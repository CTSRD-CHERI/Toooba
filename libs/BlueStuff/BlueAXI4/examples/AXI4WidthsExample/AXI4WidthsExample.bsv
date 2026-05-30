/*-
 * Copyright (c) 2023 Peter Rugg
 * Copyright (c) 2022 Alexandre Joannou
 * All rights reserved.
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

package AXI4WidthsExample;

import SourceSink :: *;
import BlueAXI4 :: *;
import BlueUtils :: *;
import BlueBasics :: *;
import Connectable :: *;
import FIFOF :: *;
import FIFO :: *;
import Vector :: *;
import GetPut :: *;

module mkRNG #(a seed) (Get #(a)) provisos (Bits #(a, sz), Arith #(a));
  let state <- mkReg (seed);
  method get = actionvalue
    let newState = state * 6364136223846793005 + 1;
    state <= newState;
    return newState;
  endactionvalue;
endmodule

module testAXI4ReadWidths (Empty);
  Vector#(2, AXI4_Slave#(0, 8, 512, 0, 0, 0, 0, 0)) mems <- replicateM(mkAXI4Mem(512, UnInit));
  let oracleMem = mems[0];
  let testMem = mems[1];
  NumProxy#(1) one = ?;
  Tuple2#(AXI4_Slave#(0, 8, 64, 0, 0, 0, 0, 0), AXI4_Master#(0, 8, 512, 0, 0, 0, 0, 0))
      narrowSw_wideMw <- mkAXI4DataWidthShim_NarrowToWide(one, one);
  match {.narrowSw, .wideMw} = narrowSw_wideMw;
  Tuple2#(AXI4_Slave#(0, 8, 512, 0, 0, 0, 0, 0), AXI4_Master#(0, 8, 64, 0, 0, 0, 0, 0))
      wideSn_narrowMn <- mkAXI4DataWidthShim_WideToNarrow(one, one);
  match {.wideSn, .narrowMn} = wideSn_narrowMn;

  Tuple2#(AXI4_Slave#(0, 8, 32, 0, 0, 0, 0, 0), AXI4_Master#(0, 8, 64, 0, 0, 0, 0, 0))
      narrowSw_wideMw_inner <- mkAXI4DataWidthShim_NarrowToWide(one, one);
  match {.narrowSw_inner, .wideMw_inner} = narrowSw_wideMw_inner;
  Tuple2#(AXI4_Slave#(0, 8, 64, 0, 0, 0, 0, 0), AXI4_Master#(0, 8, 32, 0, 0, 0, 0, 0))
      wideSn_narrowMn_inner <- mkAXI4DataWidthShim_WideToNarrow(one, one);
  match {.wideSn_inner, .narrowMn_inner} = wideSn_narrowMn_inner;

  mkConnection(wideMw, testMem);
  mkConnection(narrowMn, wideSn_inner);
  mkConnection(wideMw_inner, narrowSw);
  mkConnection(narrowMn_inner, narrowSw_inner);

  Reg#(Bit#(8)) size <- mkReg(1);
  Reg#(Bit#(6)) offset <- mkReg(0);
  FIFO#(Maybe#(Tuple2#(Bit#(8), Bit#(6)))) trackFF <- mkFIFO;
  Reg#(Bool) init <- mkReg(False);
  Reg#(Bool) setupSent <- mkReg(False);

  rule setup(!setupSent);
      let awflit = AXI4_AWFlit { awaddr : 0
                               , awid : 0
                               , awsize : 64
                               , awlen: 0
                               , awregion: 0
                               , awburst: INCR
                               , awprot: 0
                               , awcache: 0
                               , awlock: ?
                               , awqos: 0
                               , awuser : 0};
      let wflit = AXI4_WFlit { wdata: 'h01234567_89abcdef_02468ace_13579bdf_048c26ae_159d37bf_082a4c6e_193b5d7f_fedcba98_76543210_00000001_11111112_22222223_33333334_44444445_55555556
                             , wstrb: ~0
                             , wlast: True
                             , wuser: 0};
      oracleMem.aw.put(awflit);
      wideSn.aw.put(awflit);
      oracleMem.w.put(wflit);
      wideSn.w.put(wflit);
      setupSent <= True;
  endrule

  rule drainB;
      oracleMem.b.drop;
      wideSn.b.drop;
      init <= True;
  endrule

  rule emitReqs(init);
      Bit#(6) nextOffset = truncate(zeroExtend(offset) + size);
      Bit#(8) nextSize = nextOffset == 0 ? size << 1 : size;
      if (nextSize <= 64) begin
          let arflit = AXI4_ARFlit { araddr: zeroExtend(offset)
                                   , arid: 0
                                   , aruser: 0
                                   , arlen: 0
                                   , arburst: INCR
                                   , arcache: 0
                                   , arlock: ?
                                   , arregion: 0
                                   , arqos: 0
                                   , arprot: 0
                                   , arsize: toAXI4_Size(zeroExtend(size)).Valid};
          wideSn.ar.put(arflit);
          oracleMem.ar.put(arflit);
          trackFF.enq(Valid(tuple2(size, offset)));
          size <= nextSize;
          offset <= nextOffset;
      end else begin
          trackFF.enq(Invalid);
      end
  endrule

  function getRelevantData(Bit#(512) data, Bit#(6) offset, Bit#(8) size);
      Bit#(9) bitOffset = {offset, 0};
      Bit#(11) bitSize = {size, 0};
      return (data >> bitOffset) & ~((~0) << bitSize);
  endfunction

  rule compareRsps(isValid(trackFF.first));
      match {.size, .offset} = trackFF.first.Valid;
      let testR <- get(wideSn.r);
      let oracleR <- get(oracleMem.r);
      let testData = getRelevantData(oracleR.rdata, offset, size);
      let oracleData = getRelevantData(testR.rdata, offset, size);
      $display("reqsize: ", fshow(size), ", reqoffset: ", fshow(offset)
           , "\noracle: ", fshow(oracleR)
           , "\n        ", fshow(oracleData)
           , "\ntest  : ", fshow(testR)
           , "\n        ", fshow(testData));
      if(testData != oracleData) begin
          $display("Fail");
          $finish;
      end
      trackFF.deq();
  endrule

  rule succeed(!isValid(trackFF.first));
      $display("success");
      $finish;
  endrule
endmodule

module testAXI4WriteWidths (Empty);
  Vector#(2, AXI4_Slave#(0, 8, 512, 0, 0, 0, 0, 0)) mems <- replicateM(mkAXI4Mem(512, UnInit));
  let oracleMem = mems[0];
  let testMem = mems[1];
  NumProxy#(1) one = ?;
  Tuple2#(AXI4_Slave#(0, 8, 64, 0, 0, 0, 0, 0), AXI4_Master#(0, 8, 512, 0, 0, 0, 0, 0))
      narrowSw_wideMw <- mkAXI4DataWidthShim_NarrowToWide(one, one);
  match {.narrowSw, .wideMw} = narrowSw_wideMw;
  Tuple2#(AXI4_Slave#(0, 8, 512, 0, 0, 0, 0, 0), AXI4_Master#(0, 8, 64, 0, 0, 0, 0, 0))
      wideSn_narrowMn <- mkAXI4DataWidthShim_WideToNarrow(one, one);
  match {.wideSn, .narrowMn} = wideSn_narrowMn;

  Tuple2#(AXI4_Slave#(0, 8, 32, 0, 0, 0, 0, 0), AXI4_Master#(0, 8, 64, 0, 0, 0, 0, 0))
      narrowSw_wideMw_inner <- mkAXI4DataWidthShim_NarrowToWide(one, one);
  match {.narrowSw_inner, .wideMw_inner} = narrowSw_wideMw_inner;
  Tuple2#(AXI4_Slave#(0, 8, 64, 0, 0, 0, 0, 0), AXI4_Master#(0, 8, 32, 0, 0, 0, 0, 0))
      wideSn_narrowMn_inner <- mkAXI4DataWidthShim_WideToNarrow(one, one);
  match {.wideSn_inner, .narrowMn_inner} = wideSn_narrowMn_inner;

  mkConnection(wideMw, testMem);
  mkConnection(narrowMn, wideSn_inner);
  mkConnection(wideMw_inner, narrowSw);
  mkConnection(narrowMn_inner, narrowSw_inner);

  Reg#(Bit#(8)) size <- mkReg(1);
  Reg#(Bit#(6)) offset <- mkReg(0);
  FIFOF#(Maybe#(Tuple2#(Bit#(8), Bit#(6)))) trackFF <- mkFIFOF;
  Reg#(Bool) init <- mkReg(False);
  Reg#(Bool) setupSent <- mkReg(False);
  Get #(Bit #(512)) rng <- mkRNG (~0);

  rule setup(!setupSent);
      let awflit = AXI4_AWFlit { awaddr : 0
                               , awid : 0
                               , awsize : 64
                               , awlen: 0
                               , awregion: 0
                               , awburst: INCR
                               , awprot: 0
                               , awcache: 0
                               , awlock: ?
                               , awqos: 0
                               , awuser : 0};
      let wflit = AXI4_WFlit { wdata: 'h01234567_89abcdef_02468ace_13579bdf_048c26ae_159d37bf_082a4c6e_193b5d7f_fedcba98_76543210_00000001_11111112_22222223_33333334_44444445_55555556
                             , wstrb: ~0
                             , wlast: True
                             , wuser: 0};
      oracleMem.aw.put(awflit);
      wideSn.aw.put(awflit);
      oracleMem.w.put(wflit);
      wideSn.w.put(wflit);
      setupSent <= True;
  endrule

  rule drainB (!init);
      oracleMem.b.drop;
      wideSn.b.drop;
      init <= True;
  endrule

  rule emitReqs(init && !trackFF.notEmpty);
      Bit#(6) nextOffset = truncate(zeroExtend(offset) + size);
      Bit#(8) nextSize = nextOffset == 0 ? size << 1 : size;
      Bit#(512) val <- rng.get;
      if (nextSize <= 64) begin
          AXI4_AWFlit #(0, 8, 0) awflit = AXI4_AWFlit { awaddr: zeroExtend(offset)
                                   , awid: 0
                                   , awuser: 0
                                   , awlen: 0
                                   , awburst: INCR
                                   , awcache: 0
                                   , awlock: ?
                                   , awregion: 0
                                   , awqos: 0
                                   , awprot: 0
                                   , awsize: toAXI4_Size(zeroExtend(size)).Valid};
          AXI4_WFlit #(512, 0) wflit = AXI4_WFlit { wdata: val
                                 , wstrb: ~(~0<<size)<<offset
                                 , wlast: True
                                 , wuser: 0};
          wideSn.aw.put(awflit);
          wideSn.w.put(wflit);
          oracleMem.aw.put(awflit);
          oracleMem.w.put(wflit);
          $display ("reqAW: ", fshow (awflit));
          $display ("reqW: ", fshow (wflit));
          trackFF.enq(Valid(tuple2(size, offset)));
          size <= nextSize;
          offset <= nextOffset;
      end else begin
          trackFF.enq(Invalid);
      end
  endrule

  rule drainBB (init);
    oracleMem.b.drop;
    wideSn.b.drop;
    let arflit = AXI4_ARFlit { araddr: 0
                             , arid: 0
                             , aruser: 0
                             , arlen: 0
                             , arburst: INCR
                             , arcache: 0
                             , arlock: ?
                             , arregion: 0
                             , arqos: 0
                             , arprot: 0
                             , arsize: 64 };
    oracleMem.ar.put(arflit);
    wideSn.ar.put(arflit);
  endrule

  rule compareRsps(isValid(trackFF.first));
      match {.size, .offset} = trackFF.first.Valid;
      let testR <- get(wideSn.r);
      let oracleR <- get(oracleMem.r);
      let testData = oracleR.rdata;
      let oracleData = testR.rdata;
      $display("reqsize: ", fshow(size), ", reqoffset: ", fshow(offset)
           , "\noracle: ", fshow(oracleR)
           , "\ntest  : ", fshow(testR) );
      if(testData != oracleData) begin
          $display("Fail");
          $finish;
      end
      trackFF.deq();
  endrule

  rule succeed(!isValid(trackFF.first));
      $display("success");
      $finish;
  endrule
endmodule

endpackage
