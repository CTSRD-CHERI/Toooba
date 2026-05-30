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
import BlueUtils :: *;
import AXI4_Avalon :: *;

import StmtFSM :: *;
import Vector :: *;
import FIFOF :: *;

import Connectable :: *;

typedef 1 NMASTERS;

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

function Action checkBFlit (AXI4_BFlit #(MID_sz, BUSER_sz) bflit) = action
  if (bflit.bresp != OKAY) begin
    lvlprint (2, $format ("Broken write"));
    $finish;
  end
endaction;

function Action checkRFlit ( Bit #(ADDR_sz) addr
                           , Bit #(TLog #(DATA_sz)) nbytes
                           , AXI4_RFlit #(MID_sz, DATA_sz, RUSER_sz) rflit
                           , Bit #(DATA_sz) expData ) = action
  Bit #(TLog #(TDiv #(DATA_sz, 8))) offset = truncate (addr);
  Bit #(TAdd #(TLog #(TDiv #(DATA_sz, 8)), 3)) bitOffset =
    zeroExtend (offset) << 3;
  Bit #(TAdd #(TLog #(DATA_sz), 3)) nBits = zeroExtend (nbytes) << 3;
  Bit #(DATA_sz) mask = (~((~0) << nBits)) << bitOffset;
  if (rflit.rresp != OKAY) begin
    lvlprint (2, $format ("Broken read"));
    $finish;
  end
  if ((rflit.rdata & mask) != (expData & mask)) begin
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
      awflit.awid = 0;
      awflit.awaddr = addr;
      awflit.awlen = 0;
      awflit.awsize = toAXI4_Size (zeroExtend (pack (countOnes (be)))).Valid;
      awflit.awburst = INCR;
      awflit.awlock = NORMAL;
      awflit.awcache = ?;
      awflit.awprot = ?;
      awflit.awqos = ?;
      awflit.awregion = ?;
      awflit.awuser = ?;
      shim.slave.aw.put (awflit);
      AXI4_WFlit #(DATA_sz, WUSER_sz) wflit = ?;
      wflit.wdata = data;
      wflit.wstrb = be;
      wflit.wlast = True;
      wflit.wuser = ?;
      shim.slave.w.put (wflit);
    endaction
    action
      let bflit <- get (shim.slave.b);
      checkBFlit (bflit);
    endaction
  endseq;

  function Stmt doRead ( Bit #(ADDR_sz) addr
                       , Bit #(TLog #(DATA_sz)) nbytes
                       , Bit #(DATA_sz) expData) = seq
    action
      AXI4_ARFlit #(MID_sz, DATA_sz, ARUSER_sz) arflit = ?;
      arflit.arid = 0;
      arflit.araddr = addr;
      arflit.arlen = 0;
      arflit.arsize = toAXI4_Size (zeroExtend (nbytes)).Valid;
      arflit.arburst = INCR;
      arflit.arlock = NORMAL;
      arflit.arcache = ?;
      arflit.arprot = ?;
      arflit.arqos = ?;
      arflit.arregion = ?;
      arflit.aruser = ?;
      shim.slave.ar.put (arflit);
    endaction
    action
      let rflit <- get (shim.slave.r);
      checkRFlit (addr, nbytes, rflit, expData);
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
    doRead ('h00, 4, 'h33221100);
    doRead ('h04, 4, 'h77665544);
    doRead ('h08, 4, 'hbbaa9988);
    doRead ('h0c, 4, 'hffeeddcc);
    doRead ('h10, 4, 'hdeadbeef);
    lvlprint (1, $format ("HOST>-------- unaligned sub word access --------"));
    doRead ('h00, 2, 'hFFFF1100);
    doRead ('h02, 2, 'h3322FFFF);
    doRead ('h01, 2, 'hFF2211FF);
    doWrite ('h1, 'b0110, 'hdeadbeef);
    doRead ('h1, 2, 'h33adbe00);
    doRead ('h1, 4, 'h33adbe00);
    $display ("success");
  endseq);

  // return AXI interface
  return shim.master;

endmodule

module mkAvalonMem (Slave #( AvalonMMRequest #(ADDR_sz, DATA_sz)
                           , AvalonMMResponse #(DATA_sz) ));
  Vector #(32, Reg #(Bit #(DATA_sz))) mem <- replicateM (mkRegU);
  let ff_req <- mkFIFOF;
  let ff_rsp <- mkFIFOF;

  AvalonMMRequest #(ADDR_sz, DATA_sz) req = ff_req.first;
  Integer lo = log2 (valueOf (DATA_sz)/8);
  Bit #(TLog #(32)) regNo = req.address[lo+valueOf (TLog #(32))-1:lo];
  Reg #(Bit #(DATA_sz)) upReg = asReg (mem [regNo]);
  rule handle_req;
    AvalonMMResponse #(DATA_sz) rsp = ?;
    rsp.response = 2'b00; // OKAY
    case (req.operation) matches
      tagged Read: rsp.operation = tagged Read upReg;
      tagged Write .val: begin
        upReg <= mergeWithBE (req.byteenable, upReg, val);
        rsp.operation = tagged Write;
      end
      default: rsp.response = 2'b10;
    endcase
    ff_req.deq;
    ff_rsp.enq (rsp);
  endrule

  return toSlave (ff_req, ff_rsp);
endmodule

module top (Empty);
  let axm <- mkAXI4Master;
  let avh <- mkAXI4Manager_to_PipelinedAvalonMMHost (
    debugAXI4_Master (axm, $format ("axm"))
  );
  Slave #(AvalonMMRequest #(ADDR_sz, DATA_sz), AvalonMMResponse #(DATA_sz))
    avmem <- mkAvalonMMMem (4096, UnInit);
    //avmem <- mkAvalonMem;
  NumProxy #(4) proxy_depth = error ("Never look inside a NumProxy");
  let ava <- toPipelinedAvalonMMAgent ( proxy_depth
                                      , debugSlave (avmem, $format ("avmem"))
                                      );
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
