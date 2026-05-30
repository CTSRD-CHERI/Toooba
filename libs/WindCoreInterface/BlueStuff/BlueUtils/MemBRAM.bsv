/*-
 * Copyright (c) 2018-2021 Alexandre Joannou
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory (Department of Computer Science and
 * Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
 * DARPA SSITH research programme.
 *
 * This material is based upon work supported by the DoD Information Analysis
 * Center Program Management Office (DoD IAC PMO), sponsored by the Defense
 * Technical Information Center (DTIC) under Contract No. FA807518D0004.  Any
 * opinions, findings and conclusions or recommendations expressed in this
 * material are those of the author(s) and do not necessarily reflect the views
 * of the Air Force Installation Contracting Agency (AFICA).
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

import MemTypes :: *;
import SimUtils :: *;
import SourceSink :: *;
import MasterSlave :: *;

import FIFOF :: *;
import SpecialFIFOs :: *;

// BRAM interface

interface BRAM#(numeric type aw, numeric type dw);
  method Action put(Bit#(TDiv#(dw, 8)) we, Bit#(aw) addr, Bit#(dw) d);
  method Bit#(dw) peek();
endinterface

interface BRAM2#(numeric type a0w, numeric type d0w, numeric type a1w, numeric type d1w);
  interface BRAM#(a0w, d0w) p0;
  interface BRAM#(a1w, d1w) p1;
endinterface

/////////////////////////
// Altera BRAM wrapper //
////////////////////////////////////////////////////////////////////////////////
import "BVI" BlueUtils_BRAM2 =
module mkAlteraBRAM#(Integer size, String filename)(BRAM#(aw,dw));

  // XXX check  for bytes / bits
  Integer depth = size/valueOf(TDiv#(dw,8));

  // BVI statements
  default_clock clk(CLK, (*unused*) clk_gate);
  default_reset no_reset;

  // parameters
  parameter widthad_a = log2(depth);
  parameter width_a = valueOf(dw);
  parameter numwords_a = depth;
  parameter width_byteena_a = valueOf(TDiv#(dw,8));
  parameter init_file = filename;

  method put(wen_a, address_a, data_a) enable (en_a);
  method q_a peek();

  // schedule
  schedule (put) CF (peek);
  schedule (put) C (put);
  schedule (peek) CF (peek, put);

endmodule

import "BVI" BlueUtils_BRAM2 =
module mkAlteraBRAM2#(Integer size, String filename)(BRAM2#(a0w,d0w,a1w,d1w));

  // XXX check  for bytes / bits
  Integer depth_a = size/valueOf(TDiv#(d0w,8));
  Integer depth_b = size/valueOf(TDiv#(d1w,8));

  // BVI statements
  default_clock clk(CLK, (*unused*) clk_gate);
  default_reset no_reset;

  // parameters
  parameter widthad_a = log2(depth_a);
  parameter widthad_b = log2(depth_b);
  parameter width_a = valueOf(d0w);
  parameter width_b = valueOf(d1w);
  parameter numwords_a = depth_a;
  parameter numwords_b = depth_b;
  parameter width_byteena_a = valueOf(TDiv#(d0w,8));
  parameter width_byteena_b = valueOf(TDiv#(d1w,8));
  parameter init_file = filename;

  interface BRAM p0;
    method put(wen_a, address_a, data_a) enable (en_a);
    method q_a peek();
  endinterface

  interface BRAM p1;
    method put(wen_b, address_b, data_b) enable (en_b);
    method q_b peek();
  endinterface

  // schedule
  schedule (p0.put) CF (p0.peek, p1.put, p1.peek);
  schedule (p0.put) C (p0.put);
  schedule (p0.peek) CF (p0.peek, p0.put, p1.put, p1.peek);
  schedule (p1.put) CF (p1.peek, p0.put, p0.peek);
  schedule (p1.put) C (p1.put);
  schedule (p1.peek) CF (p1.peek, p1.put, p0.put, p0.peek);

endmodule

// size expressed in bytes
module wrapUnaligned#(
  String name,
  BRAM#(idx_sz, chunk_sz) mem
) (Mem#(addr_t, content_t)) provisos(
  Bits#(addr_t, addr_sz), Bits#(content_t, content_sz),
  Div#(chunk_sz, 8, chunk_byte_sz),
  Div#(content_sz, 8, content_byte_sz),
  Div#(chunk_sz, content_sz, content_per_chunk),
  Log#(content_byte_sz, ofst_sz), Log#(chunk_byte_sz, chunk_ofst_sz),
  Add#(a__, content_sz, chunk_sz), // content must be smaller than or same size as chunk
  Add#(b__, chunk_ofst_sz, addr_sz), // chunk offset must be smaller than addr
  Add#(c__, TDiv#(content_sz, 8), chunk_byte_sz), // writeen must be zero extended
  Add#(d__, TAdd#(TLog#(TDiv#(content_sz, 8)), 1), TAdd#(chunk_ofst_sz, 1)), // read of the req BitPO must be zero extended
  Add#(e__, idx_sz, addr_sz), // bram idx must be smaller than addr
  Add#(f__, TAdd#(TLog#(content_byte_sz), 1), TAdd#(chunk_ofst_sz, 1)), // must zeroExtend the countZeroMSB of req writeen
  Add#(g__, ofst_sz, TAdd#(chunk_ofst_sz, 1)), // offset must be smaller than offset of chunk + 1
  // for some reason required at the readBitPo call and when asigning numBytes on writes
  Log#(TDiv#(content_sz, 8), TLog#(content_byte_sz)),
  Log#(TAdd#(1, TDiv#(content_sz, 8)), TAdd#(TLog#(content_byte_sz), 1))
  // FShow instances
  /*,FShow#(addr_t), FShow#(content_t)*/
);

  // helper functions
  //////////////////////////////////////////////////////////////////////////////

  // internal request "unpacked" representation
`define IN_REQ Tuple7#(\
      Bool,\
      Bit#(TAdd#(chunk_ofst_sz,1)),\
      Bit#(idx_sz),\
      Bit#(chunk_ofst_sz),\
      Bit#(chunk_byte_sz),\
      Bit#(chunk_sz),\
      Bit#(TAdd#(TLog#(chunk_byte_sz), 1)))

  function `IN_REQ unpackReq(MemReq#(addr_t, content_t) req);
    Bool isRead = True;
    Bit#(TAdd#(chunk_ofst_sz,1)) numBytes = 0;
    Bit#(idx_sz) idx = ?;
    Bit#(chunk_ofst_sz) byteOffset = ?;
    Bit#(chunk_byte_sz) writeen = 0;
    Bit#(chunk_sz) data = ?;
    case (req) matches
      tagged ReadReq .r: begin // read request
        numBytes = 1 << r.numBytes; // XX double check r.numBytes < sizeOf numBytes
        idx = truncateLSB(pack(r.addr));
        byteOffset = truncate(pack(r.addr));
      end
      tagged WriteReq .w: begin // write request
        isRead = False;
        numBytes = pack(fromInteger(valueOf(content_byte_sz)) - zeroExtend(countZerosMSB(w.byteEnable)));
        idx = truncateLSB(pack(w.addr));
        byteOffset = truncate(pack(w.addr));
        writeen = zeroExtend(w.byteEnable);
        data = zeroExtend(pack(w.data));
      end
    endcase
    Bit#(TAdd#(chunk_ofst_sz, 1)) avail  = fromInteger(valueOf(chunk_byte_sz)) - zeroExtend(byteOffset);
    Bit#(TAdd#(chunk_ofst_sz, 1)) remain = (avail >= numBytes) ? 0 : numBytes - avail;
    return tuple7(isRead, numBytes, idx, byteOffset, writeen, data, remain);
  endfunction

  // shifts and masks helpers
  function Bit#(TAdd#(chunk_ofst_sz, 1)) bytesBelow (Bit#(chunk_ofst_sz) o) =
    zeroExtend(o);
  function Bit#(chunk_byte_sz) byteMaskBelow (Bit#(chunk_ofst_sz) o) = ~((~0) << bytesBelow(o));
  function Bit#(TAdd#(chunk_ofst_sz, 1)) bytesAbove (Bit#(chunk_ofst_sz) o) =
    fromInteger(valueOf(chunk_byte_sz)) - zeroExtend(o);
  function Bit#(chunk_byte_sz) byteMaskAbove (Bit#(chunk_ofst_sz) o) = ~byteMaskBelow(o);
  function Bit#(TAdd#(chunk_ofst_sz, 4)) bitsBelow (Bit#(chunk_ofst_sz) o) =
    zeroExtend(bytesBelow(o)) << valueOf(TLog#(8));
  function Bit#(chunk_sz) bitMaskBelow (Bit#(chunk_ofst_sz) o) = ~((~0) << bitsBelow(o));
  function Bit#(TAdd#(chunk_ofst_sz, 4)) bitsAbove (Bit#(chunk_ofst_sz) o) =
    zeroExtend(bytesAbove(o)) << valueOf(TLog#(8));
  function Bit#(chunk_sz) bitMaskAbove (Bit#(chunk_ofst_sz) o) = ~bitMaskBelow(o);
  function Bit#(TAdd#(chunk_ofst_sz, 4)) largeBitsBelow (Bit#(TAdd#(chunk_ofst_sz, 1)) o) =
    zeroExtend(o) << valueOf(TLog#(8));

  // local state
  //////////////////////////////////////////////////////////////////////////////
  Reg#(Bool) cross_boundary[2] <- mkCReg(2,False);
  Reg#(Bool) req_done <- mkRegU;
  Reg#(Maybe#(Tuple2#(Bit#(idx_sz), Bit#(chunk_sz)))) prev_lookup[2] <- mkCReg(2, tagged Invalid);
  Wire#(Tuple2#(Bit#(idx_sz), Bit#(chunk_sz))) prevLookupUpdt <- mkWire;
  Wire#(Tuple3#(Bit#(chunk_byte_sz), Bit#(idx_sz), Bit#(chunk_sz))) memLookup <- mkWire;
  // data response/control pipeline FIFOF
  FIFOF#(`IN_REQ) pendingReq <- mkPipelineFIFOF;

  // rule debug
  rule debug;
    //printTLogPlusArgs("BlueUtils", $format("wrapUnaligned (", fshow(name), ") -- cross_boundary: ", fshow(cross_boundary[0]), ", req_done: ", fshow(req_done), ", prev_lookup[0]: ", fshow(prev_lookup[0])));
  endrule

  // rule sending the mem module put request
  rule mem_lookup;
    match {.writeen, .idx, .data} = memLookup;
    mem.put(writeen, idx, data);
    //printTLogPlusArgs("BlueUtils", $format("wrapUnaligned (", fshow(name), ") -- sending mem.put(0x%0x,0x%0x,0x%0x)", writeen, idx, data));
  endrule

  // rule updating the prev_lookup
  rule update_prev_lookup;
    match {.idx, .data} = prevLookupUpdt;
    prev_lookup[0] <= Valid(prevLookupUpdt);
    //printTLogPlusArgs("BlueUtils", $format("wrapUnaligned (", fshow(name), ") -- updating prev_lookup(0x%0x,0x%0x)", idx, data));
  endrule

  // rule for cross-boundary accesses behaviour
  //////////////////////////////////////////////////////////////////////////////
  PulseWire cross_boundary_access_fire <- mkPulseWire;
  rule cross_boundary_access (cross_boundary[0] && !req_done);
    cross_boundary_access_fire.send();
    // read internal request
    match {.isRead,.numBytes,.idx,.byteOffset,.writeen,.data,.remain} = pendingReq.first();
    // derive shift values
    if (isRead) begin // READ
      prevLookupUpdt <= tuple2(idx, mem.peek);
      req_done <= True; // signal end of request
      //printTLogPlusArgs("BlueUtils", $format("wrapUnaligned (", fshow(name), ") -- done read"));
    end else begin // WRITE
      writeen = writeen >> bytesAbove(byteOffset);
      data = data >> bitsAbove(byteOffset);
      // retire the request
      cross_boundary[0] <= False;
      pendingReq.deq();
      //printTLogPlusArgs("BlueUtils", $format("wrapUnaligned (", fshow(name), ") -- done write"));
    end
    memLookup <= tuple3(writeen, idx + 1, data);
  endrule

  // response value helper
  function buildResponse;
    // read internal request
    match {.isRead,.numBytes,.idx,.byteOffset,.writeen,.data,.remain} = pendingReq.first;
    // prepare response data
    Bit#(chunk_sz) rsp_data = ?;
    if (cross_boundary[0]) begin // merge with previously looked up  data
      match {.pidx, .pdata} = fromMaybe(?, prev_lookup[0]);
      Bit#(chunk_sz) lowData = pdata;
      lowData = (lowData  & bitMaskAbove(byteOffset)) >> bitsBelow(byteOffset);
      Bit#(chunk_sz) hiData  = truncate(mem.peek);
      hiData = (hiData & bitMaskBelow(byteOffset)) << bitsAbove(byteOffset);
      rsp_data = hiData | lowData;
    end else begin // single cycle access (aligned or un-aligned)
      let shiftAmnt = (byteOffset == 0) ? 0 : bitsBelow(byteOffset);
      rsp_data = (mem.peek & bitMaskAbove(byteOffset)) >> shiftAmnt;
    end
    // prepare response
    Bit#(content_sz)  mask = ~((~0) << largeBitsBelow(numBytes));
    MemRsp#(content_t) rsp = tagged ReadRsp unpack(truncate(rsp_data) & mask);
    return rsp;
  endfunction

  // interface
  //////////////////////////////////////////////////////////////////////////////
  Bool canPutReq = !cross_boundary[1] && !cross_boundary_access_fire && pendingReq.notFull;
  Bool canGetRsp = req_done && pendingReq.notEmpty;
  interface req = interface Sink;
    method Bool canPut = canPutReq;
    method Action put (MemReq#(addr_t, content_t) req) if (canPutReq);
      //printTLogPlusArgs("BlueUtils", $format("wrapUnaligned (", fshow(name), ") -- ", fshow(req)));
      // "unpack" the request
      `IN_REQ inReq = unpackReq(req);
      match {.isRead,.numBytes,.idx,.byteOffset,.writeen,.data,.remain} = inReq;
      // check for cross boundary access
      Bool isCrossBoundary = remain > 0;
      Bool isSingleCycle = !isCrossBoundary;
      // prepare mem put request
      let req_writeen = writeen << bytesBelow(byteOffset);
      let req_idx = idx;
      let req_data = data << bitsBelow(byteOffset);
      // check previous lookup for match and alter the mem request / single cycle accordingly
      match {.pidx, .pdata} = fromMaybe(?, prev_lookup[1]);
      //printTLogPlusArgs("BlueUtils", $format("wrapUnaligned (", fshow(name), ") -- isRead: ", fshow(isRead),", isCrossBoundary: ", fshow(isCrossBoundary),", pidx: 0x%0x, idx: 0x%0x", pidx, idx));
      if (isValid(prev_lookup[1]) && (pidx == idx) && isRead && isCrossBoundary) begin
        req_idx = idx + 1;
        isSingleCycle = True;
        //printTLogPlusArgs("BlueUtils", $format("wrapUnaligned (", fshow(name), ") -- use prev_lookup @idx 0x%0x to avoid extra lookup", idx));
      end
      // on reads or cross boundary accesses, enqueue a pending request
      if (isRead || isCrossBoundary) pendingReq.enq(tuple7(isRead,numBytes,idx,byteOffset,writeen,(isRead) ? 0 : data,remain));
      // set control registers
      cross_boundary[1] <= isCrossBoundary;
      req_done <= isSingleCycle;
      // perform the BRAMCore access
      memLookup <= tuple3(req_writeen, req_idx, req_data);
    endmethod
  endinterface;
  interface rsp = interface Source;
    method Bool canPeek = canGetRsp;
    method MemRsp#(content_t) peek if (canGetRsp) = buildResponse;
    method Action drop if (canGetRsp);
      // Reset cross_boundary to allow sendReq to fire again
      if (cross_boundary[0]) cross_boundary[0] <= False;
      // Update prev_lookup
      match {.isRead,.numBytes,.idx,.byteOffset,.writeen,.data,.remain} = pendingReq.first;
      prevLookupUpdt <= tuple2((cross_boundary[0]) ? idx + 1 : idx, mem.peek);
      // Retire request
      pendingReq.deq;
    endmethod
  endinterface;

endmodule
