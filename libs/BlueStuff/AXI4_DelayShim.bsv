/*-
 * Copyright (c) 2023 Peter Rugg
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

package AXI4_DelayShim;

import AXI4 :: *;
import BlueBasics :: *;
import SourceSink :: *;

import FIFOF :: *;
import FF :: *;
import Vector :: *;

// An AXI4 shim that delays transactions by the given parameter
module mkAXI4_DelayShim #(NumProxy#(depth) _dummy, Bit#(16) delay)
  (AXI4_Shim#(id_, addr_, data_, awuser_, wuser_, buser_, aruser_, ruser_));

  let awff <- mkFIFOF;
  let wff <- mkFIFOF;
  FF#(AXI4_BFlit#(id_, buser_), depth) bff <- mkUGFFDelay(delay);
  FF#(AXI4_ARFlit#(id_, addr_, aruser_), depth) arff <- mkUGFFDelay(delay);
  let rff <- mkFIFOF;
  interface AXI4_Master master;
    interface aw = toSource(awff);
    interface w = toSource(wff);
    interface b = toSink(bff);
    interface ar = toSource(arff);
    interface r = toSink(rff);
  endinterface
  interface AXI4_Slave slave;
    interface aw = toSink(awff);
    interface w = toSink(wff);
    interface b = toSource(bff);
    interface ar = toSink(arff);
    interface r = toSource(rff);
  endinterface
  interface clear = error("clear not supported");
endmodule

// AXI4 delay shim with additional slave port to configure the latency
module mkAXI4_ConfigurableDelayShim #(NumProxy#(depth) depthProxy, Bit#(16) defaultDelay)
  (Tuple2 #( AXI4_Shim#(id_, addr_, data_, awuser_, wuser_, awuser_, aruser_, aruser_)
           , AXI4_Slave#(id_, addr_, data_, awuser_, wuser_, awuser_, aruser_, aruser_) ))
  provisos ( Add#(a__, 16, data_) /* 16 bit latency taken from data */
           , Add#(b__, 12, addr_) /* Configuration map taken as a 12 bit page */ );

  let configShim <- mkAXI4Shim;
  Reg#(Bit#(16)) delay <- mkReg(defaultDelay);

  let delayShim <- mkAXI4_DelayShim(depthProxy, delay);

  rule writeConfig;
    let awflit <- get(configShim.master.aw);
    let wflit <- get(configShim.master.w);
    let bresp = SLVERR;
    Bit#(12) addr = truncate(awflit.awaddr);
    if (addr == 0) begin
      Bit#(16) newDelay = truncate(wflit.wdata);
      delay <= newDelay;
      $display("%m: changing latency from ", fshow(delay), " to ", fshow(newDelay), " cycles.");
      bresp = OKAY;
    end
    let bflit = AXI4_BFlit { bid: awflit.awid
                           , bresp: bresp
                           , buser: awflit.awuser };
    configShim.master.b.put(bflit);
  endrule

  rule readConfig;
    let arflit <- get(configShim.master.ar);
    Bit#(data_) rdata = ?;
    let rresp = SLVERR;
    Bit#(12) addr = truncate(arflit.araddr);
    if (addr == 12'b0) begin
      rdata = zeroExtend(delay);
      rresp = OKAY;
    end
    let rflit = AXI4_RFlit { rid: arflit.arid
                           , rresp: rresp
                           , rdata: rdata
                           , rlast: True
                           , ruser: arflit.aruser };
    configShim.master.r.put(rflit);
  endrule

  return tuple2(delayShim, configShim.slave);
endmodule

module mkAXI4_SelfConfigDelayShim #(NumProxy#(depth) depthProxy, Bit#(16) defaultDelay, Bit#(addr_) configPageBase)
  (AXI4_Shim#(id_, addr_, data_, awuser_, awuser_, awuser_, aruser_, aruser_))
  provisos ( Add#(a__, 16, data_) /* 16 bit latency taken from data */
           , Add#(b__, 12, addr_) /* Configuration map taken as a 12 bit page */ );

  function Vector#(2, Bool) route (Bit#(addr_) addr);
    Bool toConfig = addr >> 12 == configPageBase >> 12;
    return cons(!toConfig, cons(toConfig, nil));
  endfunction

  let inShim <- mkAXI4Shim;
  let configDelayShim <- mkAXI4_ConfigurableDelayShim(depthProxy, defaultDelay);
  match {.delayShim, .configSlave} = configDelayShim;

  mkAXI4Bus (route, cons(inShim.master, nil), cons(delayShim.slave, cons(configSlave, nil)));

  interface master = debugAXI4_Master(delayShim.master, $format("self config outgoing"));
  interface slave = debugAXI4_Slave(inShim.slave, $format("self config incoming"));
  interface clear = error("clear not supported");
endmodule

endpackage
