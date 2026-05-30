/*-
 * Copyright (c) 2018-2019 Alexandre Joannou
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
import BlueBasics :: *;
import Recipe :: *;

import Connectable :: *;
import FIFOF :: *;
import SpecialFIFOs :: *;

typedef   0 ID_sz;
typedef  32 ADDR_sz;
typedef  32 DATA_sz;
typedef  64 WIDEDATA_sz;
typedef   0 AWUSER_sz;
typedef   0 WUSER_sz;
typedef   0 BUSER_sz;
typedef   0 ARUSER_sz;
typedef   0 RUSER_sz;

`define PARAMS ID_sz, ADDR_sz, DATA_sz, AWUSER_sz, WUSER_sz, BUSER_sz, ARUSER_sz, RUSER_sz
`define WIDEPARAMS ID_sz, ADDR_sz, WIDEDATA_sz, AWUSER_sz, WUSER_sz, BUSER_sz, ARUSER_sz, RUSER_sz

// debug helpers

Integer verbosity_level = 0;
function Action vPrint (Integer lvl, Fmt fmt) =
  action if (verbosity_level >= lvl) $display ("%0t - ", $time, fmt); endaction;

function Action die (Fmt fmt) = action
  $display ("%0t - ", $time, fmt);
  $finish;
endaction;

function Action doAssert (Bool cond, Fmt fmt) = cond ? noAction : die(fmt);

function AXI4_AWFlit#(ID_sz, ADDR_sz, AWUSER_sz)
  craftAW (Bit#(ADDR_sz) addr, AXI4_Size sz, AXI4_Len len) =
    AXI4_AWFlit { awid:     0
                , awaddr:   addr
                , awlen:    len
                , awsize:   sz
                , awburst:  INCR
                , awlock:   NORMAL
                , awcache:  0
                , awprot:   0
                , awqos:    0
                , awregion: 0
                , awuser:   0
                };

function AXI4_WFlit#(DATA_sz, WUSER_sz)
  craftW (Bit#(DATA_sz) data, Bit#(TDiv#(DATA_sz, 8)) strb, Bool last) =
  AXI4_WFlit { wdata: data, wstrb: strb, wlast: last, wuser: 0 };

function Recipe testRecipe ( AXI4_Slave#(`PARAMS) inSlave
                           , AXI4_Master#(`WIDEPARAMS) outMaster
                           , PulseWire done ) = rPar(rBlock(
  rSeq(rBlock(
    action
      let awflit = craftAW(32'h33333300, 4, 4); // means 5 flits
      inSlave.aw.put(awflit);
      vPrint(0, $format("Sending: ", fshow(awflit)));
    endaction
  , action
      let wflit = craftW (32'h00112233, 'hf, False);
      inSlave.w.put(wflit);
      vPrint(0, $format("Sending: ", fshow(wflit)));
    endaction
  , action
      let wflit = craftW (32'h44556677, 'hf, False);
      inSlave.w.put(wflit);
      vPrint(0, $format("Sending: ", fshow(wflit)));
    endaction
  , action
      let wflit = craftW (32'h8899aabb, 'hf, False);
      inSlave.w.put(wflit);
      vPrint(0, $format("Sending: ", fshow(wflit)));
    endaction
  , action
      let wflit = craftW (32'hccddeeff, 'hf, False);
      inSlave.w.put(wflit);
      vPrint(0, $format("Sending: ", fshow(wflit)));
    endaction
  , action
      let wflit = craftW (32'heeeeeeee, 'hf, True);
      inSlave.w.put(wflit);
      vPrint(0, $format("Sending: ", fshow(wflit)));
    endaction
  ))
  , rSeq(rBlock(
    action
      let awflit <- get(outMaster.aw);
      let testflit = craftAW(32'h33333300, 4, 4);
      vPrint(0, $format("Received: ", fshow(awflit)));
      doAssert(awflit.awaddr == testflit.awaddr, $format("awaddr fail"));
      doAssert(awflit.awsize == testflit.awsize, $format("awsize fail"));
      doAssert(awflit.awlen == testflit.awlen, $format("awlen fail"));
    endaction
  , action
      let wflit <- get(outMaster.w);
      let testflit = craftW (32'h00112233, 'hf, False);
      vPrint(0, $format("Received: ", fshow(wflit)));
      doAssert(     truncate (wflit.wdata & beToMask (wflit.wstrb))
                 == (testflit.wdata & beToMask (testflit.wstrb))
              , $format("data fail"));
      doAssert(wflit.wlast == testflit.wlast, $format("last fail"));
    endaction
  , action
      let wflit <- get(outMaster.w);
      let testflit = craftW (32'h44556677, 'hf, False);
      vPrint(0, $format("Received: ", fshow(wflit)));
      doAssert(     truncateLSB (wflit.wdata & beToMask (wflit.wstrb))
                 == (testflit.wdata & beToMask (testflit.wstrb))
              , $format("data fail"));
      doAssert(wflit.wlast == testflit.wlast, $format("last fail"));
    endaction
  , action
      let wflit <- get(outMaster.w);
      let testflit = craftW (32'h8899aabb, 'hf, False);
      vPrint(0, $format("Received: ", fshow(wflit)));
      doAssert(     truncate (wflit.wdata & beToMask (wflit.wstrb))
                 == (testflit.wdata & beToMask (testflit.wstrb))
              , $format("data fail"));
      doAssert(wflit.wlast == testflit.wlast, $format("last fail"));
    endaction
  , action
      let wflit <- get(outMaster.w);
      let testflit = craftW (32'hccddeeff, 'hf, False);
      vPrint(0, $format("Received: ", fshow(wflit)));
      doAssert(     truncateLSB (wflit.wdata & beToMask (wflit.wstrb))
                 == (testflit.wdata & beToMask (testflit.wstrb))
              , $format("data fail"));
      doAssert(wflit.wlast == testflit.wlast, $format("last fail"));
    endaction
  , action
      let wflit <- get(outMaster.w);
      let testflit = craftW (32'heeeeeeee, 'hf, False);
      vPrint(0, $format("Received: ", fshow(wflit)));
      doAssert(     truncate (wflit.wdata & beToMask (wflit.wstrb))
                 == (testflit.wdata & beToMask (testflit.wstrb))
              , $format("data fail"));
      doAssert(wflit.wlast == testflit.wlast, $format("last fail"));
      done.send;
    endaction
  ))
));

module top (Empty);

  AXI4_Shim#(`PARAMS) inShim <- mkAXI4Shim;
  AXI4_Shim#(`WIDEPARAMS) outShim <- mkAXI4Shim;
  NumProxy#(4) inDepth = error("don't look inside a proxy");
  NumProxy#(4) outDepth = error("don't look inside a proxy");
  Tuple2#(AXI4_Slave#(`PARAMS), AXI4_Master#(`WIDEPARAMS))
    tpl <- mkAXI4DataWidthShim_NarrowToWide(inDepth, outDepth);
  match {.slv, .mst} = tpl;
  mkConnection(inShim.master, slv);
  mkConnection(mst, outShim.slave);

  PulseWire done <- mkPulseWire;
  RecipeFSM m <- mkRecipeFSM(testRecipe(inShim.slave, outShim.master, done));

  // Start runing the recipe
  rule run;
    $display("starting at time %0t", $time);
    $display("------------------------------------------");
    m.trigger;
  endrule

  // On the recipe's last cyle, terminate simulation
  rule endSim (done);
    $display("------------------------------------------");
    $display("finishing at time %0t", $time);
    $finish(0);
  endrule

endmodule

`undef PARAMS
