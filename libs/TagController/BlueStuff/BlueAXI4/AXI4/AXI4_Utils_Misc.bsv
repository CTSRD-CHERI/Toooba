/*-
 * Copyright (c) 2018-2022 Alexandre Joannou
 * Copyright (c) 2019 Peter Rugg
 * Copyright (c) 2020 Jonas Fiala
 * Copyright (c) 2021 Marno van der Maas
 * Copyright (c) 2021 Ivan Ribeiro
 * All rights reserved.
 *
 * This hardware design was developed by the University of Cambridge Computer
 * Laboratory (Department of Computer Science and Technology) under EPSRC award
 * EP/S030867/1 ("SIPP"); and by SRI International and the University of
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

// AXI4 imports
import AXI4_Types :: *;
import AXI4_Common_Types :: *;
import AXI4_Utils_Basics :: *;
import AXI4_Channels_Utils :: *;

// BlueStuff import
import BlueBasics :: *;

// Standard
import FIFOF :: *;
import SpecialFIFOs :: *;
import Connectable :: *;

//////////////////
// AXI4 Limiter //
////////////////////////////////////////////////////////////////////////////////

module mkAXI4Limiter#(parameter Integer maxReqs) (AXI4_Shim#(a, b, c, d, e, f, g, h));

  // req counting
  FIFOF#(Bit#(0)) limWriteFF <- mkSizedFIFOF(maxReqs);
  let pendingW <- mkReg(False);
  FIFOF#(Bit#(0)) limReadFF <- mkSizedFIFOF(maxReqs);
  // inner shim
  let shim <- mkAXI4ShimFF;
  let slv = shim.slave;
  // interfaces
  method clear = action
    limWriteFF.clear;
    pendingW <= False;
    limReadFF.clear;
    shim.clear;
  endaction;
  interface slave = interface AXI4_Slave;
    interface aw = interface Sink;
      method canPut = slv.aw.canPut && limWriteFF.notFull && !pendingW;
      //method put = slv.aw.put;
      method put if (slv.aw.canPut && limWriteFF.notFull && !pendingW) = slv.aw.put;
    endinterface;
    interface w = interface Sink;
      method canPut = slv.w.canPut && limWriteFF.notFull;
      //method put(x) = action
      method put(x) if (slv.w.canPut && limWriteFF.notFull) = action
        slv.w.put(x);
        pendingW <= !x.wlast;
        if (x.wlast) limWriteFF.enq(?);
      endaction;
    endinterface;
    interface b = interface Source;
      method canPeek = slv.b.canPeek && limWriteFF.notEmpty;
      //method peek = slv.b.peek;
      method peek if (slv.b.canPeek && limWriteFF.notEmpty) = slv.b.peek;
      //method drop = action
      method drop if (slv.b.canPeek && limWriteFF.notEmpty) = action
        limWriteFF.deq;
        slv.b.drop;
      endaction;
    endinterface;
    interface ar = interface Sink;
      method canPut = slv.ar.canPut && limReadFF.notFull;
      //method put(x) = action
      method put(x) if (slv.ar.canPut && limReadFF.notFull) = action
        limReadFF.enq(?);
        slv.ar.put(x);
      endaction;
    endinterface;
    interface r = interface Source;
      method canPeek = slv.r.canPeek && limReadFF.notEmpty;
      //method peek = slv.r.peek;
      method peek if (slv.r.canPeek && limReadFF.notEmpty) = slv.r.peek;
      //method drop = action
      method drop if (slv.r.canPeek && limReadFF.notEmpty) = action
        if (slv.r.peek.rlast) limReadFF.deq;
        slv.r.drop;
      endaction;
    endinterface;
  endinterface;
  interface master = shim.master;

endmodule

//////////////////////////////////////
// Arbiter between reads and writes //
////////////////////////////////////////////////////////////////////////////////

typedef enum {IDLE, BURST_WRITE, WAITING} SerialiserState deriving (FShow, Bits, Eq);

module mkSerialiser #(AXI4_Master#(a, b, c, d, e, f, g, h) m)
  (AXI4_Master#(a, b, c, d, e, f, g, h));

  let shim <- mkAXI4ShimBypassFIFOF;
  let slv = shim.slave;

  let lastWasRead <- mkReg(False);
  let state <- mkCReg(2, IDLE);

  let writeWaiting = m.aw.canPeek;
  let readWaiting = m.ar.canPeek;

  let allowNewRead = state[0] == IDLE && (!lastWasRead || (!writeWaiting));
  let allowNewWrite = state[0] == IDLE && (lastWasRead || (!readWaiting));

  // Requests //
  //////////////////////////////////////////////////////////////////////////////

  rule takeAW(allowNewWrite);
    let awFlit <- get(m.aw);
    state[0] <= BURST_WRITE;
    lastWasRead <= False;
    slv.aw.put(awFlit);
  endrule

  rule takeW(state[1] == BURST_WRITE);
    let wFlit <- get(m.w);
    if (wFlit.wlast) state[1] <= WAITING;
    slv.w.put(wFlit);
  endrule

  rule takeAR(allowNewRead);
    let arFlit <- get(m.ar);
    state[0] <= WAITING;
    lastWasRead <= True;
    slv.ar.put(arFlit);
  endrule

  // Responses //
  //////////////////////////////////////////////////////////////////////////////

  (* mutually_exclusive = "takeR, takeB" *)

  rule takeB (state[1] == WAITING);
    let bFlit <- get(slv.b);
    m.b.put(bFlit);
    state[1] <= IDLE;
  endrule

  rule takeR (state[1] == WAITING);
    let rFlit <- get(slv.r);
    m.r.put(rFlit);
    if (rFlit.rlast) state[1] <= IDLE;
  endrule

  return shim.master;

endmodule

//////////////////////////////////////////
// AXI4 Burst Master <-> NonBurst Slave //
////////////////////////////////////////////////////////////////////////////////

module mkBurstToNoBurst (AXI4_Shim#(a, b, c, d, e, f, g, h))
  provisos(Add#(a__, SizeOf#(AXI4_Len), b));

  // Shims
  let inShim <- mkAXI4ShimFF;
  let inSerial <- mkSerialiser(inShim.master);
  let outShim <- mkAXI4ShimFF;
  // handy names
  let inAW = inSerial.aw;
  let inW  = inSerial.w;
  let inB  = inSerial.b;
  let inAR = inSerial.ar;
  let inR  = inSerial.r;
  let outAW = outShim.slave.aw;
  let outW  = outShim.slave.w;
  let outB  = outShim.slave.b;
  let outAR = outShim.slave.ar;
  let outR  = outShim.slave.r;
  // internal state
  let lastReadRspFF   <- mkSizedFIFOF(4);
  let countWriteRspFF <- mkSizedFIFOF(4);
  Reg#(Bit#(SizeOf#(AXI4_Len))) writesSent[2] <- mkCReg(2, 0);
  Reg#(Bit#(SizeOf#(AXI4_Len))) readsSent[2] <- mkCReg(2, 0);
  let defaultBResp = AXI4_BFlit {bid: ?, bresp: EXOKAY, buser: ?};
  Reg#(Tuple2#(Bit#(TAdd#(SizeOf#(AXI4_Len), 1)), AXI4_BFlit #(a, f))) flitReceived[3] <- mkCReg(3, tuple2(0, defaultBResp));

  // helper functions
  function getFlitAddr(addr, size, burst, cnt) = case (burst)
    INCR: return addr + (zeroExtend(cnt) << pack(size));
    default: return addr;
  endcase;

  // DEBUG //
  //////////////////////////////////////////////////////////////////////////////
  Bool debug = False;
  (* fire_when_enabled *)
  rule dbg (debug);
    Fmt dbg_str = $format("inAW.canPeek:\t ", fshow(inAW.canPeek))
                + $format("\toutAW.canPut:\t ", fshow(outAW.canPut))
                + $format("\n\tinW.canPeek:\t ", fshow(inW.canPeek))
                + $format("\toutW.canPut:\t ", fshow(outW.canPut))
                + $format("\n\tinB.canPut:\t ", fshow(inB.canPut))
                + $format("\toutB.canPeek:\t ", fshow(outB.canPeek))
                + $format("\n\tinAR.canPeek:\t ", fshow(inAR.canPeek))
                + $format("\toutAR.canPut:\t ", fshow(outAR.canPut))
                + $format("\n\tinR.canPut:\t ", fshow(inR.canPut))
                + $format("\toutR.canPeek:\t ", fshow(outR.canPeek));
    Fmt state_str = $format(" writesSent: %d", writesSent[0],
                            " readsSent: %d", readsSent[0],
                            " flitReceived: ", fshow(flitReceived[0]));
    $display("%0t: ", $time, dbg_str);
    $display("%0t: ", $time, state_str);
  endrule
  (* fire_when_enabled *)
  rule dbgff (debug);
    Fmt state_str = $format("countWriteRspFF - notFull: ", fshow(countWriteRspFF.notFull),
                            " notEmpty: ", fshow(countWriteRspFF.notEmpty),
                            " first: %d", countWriteRspFF.first)
                  + $format("\n\tlastReadRspFF - notFull: ", fshow(lastReadRspFF.notFull),
                            " notEmpty: ", fshow(lastReadRspFF.notEmpty),
                            " first: ", fshow(lastReadRspFF.first));
    $display("%0t: ", $time, state_str);
  endrule
  // Writes
  //////////////////////////////////////////////////////////////////////////////
  rule forward_write_req;
    // prepare new AW request flit
    let awflit = inAW.peek;
    let newawflit = awflit;
    newawflit.awaddr = getFlitAddr(awflit.awaddr, awflit.awsize, awflit.awburst,
                                   writesSent[0]);
    newawflit.awlen = 0;
    newawflit.awburst = FIXED;
    // prepare new W request flit
    let newwflit <- get(inW);
    newwflit.wlast = True;
    // produce a AW/W output
    outAW.put(newawflit);
    outW.put(newwflit);
    // book keeping
    if (inW.peek.wlast) begin
      inAW.drop;
      countWriteRspFF.enq(awflit.awlen);
      writesSent[0] <= 0;
    end else writesSent[0] <= writesSent[0] + 1;
    // DEBUG //
    if (debug) $display("%0t: forward_write_req", $time,
                        "\n", fshow(awflit), "\n", fshow(inW.peek),
                        "\n", fshow(newawflit), "\n", fshow(newwflit));
  endrule
  rule consume_bresp;
    // always consume the response and save the "aggregated" response
    outB.drop;
    // combine the old and new response, keeping the "lower" bresp value of the two, and for the
    // other fields use the new response's values
    // The ordering of bresp values used here is EXOKAY > OKAY > DECERR > SLVERR
    function AXI4_BFlit #(a, f) combine_bresp (AXI4_BFlit #(a, f) bflit_a, AXI4_BFlit #(a, f) bflit_b);
      let bresp_a = bflit_a.bresp;
      let bresp_b = bflit_b.bresp;
      return case (tuple2(bresp_a, bresp_b)) matches
        {EXOKAY, .x}: bflit_b;
        {OKAY,   .x} &&& (x != EXOKAY): bflit_b;
        {DECERR, .x} &&& (x != EXOKAY && x != OKAY): bflit_b;
        // in all other cases, including when bresp_a is SLVERR, we return bresp_a
        // but with corrected id and user fields
        default: AXI4_BFlit { bid   : bflit_b.bid
                            , bresp : bresp_a
                            , buser : bflit_b.buser };
      endcase;
    endfunction
    flitReceived[0] <= tuple2(tpl_1(flitReceived[0]) + 1
                             ,combine_bresp(tpl_2(flitReceived[0])
                                           ,outB.peek));

    // DEBUG //
    if (debug) $display("%0t: consume_bresp - ", $time, fshow(outB.peek));
  endrule

  // on last response, forward the aggregated response and reset book keeping
  rule produce_bresp (countWriteRspFF.notEmpty
                     && tpl_1(flitReceived[1]) > zeroExtend (countWriteRspFF.first));
    flitReceived[1] <= tuple2(0, defaultBResp);
    countWriteRspFF.deq;
    inB.put(tpl_2(flitReceived[1]));

    // DEBUG //
    if (debug) $display("%0t: produce_bresp - ", $time, fshow(tpl_2(flitReceived[1])));
  endrule

  // Reads
  //////////////////////////////////////////////////////////////////////////////
  rule forward_read_req;
    // prepare new request flit
    let arflit = inAR.peek;
    let newflit = arflit;
    newflit.araddr = getFlitAddr(arflit.araddr, arflit.arsize, arflit.arburst,
                                 readsSent[0]);
    newflit.arlen = 0;
    newflit.arburst = FIXED;
    // is this the last request ?
    let isLast = (readsSent[0] == arflit.arlen);
    // produce a AR output
    outAR.put(newflit);
    lastReadRspFF.enq(isLast);
    // book keeping
    if (isLast) begin
      inAR.drop;
      readsSent[0] <= 0;
    end else readsSent[0] <= readsSent[0] + 1;
    // DEBUG //
    if (debug) $display("%0t: forward_read_req", $time,
                        "\n", fshow(arflit), "\n", fshow(newflit),
                        "\nisLast: ", fshow(isLast),
                        " readsSent: %0d", readsSent[0]);
  endrule
  rule forward_read_rsp;
    // prepare new response flit
    let newflit   = outR.peek;
    newflit.rlast <- get(lastReadRspFF);
    // consume and produce on AXI
    outR.drop;
    inR.put(newflit);
    // DEBUG //
    if (debug) $display("%0t: forward_read_rsp - ", $time, fshow(newflit));
  endrule

  // Interface
  //////////////////////////////////////////////////////////////////////////////
  method clear = action
    inShim.clear;
    outShim.clear;
    lastReadRspFF.clear;
    countWriteRspFF.clear;
    writesSent[1]   <= 0;
    readsSent[1]    <= 0;
    flitReceived[2] <= tuple2(0, defaultBResp);
  endaction;
  interface slave  = inShim.slave;
  interface master = outShim.master;

endmodule

///////////////////////
// Width conversions //
////////////////////////////////////////////////////////////////////////////////

module toWider_AXI4_Master #(AXI4_Master#(id_, addr_, narrow_, awuser_, wuser_, buser_, aruser_, ruser_) narrow)
  (AXI4_Master#(id_, addr_, wide_, awuser_, wuser_, buser_, aruser_, ruser_)) provisos (Add#(narrow_, narrow_, wide_), Add#(TDiv#(narrow_, 8), TDiv#(narrow_, 8), TDiv#(wide_, 8)));

  //TODO will not tolerate bursts
  //TODO will handle only one outstanding ID at a time

  AXI4_Shim#(id_, addr_, narrow_, awuser_, wuser_, buser_, aruser_, ruser_) bufferShim <- mkAXI4ShimUGSizedFIFOF4;
  mkConnection(bufferShim.slave, narrow);

  let inMaster = bufferShim.master;

  let takeUpperW <- mkFIFOF;
  let takeUpperR <- mkSizedFIFOF(8);

  let awFF <- mkFIFOF;

  let currentRID <- mkRegU;
  let currentWID <- mkRegU;

  let awCanPeek <- mkDWire(False);
  let wCanPeek <- mkDWire(False);
  let arCanPeek <- mkDWire(False);
  let bCanPut <- mkDWire(False);
  let rCanPut <- mkDWire(False);

  rule canAW;
    awCanPeek <= inMaster.aw.canPeek && (!takeUpperW.notEmpty || (inMaster.aw.peek.awid == currentWID)) && takeUpperW.notFull && awFF.notFull;
  endrule
  rule canW;
    wCanPeek <= inMaster.w.canPeek && takeUpperW.notEmpty;
  endrule
  rule canAR;
    arCanPeek <= inMaster.ar.canPeek && (!takeUpperR.notEmpty || (inMaster.ar.peek.arid == currentRID)) && takeUpperR.notFull;
  endrule
  rule canB;
    bCanPut <= inMaster.b.canPut;
  endrule
  rule canR;
    rCanPut <= inMaster.r.canPut && takeUpperR.notEmpty;
  endrule

  rule consumeAW (awCanPeek);
    let flit <- get(inMaster.aw);
    currentWID <= flit.awid;
    takeUpperW.enq(flit.awaddr[valueOf(TLog#(TDiv#(narrow_,8)))]);
    awFF.enq(flit);
  endrule

  interface aw = toSource(awFF);
  interface Source w;
    method Action drop if (wCanPeek);
      let flit <- get(inMaster.w);
      takeUpperW.deq;
    endmethod
    method canPeek = wCanPeek;
    method peek if (wCanPeek);
      let x = inMaster.w.peek;
      Bit#(narrow_) zeroDat = 0;
      Bit#(TDiv#(narrow_, 8)) zeroStrb = 0;
      return AXI4_WFlit {
        wdata: takeUpperW.first == 1'b1 ? {x.wdata, zeroDat} : {zeroDat, x.wdata},
        wstrb: takeUpperW.first == 1'b1 ? {x.wstrb, zeroStrb} : {zeroStrb, x.wstrb},
        wlast: x.wlast,
        wuser: x.wuser
      };
    endmethod
  endinterface
  interface Sink b;
    method canPut = bCanPut;
    method Action put(x) if (bCanPut);
        inMaster.b.put(x);
    endmethod
  endinterface
  interface Source ar;
    method Action drop if (arCanPeek);
      let flit <- get(inMaster.ar);
      currentRID <= flit.arid;
      takeUpperR.enq(flit.araddr[valueOf(TLog#(TDiv#(narrow_,8)))]);
    endmethod
    method canPeek = arCanPeek;
    method peek if (arCanPeek) = inMaster.ar.peek;
  endinterface
  interface Sink r;
    method canPut = rCanPut;
    method Action put(x) if (rCanPut);
      inMaster.r.put(AXI4_RFlit {
        rid:   x.rid,
        rdata: takeUpperR.first == 1'b1 ? truncateLSB(x.rdata) : truncate(x.rdata),
        rresp: x.rresp,
        rlast: x.rlast,
        ruser: x.ruser
      });
      takeUpperR.deq;
    endmethod
  endinterface
endmodule

typedef enum { COMBINE, PAD_FIRST, PAD_LAST } ReadSplitOption deriving (Bits, Eq, FShow);

//Module to double the data width of a slave. Assumes no bursts, data address aligned to data size.
module toWider_AXI4_Slave #(AXI4_Slave #( id_, addr_,  narrow_
                                        , awuser_, wuser_, buser_
                                        , aruser_, ruser_) narrow)
                           (AXI4_Slave #( id_, addr_, wide_
                                        , awuser_, wuser_, buser_
                                        , aruser_, ruser_))
  provisos ( Add #(narrow_, narrow_, wide_)
           , Add#(_a, TExp#(SizeOf#(AXI4_Size)), addr_) );

  let debug = False;

  //TODO make more general: currently only works to double width
  //TODO out-of-order responses - allow multiple outstanding with same ID
  //TODO give error response if either response is an error?

  //Transactions pending at wide side
  let shim <- mkAXI4ShimBypassFIFOF;
  let in = shim.master;

  //Buffers for second halves of wide write flits (will be sent next)
  let second_aw  <- mkSizedBypassFIFOF(1);
  let second_w   <- mkSizedBypassFIFOF(1);

  //Records whether responses should be dropped (i.e. first half of what was originally 1 xaction)
  let drop_b     <- mkSizedBypassFIFOF(1);

  //Buffer for second half of ar request (will be sent next)
  let second_ar  <- mkSizedBypassFIFOF(1);

  //Records whether read responses should be combined with another response, or represent an entire
  //xaction with the first or last bits to be zero-filled
  let split_ar   <- mkSizedBypassFIFOF(1);

  //Buffers the first half of a read response (will be recombined next)
  let first_r    <- mkSizedBypassFIFOF(1);


  //Dynamic arbitration: alternate between reads and writes
  let lastWasRead <- mkReg(False);

  //Control signals
  let busy = drop_b.notEmpty || split_ar.notEmpty;
  let noPendingWrite = !in.aw.canPeek || !in.w.canPeek;
  let noPendingRead = !in.ar.canPeek;
  let allowRead = (!lastWasRead || noPendingWrite) && !busy;
  let allowWrite = (lastWasRead || noPendingRead) && !busy;

  //useful bindings
  let halfBitIdx = valueOf(TSub#(TLog#(narrow_), 3)); //Index of bit which determines which half is referred to by an address

  //determines whether a request requires two half-width requests to be sent on the narrow bus
  function Bool crossesBoundary (Bit #(addr_) addr, AXI4_Size size);
    return addr[halfBitIdx] == 1'b0 && (addr + zeroExtend(fromAXI4_Size(size)) > (addr[valueOf(addr_)-1:halfBitIdx] << halfBitIdx) + (fromInteger(valueOf(narrow_)) >> 3));
  endfunction

  function Maybe #(AXI4_Size) getFirstSize (Bit #(addr_) addr, AXI4_Size size) =
    crossesBoundary(addr, size) ? toAXI4_Size((fromInteger(valueOf(narrow_) / 8)) - addr[halfBitIdx-1:0]) : Valid(size);
  function Maybe #(AXI4_Size) getSecondSize (Bit #(addr_) addr, AXI4_Size size) =
    toAXI4_Size(zeroExtend(fromAXI4_Size(size)) - (fromInteger(valueOf(narrow_) / 8)) + addr[halfBitIdx:0]);

  rule send_first_aw_w (allowWrite);
    lastWasRead <= False;
    let old_aw = in.aw.peek;
    let old_w = in.w.peek;
    let requiresSplit = crossesBoundary(old_aw.awaddr, old_aw.awsize);
    let firstSize = getFirstSize(old_aw.awaddr, old_aw.awsize);
    let secondSize = getSecondSize(old_aw.awaddr, old_aw.awsize);

    if (!isValid(firstSize) || (!isValid(secondSize) && requiresSplit)) begin
      $display("Error in toWider_AXI4_Slave: split aw transactions would not have power of two size - ", fshow(old_aw));
      $finish(0);
    end

    if (!(old_aw.awlen == 0 && old_w.wlast)) begin
      $display("Error in toWider_AXI4_Slave: aw burst transaction attempted - not supported\n", fshow(old_aw), "\n", fshow(old_w));
    end

    let new_aw = old_aw;
    new_aw.awsize = firstSize.Valid;
    narrow.aw.put(new_aw);

    AXI4_WFlit #(narrow_, wuser_) new_w = AXI4_WFlit {
        wdata: requiresSplit ? old_w.wdata[valueOf(narrow_)-1:0] : (old_aw.awaddr[halfBitIdx] == 1'b0 ? old_w.wdata [valueOf(narrow_)-1:0] : old_w.wdata [valueOf(wide_)-1:valueOf(narrow_)]),
        wstrb: requiresSplit ? old_w.wstrb[(fromInteger(valueOf(narrow_)) >> 3) -1 : 0] : (old_aw.awaddr[halfBitIdx] == 1'b0 ? old_w.wstrb [(fromInteger(valueOf(narrow_)) >> 3) -1:0] : old_w.wstrb[(fromInteger(valueOf(wide_)) >> 3) -1 : fromInteger(valueOf(narrow_)) >> 3]),
        wlast: True,
        wuser: old_w.wuser
      };

    narrow.w.put(new_w);

    if (requiresSplit) begin
      let new_aw_2 = old_aw;
      new_aw_2.awsize = secondSize.Valid;
      new_aw_2.awaddr = old_aw.awaddr + (fromInteger(valueOf(narrow_)) >> 3);
      second_aw.enq(new_aw_2);

      second_w.enq(AXI4_WFlit {
        wdata: old_w.wdata[valueOf(wide_)-1:valueOf(narrow_)],
        wstrb: old_w.wstrb[(fromInteger(valueOf(wide_)) >> 3)-1: fromInteger(valueOf(narrow_))>>3],
        wlast: True,
        wuser: old_w.wuser
        });

      drop_b.enq(True);
    end else begin
      drop_b.enq(False);
    end
    in.w.drop;
    in.aw.drop;
    if (debug) begin
      $display("send_first_aw_w fired");
      $display("\told_aw: ", fshow(old_aw));
      $display("\tnew_aw: ", fshow(new_aw));
      $display("\told_w: ", fshow(old_w));
      $display("\tnew_w: ", fshow(new_w));
      $display("\trequiresSplit: ", fshow(requiresSplit));
    end
  endrule

  rule send_second_aw;
    narrow.aw.put(second_aw.first);
    second_aw.deq;
    drop_b.enq(False);
    if (debug) begin
      $display("send_second_aw fired");
      $display("\tsecond_aw.first: ", fshow(second_aw.first));
    end
  endrule

  rule send_second_w;
    narrow.w.put(second_w.first);
    second_w.deq;
    if (debug) begin
      $display("send_second_w fired");
      $display("\tsecond_w.first: ", fshow(second_w.first));
    end
  endrule

  rule take_b;
    drop_b.deq;
    narrow.b.drop;
    if (!drop_b.first) begin
      in.b.put(narrow.b.peek);
    end
    if (debug) begin
      $display("take_b fired");
      $display("\tnarrow.b.peek: ", fshow(narrow.b.peek));
      $display("\tdrop_b.first: ", fshow(drop_b.first));
    end
  endrule

  rule send_first_ar(allowRead);
    lastWasRead <= True;
    let old_ar = in.ar.peek;
    let requiresSplit = crossesBoundary(old_ar.araddr, old_ar.arsize);
    let firstSize = getFirstSize(old_ar.araddr, old_ar.arsize);
    let secondSize = getSecondSize(old_ar.araddr, old_ar.arsize);

    if (!isValid(firstSize) || (!isValid(secondSize) && requiresSplit)) begin
      $display("Error in toWider_AXI4_Slave: split ar transactions would not have power of two size - ", fshow(old_ar));
      $finish(0);
    end
    if (!(old_ar.arlen == 0)) begin
      $display("Error in toWider_AXI4_Slave: ar burst transaction attempted - not supported\n", fshow(old_ar));
    end

    let new_ar = old_ar;
    new_ar.arsize = firstSize.Valid;
    narrow.ar.put(new_ar);

    if (requiresSplit) begin
      let new_ar_2 = old_ar;
      new_ar_2.arsize = secondSize.Valid;
      new_ar_2.araddr = old_ar.araddr + (fromInteger(valueOf(narrow_)) >> 3);
      second_ar.enq(new_ar_2);
      split_ar.enq(COMBINE);
    end else if (old_ar.araddr[halfBitIdx] == 1'b1) begin
      split_ar.enq(PAD_FIRST);
    end else begin
      split_ar.enq(PAD_LAST);
    end
    in.ar.drop;
    if (debug) begin
      $display("send_first_ar fired");
      $display("\told_ar: ", fshow(old_ar));
      $display("\tnew_ar: ", fshow(new_ar));
      $display("\trequiresSplit: ", fshow(requiresSplit));
    end
  endrule

  rule send_second_ar;
    narrow.ar.put(second_ar.first);
    second_ar.deq;
    if (debug) begin
      $display("send_second_ar fired");
      $display("\tsecond_ar.first: ", fshow(second_ar.first));
    end
  endrule

  rule receive_first_r(!first_r.notEmpty);
    narrow.r.drop;
    if (!narrow.r.peek.rlast) begin
      $display("Error in toWider_AXI4_Slave: r burst transaction attempted - not supported.");
      $finish(0);
    end
    case (split_ar.first)
      COMBINE: first_r.enq(narrow.r.peek.rdata);
      PAD_FIRST: begin
        in.r.put(AXI4_RFlit {
        rid: narrow.r.peek.rid,
        rdata: {narrow.r.peek.rdata, 0},
        rresp: narrow.r.peek.rresp,
        rlast: narrow.r.peek.rlast,
        ruser: narrow.r.peek.ruser
        });
        split_ar.deq;
      end
      PAD_LAST: begin
        in.r.put(AXI4_RFlit {
        rid: narrow.r.peek.rid,
        rdata: {0, narrow.r.peek.rdata},
        rresp: narrow.r.peek.rresp,
        rlast: narrow.r.peek.rlast,
        ruser: narrow.r.peek.ruser
        });
        split_ar.deq;
      end
    endcase
    if (debug) begin
      $display("receive_first_r fired");
      $display("\tnarrow.r.peek ", fshow(narrow.r.peek));
      $display("\tsplit_ar.first ", fshow(split_ar.first));
    end
  endrule

  rule receive_second_r;
    first_r.deq;
    narrow.r.drop;
    split_ar.deq;
    if (!narrow.r.peek.rlast) begin
      $display("Error in toWider_AXI4_Slave: r burst transaction attempted - not supported.");
      $finish(0);
    end
    AXI4_RFlit #(id_, wide_, ruser_) new_r = AXI4_RFlit {
      rid: narrow.r.peek.rid,
      rdata: {narrow.r.peek.rdata, first_r.first},
      rresp: narrow.r.peek.rresp,
      rlast: narrow.r.peek.rlast,
      ruser: narrow.r.peek.ruser
      };
    in.r.put(new_r);
    if (debug) begin
      $display("receive_second_r fired");
      $display("\tnarrow.r.peek ", fshow(narrow.r.peek));
    end
  endrule

  return shim.slave;
endmodule

module sizedSerializeWithId_AXI4_Slave
  #( Integer writeDepth, Bit #(a) writeId
   , Integer readDepth, Bit #(a) readId
   , AXI4_Slave #(a, b, c, d, e, f, g, h) s)
  (AXI4_Slave #(a_, b, c, d, e, f, g, h));
  // axi shim
  let axiShim <- mkAXI4ShimFF;
  // fifofs of ids
  let wFF <- mkSizedFIFOF (writeDepth);
  let rFF <- mkSizedFIFOF (readDepth);
  // forwarding rules
  rule forward_aw;
    let awFlit <- get (axiShim.master.aw);
    wFF.enq (awFlit.awid);
    s.aw.put (mapAXI4_AWFlit_awid (constFn (writeId), awFlit));
  endrule
  rule forward_w;
    let wFlit <- get (axiShim.master.w);
    s.w.put (wFlit);
  endrule
  rule forward_b;
    let bFlit <- get (s.b);
    axiShim.master.b.put (mapAXI4_BFlit_bid (constFn (wFF.first), bFlit));
    wFF.deq;
  endrule
  rule forward_ar;
    let arFlit <- get (axiShim.master.ar);
    rFF.enq (arFlit.arid);
    s.ar.put (mapAXI4_ARFlit_arid (constFn (readId), arFlit));
  endrule
  rule forward_r;
    let rFlit <- get (s.r);
    axiShim.master.r.put (mapAXI4_RFlit_rid (constFn (rFF.first), rFlit));
    rFF.deq;
  endrule
  // interface
  return axiShim.slave;
endmodule

module sizedSerializeWithId_AXI4_Master
  #( Integer writeDepth, Bit #(a_) writeId
   , Integer readDepth, Bit #(a_) readId
   , AXI4_Master #(a, b, c, d, e, f, g, h) m)
  (AXI4_Master #(a_, b, c, d, e, f, g, h));
  // axi shim
  let axiShim <- mkAXI4ShimFF;
  // fifofs of ids
  let wFF <- mkSizedFIFOF (writeDepth);
  let rFF <- mkSizedFIFOF (readDepth);
  // forwarding rules
  rule forward_aw;
    let awFlit <- get (m.aw);
    wFF.enq (awFlit.awid);
    axiShim.slave.aw.put (mapAXI4_AWFlit_awid (constFn (writeId), awFlit));
  endrule
  rule forward_w;
    let wFlit <- get (m.w);
    axiShim.slave.w.put (wFlit);
  endrule
  rule forward_b;
    let bFlit <- get (axiShim.slave.b);
    m.b.put (mapAXI4_BFlit_bid (constFn (wFF.first), bFlit));
    wFF.deq;
  endrule
  rule forward_ar;
    let arFlit <- get (m.ar);
    rFF.enq (arFlit.arid);
    axiShim.slave.ar.put (mapAXI4_ARFlit_arid (constFn (readId), arFlit));
  endrule
  rule forward_r;
    let rFlit <- get (axiShim.slave.r);
    m.r.put (mapAXI4_RFlit_rid (constFn (rFF.first), rFlit));
    rFF.deq;
  endrule
  // interface
  return axiShim.master;
endmodule
