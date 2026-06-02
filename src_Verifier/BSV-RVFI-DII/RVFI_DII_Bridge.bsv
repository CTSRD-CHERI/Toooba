/*-
 * Copyright (c) 2018 Jonathan Woodruff
 * Copyright (c) 2018 Alexandre Joannou
 * Copyright (c) 2018-2019 Peter Rugg
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory (Department of Computer Science and
 * Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
 * DARPA SSITH research programme.
 *
 * @BERI_LICENSE_HEADER_START@
 *
 * Licensed to BERI Open Systems C.I.C. (BERI) under one or more contributor
 * license agreements.  See the NOTICE file distributed with this work for
 * additional information regarding copyright ownership.  BERI licenses this
 * file to you under the BERI Hardware-Software License, Version 1.0 (the
 * "License"); you may not use this file except in compliance with the
 * License.  You may obtain a copy of the License at:
 *
 *   http://www.beri-open-systems.org/legal/license-1-0.txt
 *
 * Unless required by applicable law or agreed to in writing, Work distributed
 * under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * @BERI_LICENSE_HEADER_END@
 */

import Assert::*;
import Vector :: *;
import FIFO :: *;
import FIFOF :: *;
import SpecialFIFOs :: *;
import FIFOLevel :: *;
import RegFile :: * ;
import GetPut :: *;
import ClientServer :: *;
import Connectable :: *;
import RVFI_DII_Types :: *;
import Socket :: *;
import Clocks :: *;
import ConfigReg :: *;

export RVFI_DII_Client(..);
export RVFI_DII_Client_Scalar(..);
export RVFI_DII_Server(..);

export RVFI_DII_Bridge(..);
export RVFI_DII_Bridge_Scalar(..);

export mkRVFI_DII_Bridge;
export mkRVFI_DII_Bridge_Scalar;

interface RVFI_DII_Client#(numeric type xlen, numeric type memwidth, numeric type reqWidth, numeric type repWidth);
  method ActionValue#(Vector#(reqWidth, RVFI_DII_Parcel_Resp)) getParcels(Dii_Parcel_Id seqReqFirst);
  interface Put#(Vector#(repWidth, Maybe#(RVFI_DII_Execution#(xlen,memwidth)))) report;
endinterface

interface RVFI_DII_Client_Scalar#(numeric type xlen, numeric type memwidth);
  method ActionValue#(Maybe#(Bit#(32))) getInst(Dii_Id seqReq);
  interface Put#(RVFI_DII_Execution#(xlen,memwidth)) report;
endinterface

interface RVFI_DII_Server#(numeric type xlen, numeric type memwidth);
  interface Get#(RVFI_DII_Execution#(xlen,memwidth)) report;
endinterface

interface RVFI_DII_Bridge#(numeric type xlen, numeric type memwidth, numeric type reqWidth, numeric type repWidth);
  interface Reset new_rst;
  interface RVFI_DII_Client#(xlen,memwidth,reqWidth,repWidth) client;
  method Bool done;
endinterface

interface RVFI_DII_Bridge_Scalar#(numeric type xlen, numeric type memwidth);
  interface Reset new_rst;
  interface RVFI_DII_Client_Scalar#(xlen,memwidth) client;
  method Bool done;
endinterface

interface RVFI_DII_Bridge_Reset_Core#(numeric type xlen, numeric type memwidth, numeric type reqWidth, numeric type repWidth);
  interface Reset new_rst;
  interface RVFI_DII_Client#(xlen,memwidth,reqWidth,repWidth) client;
  method ActionValue#(Dii_Parcel_Id) getParcelIdForId(Dii_Id id);
  method Bool done;
endinterface

interface RVFI_DII_Bridge_Core#(numeric type xlen, numeric type memwidth, numeric type reqWidth, numeric type repWidth);
  interface RVFI_DII_Client#(xlen,memwidth,reqWidth,repWidth) client;
  method ActionValue#(Dii_Parcel_Id) getParcelIdForId(Dii_Id id);
  method Bool done;
endinterface

module mkRVFI_DII_Bridge#(String name, Integer dflt_port) (RVFI_DII_Bridge#(xlen, memwidth,reqWidth,repWidth))
  provisos (Add#(a__, TDiv#(xlen,8), 8), Add#(b__, xlen, 64), Add#(c__, TDiv#(memwidth,8), 8), Add#(d__, memwidth, 64));

  RVFI_DII_Bridge_Reset_Core#(xlen, memwidth, reqWidth, repWidth) _bridge <- mkRVFI_DII_Bridge_Reset_Core(name, dflt_port);

  interface new_rst = _bridge.new_rst;
  interface RVFI_DII_Client client = _bridge.client;
  interface done = _bridge.done;
endmodule

module mkRVFI_DII_Bridge_Scalar#(String name, Integer dflt_port) (RVFI_DII_Bridge_Scalar#(xlen, memwidth))
  provisos (Add#(a__, TDiv#(xlen,8), 8), Add#(b__, xlen, 64), Add#(c__, TDiv#(memwidth,8), 8), Add#(d__, memwidth, 64));

  RVFI_DII_Bridge_Reset_Core#(xlen, memwidth, 2, 1) _bridge <- mkRVFI_DII_Bridge_Reset_Core(name, dflt_port);

  interface new_rst = _bridge.new_rst;

  interface RVFI_DII_Client_Scalar client;
    method ActionValue#(Maybe#(Bit#(32))) getInst (Dii_Id seqReq);
      Dii_Parcel_Id parcelSeqReq <- _bridge.getParcelIdForId(seqReq);
      let parcels <- _bridge.client.getParcels(parcelSeqReq);
      let minst = tagged Invalid;
      case (parcels[0]) matches
        tagged DIIParcel .lowBits: begin
          Bit#(32) insn = zeroExtend(lowBits);
          if (insn[1:0] == 2'b11) begin
            if (parcels[1] matches tagged DIIParcel .highBits) begin
              insn[31:16] = highBits;
            end else begin
              dynamicAssert(False, "Uncompressed instruction's second half has no bits");
            end
          end
          minst = tagged Valid insn;
        end
        tagged DIINoParcel .isSecond: begin
          dynamicAssert(!isSecond, "Scalar bridge should always have fetched from the start of a parcel");
        end
      endcase
      //$display("Called getInst in RVFI_DII Bridge ", fshow(seqReq), fshow(minst));
      return minst;
    endmethod

    interface Put report;
      method Action put (RVFI_DII_Execution#(xlen, memwidth) rep);
        _bridge.client.report.put(cons(tagged Valid rep, nil));
      endmethod
    endinterface
  endinterface

  method Bool done = _bridge.done;
endmodule

module mkRVFI_DII_Bridge_Reset_Core#(String name, Integer dflt_port) (RVFI_DII_Bridge_Reset_Core#(xlen, memwidth,reqWidth,repWidth))
  provisos (Add#(a__, TDiv#(xlen,8), 8), Add#(b__, xlen, 64), Add#(c__, TDiv#(memwidth,8), 8), Add#(d__, memwidth, 64));

  // handle buffers with different Reset
  let    clk <- exposeCurrentClock;
  let newRst <- mkReset(0, True, clk);
  Reg#(Bool) doReset <- mkSyncRegToCC(False, clk, newRst.new_rst);
  Socket#(8, 88) socket <- mkSocket(name, dflt_port);
  RVFI_DII_Bridge_Core#(xlen, memwidth, reqWidth, repWidth) _bridge <- mkRVFI_DII_Bridge_Core(name, dflt_port, socket, reset_by newRst.new_rst);

  rule readDone;
    doReset <= _bridge.done;
  endrule

  rule doResetRule(doReset);
    $display("Performing reset in RVFI_DII Bridge");
    newRst.assertReset;
  endrule

  interface new_rst = newRst.new_rst;
  interface RVFI_DII_Client client = _bridge.client;
  interface getParcelIdForId = _bridge.getParcelIdForId;
  interface done = _bridge.done;
endmodule

module mkRVFI_DII_Bridge_Core#(String name, Integer dflt_port, Socket#(8, 88) socket) (RVFI_DII_Bridge_Core#(xlen, memwidth, reqWidth, repWidth))
  provisos (Add#(a__, TDiv#(xlen,8), 8), Add#(b__, xlen, 64), Add#(c__, TDiv#(memwidth,8), 8), Add#(d__, memwidth, 64));
  Reg#(Bool) allBuffered <- mkConfigReg(False);
  Reg#(Dii_Parcel_Id) countParcelIn <- mkConfigReg(0);
  Reg#(Dii_Id) countInstIn <- mkConfigReg(0);
  Reg#(Dii_Id) countInstOut <- mkConfigReg(0);
  Reg#(Bool) doneReg <- mkConfigReg(False);
  //Array of parcels and associated IDs
  RegFile#(Dii_Parcel_Id, Bit#(16)) parcels <- mkRegFileFull;
  RegFile#(Dii_Id, Dii_Parcel_Id) id2pid <- mkRegFileFull;
  FIFOF#(Bit#(16)) secondParcel <- mkFIFOF1;

  rule queTraces(!allBuffered && !secondParcel.notEmpty);
    let mBytes <- socket.get;
    if (mBytes matches tagged Valid .bytes) begin
      RVFI_DII_Instruction_ByteStream cmd = unpack(pack(bytes));
      Bool halt = (cmd.rvfi_cmd == 0);
      if (!halt) begin
        //$display("Received instruction RVFI_DII Bridge: ", fshow(cmd));
        Bit#(32) insn = byteStream2rvfiInst(cmd).rvfi_insn;
        parcels.upd(countParcelIn, insn[15:0]);
        id2pid.upd(countInstIn, countParcelIn);
        if (insn[1:0] == 2'b11) begin
          secondParcel.enq(insn[31:16]);
        end else begin
          countParcelIn <= countParcelIn + 1;
          countInstIn <= countInstIn + 1;
        end
      end else begin
        // Return the default "nop" in this case.
        allBuffered <= True;
        $display("Halt received in RVFI_DII Bridge");
      end
    end
  endrule

  rule queTracesSecondParcel;
    let parcel = secondParcel.first;
    secondParcel.deq;
    parcels.upd(countParcelIn + 1, parcel);
    countParcelIn <= countParcelIn + 2;
    countInstIn <= countInstIn + 1;
  endrule

  function Action sendRvfiTrace(RVFI_DII_Execution#(xlen,memwidth) rvfiTrace) =
    action
      Vector#(88, Bit#(8)) traceBytes = unpack(pack(rvfi2byteStream(rvfiTrace)));
      //$display("Sent RVFI-DII trace: ", fshow(rvfiTrace));
      Bool sent <- socket.put(traceBytes);
      dynamicAssert(sent, "RVFI trace failed to send!");
    endaction;

  Bool readyToHalt = (allBuffered && countInstOut == countInstIn);
  rule report_halt(readyToHalt && !doneReg);
    sendRvfiTrace(RVFI_DII_Execution{
            rvfi_order: ?,
            rvfi_trap:  ?,
            rvfi_halt:  True,
            rvfi_intr:  ?,
            rvfi_insn:  ?,
            rvfi_rs1_addr:  ?,
            rvfi_rs2_addr:  ?,
            rvfi_rs1_data:  ?,
            rvfi_rs2_data:  ?,
            rvfi_pc_rdata:  ?,
            rvfi_pc_wdata:  ?,
            rvfi_mem_wdata: ?,
            rvfi_rd_addr:   ?,
            rvfi_rd_wdata:  ?,
            rvfi_mem_addr:  ?,
            rvfi_mem_rmask: ?,
            rvfi_mem_wmask: ?,
            rvfi_mem_rdata: ?
          });
    $display("Sent Halt trace in RVFI_DII Bridge");
    doneReg <= True;
  endrule

  // wire up interfaces
  interface RVFI_DII_Client client;
    method ActionValue#(Vector#(reqWidth, RVFI_DII_Parcel_Resp)) getParcels(Dii_Parcel_Id seqReqFirst) if (allBuffered);
      function RVFI_DII_Parcel_Resp getParcel(Integer i);
        Dii_Parcel_Id seqReq = seqReqFirst + fromInteger(i);
        if (seqReq < countParcelIn) begin
          return tagged DIIParcel parcels.sub(seqReq);
        end else begin
          return tagged DIINoParcel unpack((seqReq - countParcelIn)[0]);
        end
      endfunction

      Vector#(reqWidth, RVFI_DII_Parcel_Resp) parcelResps = genWith(getParcel);
      //$display("Called getParcels in RVFI_DII Bridge ", fshow(seqReqFirst), fshow(parcelResps));
      return parcelResps;
    endmethod

    interface Put report;
      method Action put(Vector#(repWidth, Maybe#(RVFI_DII_Execution#(xlen,memwidth))) rvfiTrace) if (!readyToHalt && !doneReg);
        Dii_Id newCount = countInstOut;
        for (Integer i = 0; i < valueOf(repWidth); i = i + 1) begin
          if (rvfiTrace[i] matches tagged Valid .trace) begin
            sendRvfiTrace(trace);
            newCount = newCount + 1;
          end
        end
        countInstOut <= newCount;
      endmethod
    endinterface
  endinterface

  method ActionValue#(Dii_Parcel_Id) getParcelIdForId(Dii_Id id) if (allBuffered);
    if (id < countInstIn) begin
      return id2pid.sub(id);
    end else begin
      return countParcelIn + {id, 1'b0};
    end
  endmethod

  method Bool done = doneReg;
endmodule
