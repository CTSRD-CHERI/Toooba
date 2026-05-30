/*-
 * Copyright (c) 2018-2022 Alexandre Joannou
 * All rights reserved.
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

package AXI4_Firewall;

// AXI4 imports
import AXI4_Types :: *;
import AXI4_Common_Types :: *;
import AXI4_Channels_Utils :: *;

// BlueBasics import
import BlueBasics :: *;

// Standard
import FIFOF :: *;

////////////////////////////////////////////////////////////////////////////////

/*
module mkSimpleAXI4Master_Firewall #( Integer timeoutCycles
                                    , AXI4_Master #(a, b, c, d, e, f, g, h) m)
                                    (AXI4_Master #(a, b, c, d, e, f, g, h));

  let bTimeoutReg <- mkReg(Invalid);
  let rTimeoutReg <- mkReg(Invalid);
  let bIDReg <- mkRegU;
  let rIDReg <- mkRegU;
  let bRspFF <- mkFIFOF;
  let rRspFF <- mkFIFOF;

  (* descending_urgency = "forwardBFlit, countDownBTimeout" *)
  rule forwardBFlit (bRspFF.notEmpty && m.b.canPut);
    m.b.put(bRspFF.first);
    bRspFF.deq;
    bTimeoutReg <= Invalid;
  endrule
  rule countDownBTimeout (isValid(bTimeoutReg));
    let newCnt = bTimeoutReg.Valid - 1;
    if (newCnt == 0) begin
      m.b.put(AXI4_BFlit {bid: bIDReg, bresp: DECERR, buser: ?});
      bTimeoutReg <= Invalid;
    end else bTimeoutReg <= Valid(newCnt);
  endrule

  (* descending_urgency = "forwardRFlit, countDownRTimeout" *)
  rule forwardRFlit (rRspFF.notEmpty && m.r.canPut);
    m.r.put(rRspFF.first);
    rRspFF.deq;
    rTimeoutReg <= Invalid;
  endrule
  rule countDownRTimeout (isValid(rTimeoutReg));
    let newCnt = rTimeoutReg.Valid - 1;
    if (newCnt == 0) begin
      m.r.put(AXI4_RFlit { rid: rIDReg
                         , rdata: ?
                         , rresp: DECERR
                         , rlast: True
                         , ruser: ? });
      rTimeoutReg <= Invalid;
    end else rTimeoutReg <= Valid(newCnt);
  endrule

  //////////////////////////////////////////////////////////////////////////////

  interface aw = interface Source;
    method canPeek = !isValid(bTimeoutReg);
    method peek if (!isValid(bTimeoutReg)) = m.aw.peek;
    method drop if (!isValid(bTimeoutReg)) = action
      m.aw.drop;
      bTimeoutReg <= Valid(fromInteger(timeoutCycles));
      bIDReg <= m.aw.peek.awid;
    endaction;
  endinterface;
  interface w = m.w;
  interface b = toSink(bRspFF);

  interface ar = interface Source;
    method canPeek = !isValid(rTimeoutReg);
    method peek if (!isValid(rTimeoutReg)) = m.ar.peek;
    method drop if (!isValid(rTimeoutReg)) = action
      m.ar.drop;
      rTimeoutReg <= Valid(fromInteger(timeoutCycles));
      rIDReg <= m.ar.peek.arid;
    endaction;
  endinterface;
  interface r = toSink(rRspFF);

endmodule
*/

module mkSimpleAXI4Slave_Firewall #( Integer timeoutCycles
                                   , AXI4_Slave #(a, b, c, d, e, f, g, h) s)
                                   (AXI4_Slave #(a, b, c, d, e, f, g, h));

  let bTimeoutReg <- mkReg(Invalid);
  let rTimeoutReg <- mkReg(Invalid);
  let bIDReg <- mkRegU;
  let rIDReg <- mkRegU;
  let bRspFF <- mkFIFOF;
  let rRspFF <- mkFIFOF;
  let awReqFF <- mkFIFOF;
  let  wReqFF <- mkFIFOF;
  let arReqFF <- mkFIFOF;
  let rLenReg <- mkRegU;

  (* descending_urgency = "forwardBFlit, countDownBTimeout" *)
  rule forwardBFlit (s.b.canPeek);
    s.b.drop;
    bRspFF.enq(s.b.peek);
    bTimeoutReg <= Invalid;
    $display("%0t - firewall says: returning legitimate write rsp flit", $time);
  endrule
  rule countDownBTimeout (isValid(bTimeoutReg));
    let newCnt = bTimeoutReg.Valid - 1;
    if (newCnt == 0) begin
      //bRspFF.enq(AXI4_BFlit {bid: bIDReg, bresp: DECERR, buser: ?});
      bRspFF.enq(AXI4_BFlit {bid: bIDReg, bresp: OKAY, buser: ?});
      $display("%0t - firewall says: returning timed out write flit", $time);
      awReqFF.clear;
      wReqFF.clear;
      bTimeoutReg <= Invalid;
    end else bTimeoutReg <= Valid(newCnt);
  endrule
  rule forwardAWFlit; s.aw.put(awReqFF.first); awReqFF.deq; endrule
  rule forwardWFlit; s.w.put(wReqFF.first); wReqFF.deq; endrule

  (* descending_urgency = "forwardRFlit, countDownRTimeout" *)
  rule forwardRFlit (s.r.canPeek);
    s.r.drop;
    rRspFF.enq(s.r.peek);
    $display("%0t - firewall says: returning legitimate read rsp flit", $time);
    rTimeoutReg <= Invalid;
  endrule
  rule countDownRTimeout (isValid(rTimeoutReg));
    let newCnt = rTimeoutReg.Valid - 1;
    if (newCnt == 0) begin
      let last = rLenReg == 0;
      //rRspFF.enq(AXI4_RFlit { rid: rIDReg
      //                      , rdata: ?
      //                      , rresp: DECERR
      //                      , rlast: last
      //                      , ruser: ? });
      rRspFF.enq(AXI4_RFlit { rid: rIDReg
                            , rdata: 'hdeadbeef
                            , rresp: OKAY
                            , rlast: last
                            , ruser: ? });
      $display("%0t - firewall says: returning timed out read flit", $time);
      rLenReg <= rLenReg - 1;
      if (last) begin
        rTimeoutReg <= Invalid;
        arReqFF.clear;
      end
    end else rTimeoutReg <= Valid(newCnt);
  endrule
  rule forwardARFlit; s.ar.put(arReqFF.first); arReqFF.deq; endrule

  //////////////////////////////////////////////////////////////////////////////

  interface aw = interface Sink;
    method canPut = !isValid(bTimeoutReg);
    method put(x) if (!isValid(bTimeoutReg)) = action
      awReqFF.enq(x);
      bTimeoutReg <= Valid(fromInteger(timeoutCycles));
      bIDReg <= x.awid;
    endaction;
  endinterface;
  interface w = interface Sink;
    method canPut = wReqFF.notFull;
    method put = wReqFF.enq;
  endinterface;
  interface b = toSource(bRspFF);

  interface ar = interface Sink;
    method canPut = !isValid(rTimeoutReg);
    method put(x) if (!isValid(rTimeoutReg)) = action
      arReqFF.enq(x);
      rTimeoutReg <= Valid(fromInteger(timeoutCycles));
      rIDReg <= x.arid;
      rLenReg <= x.arlen;
    endaction;
  endinterface;
  interface r = toSource(rRspFF);

endmodule

endpackage
