/*-
 * Copyright (c) 2018-2021 Alexandre Joannou
 * Copyright (c) 2023 Peter Rugg
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

import AXI4 :: *;
import BlueUtils :: *;
import Connectable :: *;
import AXI4_DelayShim :: *;
import BlueBasics :: *;
import FIFO :: *;

typedef 32 AddrWidth;

module top (Empty);
  Bit#(AddrWidth) configAddr = 'h1000;

  NumProxy#(4) depthProxy = error("Don't look inside a proxy");

  AXI4_Shim#(1, AddrWidth, 32, 0, 0, 0, 0, 0)
    delay <- mkAXI4_SelfConfigDelayShim(depthProxy, 16'd100, configAddr);
  AXI4_Slave#(1, AddrWidth, 32, 0, 0, 0, 0, 0)
    mem <- mkAXI4Mem(512, UnInit);

  mkConnection(mem, delay.master);

  Reg#(Bit#(32)) count <- mkReg(0);
  rule incCount;
    count <= count + 1;
  endrule

  FIFO#(Bit#(32)) inFlight <- mkFIFO;

  Reg#(Bit#(8)) testNum <- mkReg(0);

  function craftAW(addr);
    return AXI4_AWFlit { awaddr: addr
                       , awid: 0
                       , awsize: 4
                       , awlen: 0
                       , awregion: 0
                       , awburst: INCR
                       , awprot: 0
                       , awcache: 0
                       , awlock: ?
                       , awqos: 0
                       , awuser: 0 };
  endfunction

  function craftW(data);
    return AXI4_WFlit { wdata: data
                      , wstrb: ~0
                      , wlast: True
                      , wuser: 0 };
  endfunction

  function craftAR(addr);
    return AXI4_ARFlit { araddr: addr
                       , arid: 0
                       , arsize: 4
                       , arlen: 0
                       , arregion: 0
                       , arburst: INCR
                       , arprot: 0
                       , arcache: 0
                       , arlock: ?
                       , arqos: 0
                       , aruser: 0 };
  endfunction

  Reg#(Bool) test0Sent <- mkReg(False);
  rule test0In (testNum == 0 && !test0Sent);
    delay.slave.aw.put(craftAW(32'h0));
    delay.slave.w.put(craftW(32'hdeadbeef));
    inFlight.enq(count);
    test0Sent <= True;
  endrule

  rule test0Out (testNum == 0);
    let bflit <- get(delay.slave.b);
    if (bflit.bresp != OKAY) begin
        $display("Error: response not okay");
        $finish();
    end
    let enqTime <- get(inFlight);
    if (count - enqTime < 100 || count - enqTime > 110) begin
        $display("Error: unexpected delay");
        $finish();
    end
    $display("Test 0 passed");
    testNum <= testNum + 1;
  endrule

  Reg#(Bool) test1Configured <- mkReg(False);
  rule test1Config(testNum == 1 && !test1Configured);
    $display("Configurating");
    delay.slave.aw.put(craftAW(configAddr));
    delay.slave.w.put(craftW(32'd300));
    test1Configured <= True;
  endrule

  Reg#(Bool) test1Sent <- mkReg(False);
  rule test1In (testNum == 1 && test1Configured && !test1Sent);
    $display("Sending");
    let bflit <- get(delay.slave.b);
    if (bflit.bresp != OKAY) begin
        $display("Error: response not okay");
        $finish();
    end
    delay.slave.aw.put(craftAW(0));
    delay.slave.w.put(craftW(32'h012345678));
    inFlight.enq(count);
    test1Sent <= True;
  endrule

  rule test1Out (testNum == 1 && test1Sent);
    let bflit <- get(delay.slave.b);
    if (bflit.bresp != OKAY) begin
        $display("Error: response not okay");
        $finish();
    end
    let enqTime <- get(inFlight);
    if (count - enqTime < 300 || count - enqTime > 310) begin
        $display("Error: unexpected delay");
        $finish();
    end
    $display("Test 1 passed");
    testNum <= testNum + 1;
  endrule

  Reg#(Bool) test2Sent <- mkReg(False);
  rule test2In (testNum == 2 && !test2Sent);
    delay.slave.ar.put(craftAR(0));
    inFlight.enq(count);
    test2Sent <= True;
  endrule

  rule test2Out (testNum == 2);
    let rflit <- get(delay.slave.r);
    if (rflit.rresp != OKAY) begin
        $display("Error: response not okay");
        $finish();
    end
    let enqTime <- get(inFlight);
    if (count - enqTime < 300 || count - enqTime > 310) begin
        $display("Error: unexpected delay");
        $finish();
    end
    if (rflit.rdata != 32'h012345678) begin
        $display("Error: unexpected rdata");
        $finish();
    end
    $display("Test 2 passed");
    testNum <= testNum + 1;
  endrule

  Reg#(Bool) test3Sent <- mkReg(False);
  rule test3In (testNum == 3 && !test3Sent);
    delay.slave.ar.put(craftAR(configAddr));
    inFlight.enq(count);
    test2Sent <= True;
  endrule

  rule test3Out (testNum == 3);
    let rflit <- get(delay.slave.r);
    if (rflit.rresp != OKAY) begin
        $display("Error: response not okay");
        $finish();
    end
    let enqTime <- get(inFlight);
    if (count - enqTime > 10) begin
        $display("Error: unexpected delay");
        $finish();
    end
    if (rflit.rdata != 32'd300) begin
        $display("Error: unexpected rdata");
        $finish();
    end
    $display("Test 3 passed");
    $finish();
  endrule
endmodule
