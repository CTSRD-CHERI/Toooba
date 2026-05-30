/*-
 * Copyright (c) 2018-2023 Alexandre Joannou
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

import BlueBasics :: *;
import BlueAXI4 :: *;
import BlueAvalon :: *;
import AXI4_Avalon :: *;

import StmtFSM :: *;

import Connectable :: *;

typedef 1 NMASTERS;
typedef 1 NSLAVES;

typedef TExp#(19) SlaveWidth;

typedef 0 MID_sz;
typedef TAdd#(MID_sz, TLog#(NMASTERS)) SID_sz;
typedef 32 ADDR_sz;
typedef 32 DATA_sz;
typedef  0 AWUSER_sz;
typedef  0 WUSER_sz;
typedef  0 BUSER_sz;
typedef  0 ARUSER_sz;
typedef  0 RUSER_sz;

`define PARAMS ADDR_sz, DATA_sz, AWUSER_sz, WUSER_sz, BUSER_sz, ARUSER_sz, RUSER_sz
`define MPARAMS MID_sz, `PARAMS
`define SPARAMS SID_sz, `PARAMS
`define MASTER_T AXI4_Master#(`MPARAMS)
`define SLAVE_T  AXI4_Slave#(`SPARAMS)
`define MASTER_SYNTH_T AXI4_Master_Sig#(`MPARAMS)
`define SLAVE_SYNTH_T  AXI4_Slave_Sig#(`SPARAMS)

`define DELAY 5

Integer verboselvl = 3;
function Action lvlprint (Integer lvl, Fmt msg) =
  when (verboselvl >= lvl, $display ("<%0t> ", $time, msg));

module mkPipelinedAvalonMMAgent (PipelinedAvalonMMAgent #(ADDR_sz, DATA_sz));
  NumProxy #(2) depthProxy = ?;
  let {master, ifc} <- pipelinedAvalonMMAgentTransactor (depthProxy);

  // artificial dealy in the agent
  let delay <- mkReg (`DELAY);
  rule dec_delay (delay > 0); delay <= delay - 1; endrule

  rule handleReq (delay == 0);
    let req = master.req.peek;
    AvalonMMResponse #(DATA_sz) rsp = case (req.operation) matches
      tagged Read: AvalonMMResponse {
        response: 2'h00
      , operation: tagged Read zeroExtend (req.address)
      };
      tagged Write .*: AvalonMMResponse { response: 2'h00
                                        , operation: tagged Write };
    endcase;
    $display ( "<%0t> AGENT> received: ", $time, fshow (req)
             , "\n       sending: ", fshow (rsp) );
    master.req.drop;
    master.rsp.put (rsp);
    delay <= `DELAY;
  endrule

  return ifc;
endmodule

function Action checkBFlit (AXI4_BFlit #(MID_sz, BUSER_sz) bflit) = action
  if (bflit.bresp != OKAY) begin
    lvlprint (2, $format ("Broken write"));
    $finish;
  end
endaction;

function Action checkRFlit ( AXI4_RFlit #(MID_sz, DATA_sz, RUSER_sz) rflit
                           , Bit #(DATA_sz) expData ) = action
  if (rflit.rresp != OKAY) begin
    lvlprint (2, $format ("Broken read"));
    $finish;
  end
  if (rflit.rdata != expData) begin
    lvlprint (2, $format ( "Expected read data:", fshow (expData)
                         , ", got: ", fshow (rflit.rdata) ));
    $finish;
  end
endaction;

module mkAXI4Master (`MASTER_T);
  AXI4_Shim#(`MPARAMS) shim <- mkAXI4Shim;

  function Stmt doWrite ( Bit #(ADDR_sz) addr
                        , Bit #(TDiv #(DATA_sz, 8)) be
                        , Bit #(DATA_sz) data) = seq
    action
      AXI4_AWFlit #(MID_sz, DATA_sz, AWUSER_sz) awflit = ?;
      awflit.awaddr = addr;
      awflit.awsize = toAXI4_Size (zeroExtend (pack (countOnes (be)))).Valid;
      awflit.awlen = 0;
      shim.slave.aw.put (awflit);
      AXI4_WFlit #(DATA_sz, WUSER_sz) wflit = ?;
      wflit.wdata = data;
      wflit.wstrb = be;
      wflit.wlast = True;
      shim.slave.w.put (wflit);
      lvlprint (1, $format ("HOST> sent:", fshow (awflit)));
      lvlprint (1, $format ("HOST> sent:", fshow (wflit)));
    endaction
    action
      let bflit <- get (shim.slave.b);
      lvlprint (1, $format ("HOST> received:", fshow (bflit)));
      checkBFlit (bflit);
    endaction
  endseq;

  function Stmt doRead ( Bit #(ADDR_sz) addr
                       , Bit #(TLog #(DATA_sz)) nbytes
                       , Bit #(DATA_sz) expData) = seq
    action
      AXI4_ARFlit #(MID_sz, DATA_sz, ARUSER_sz) arflit = ?;
      arflit.araddr = addr;
      arflit.arsize = toAXI4_Size (zeroExtend (nbytes)).Valid;
      arflit.arlen = 0;
      shim.slave.ar.put (arflit);
    endaction
    action
      let rflit <- get (shim.slave.r);
      checkRFlit (rflit, expData);
    endaction
  endseq;

  mkAutoFSM (seq
    lvlprint (1, $format ("HOST>---------- init mem ------------"));
    doWrite ('h00, ~0, 'h33221100);
    doWrite ('h04, ~0, 'h77665544);
    doWrite ('h08, ~0, 'hbbaa9988);
    doWrite ('h0c, ~0, 'hffeeddcc);
    doWrite ('h10, ~0, 'hdeadbeef);
    lvlprint (1, $format ("HOST>---------- check mem ------------"));
    doRead ('h00, 4, 'h0);
    doRead ('h04, 4, 'h04);
    doRead ('h08, 4, 'h08);
    doRead ('h0c, 4, 'h0c);
    doRead ('h10, 4, 'h10);
    $display ("success");
  endseq);

  // return AXI interface
  return debugAXI4_Master (shim.master, $format ("mkAXI4Master"));

endmodule

module top (Empty);
  let axm <- mkAXI4Master;
  let avh <- mkAXI4Manager_to_PipelinedAvalonMMHost (axm);
  let ava <- mkPipelinedAvalonMMAgent;
  (* fire_when_enabled, no_implicit_conditions *)
  rule debug;
    $display ("-------------------- <t = %0t> --------------------", $time);
    $display (fshow (avh));
    $display (fshow (ava));
  endrule
  mkConnection(avh, ava);
endmodule

`undef PARAMS
`undef MPARAMS
`undef SPARAMS
`undef MASTER_T
`undef SLAVE_T
`undef DELAY
