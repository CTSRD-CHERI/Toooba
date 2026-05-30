/*-
 * Copyright (c) 2018-2020 Alexandre Joannou
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

import SourceSink :: *;

import Connectable :: *;
import FIFOF :: *;
import SpecialFIFOs :: *;

typedef   0 ID_sz;
typedef  32 ADDR_sz;
typedef 128 DATA_sz;
typedef   0 AWUSER_sz;
typedef   0 WUSER_sz;
typedef   0 BUSER_sz;
typedef   0 ARUSER_sz;
typedef   0 RUSER_sz;

`define PARAMS ID_sz, ADDR_sz, DATA_sz, AWUSER_sz, WUSER_sz, BUSER_sz, ARUSER_sz, RUSER_sz

Integer nb_flit = 8;
Integer nb_rsp = 2;

module axiMaster (AXI4_Master#(`PARAMS));

  // AXI master shim
  AXI4_Shim#(`PARAMS) shim <- mkAXI4Shim;
  // Req addr
  Reg#(Bit#(ADDR_sz)) nextWriteAddr <- mkReg(0);
  // book keep
  Reg#(Bool) awSent <- mkReg (False);
  Reg#(Bool) reqSent <- mkReg (False);
  Reg#(Bit#(32)) rspCnt <- mkReg (0);
  Reg#(Bit#(32)) cnt <- mkReg (0);

  // arbitrary work for each channel
  rule putAXI4_AWFlit (!awSent);
    AXI4_AWFlit#(ID_sz, ADDR_sz, AWUSER_sz) f = ?;
    f.awaddr  = nextWriteAddr;
    f.awburst = INCR;
    f.awlen   = fromInteger (nb_flit - 1);
    nextWriteAddr <= nextWriteAddr + 1;
    shim.slave.aw.put(f);
    awSent <= True;
    $display("%0t - MASTER - sending ", $time, fshow(f));
  endrule
  rule putAXI4_WFlit (!reqSent);
    AXI4_WFlit#(DATA_sz, WUSER_sz) f = AXI4_WFlit{
      wdata: zeroExtend (cnt), wstrb: ?, wlast: cnt == fromInteger (nb_flit - 1), wuser: ?
    };
    shim.slave.w.put(f);
    if (cnt == fromInteger (nb_flit - 1)) begin
      cnt <= 0;
      reqSent <= True;
    end else cnt <= cnt + 1;
    $display("%0t - MASTER - sending ", $time, fshow(f));
  endrule
  rule getAXI4_BFlit (awSent && reqSent);
    let rsp <- get(shim.slave.b);
    $display("%0t - MASTER - received ", $time, fshow(rsp));
    reqSent <= False;
    awSent <= False;
    if (rspCnt == fromInteger (nb_rsp - 1)) $finish(0);
    else rspCnt <= rspCnt + 1;
  endrule

  // return AXI interface
  return shim.master;

endmodule

module axiSlave (AXI4_Slave#(`PARAMS));

  // AXI slave shim
  AXI4_Shim#(`PARAMS) shim <- mkAXI4Shim;

  // arbitrary work for each channel
  let awResp <- mkFIFOF;
  let wResp <- mkFIFOF;
  rule getAXI4_AWFlit;
    let req <- get(shim.master.aw);
    awResp.enq(AXI4_BFlit{
      bid: req.awid, bresp: OKAY, buser: ?
    });
    $display("%0t ---- SLAVE - received ", $time, fshow(req));
  endrule
  rule getAXI4_WFlit;
    let req <- get(shim.master.w);
    if (req.wlast) wResp.enq(True);
    $display("%0t ---- SLAVE - received ", $time, fshow(req));
  endrule
  rule putAXI4_BFlit;
    awResp.deq;
    wResp.deq;
    shim.master.b.put(awResp.first);
    $display("%0t ---- SLAVE - sending ", $time, fshow(awResp.first));
  endrule

  // return AXI interface
  return shim.slave;

endmodule

module top (Empty);
  AXI4_Master#(`PARAMS) master <- axiMaster;
  AXI4_Slave#(`PARAMS)  slave  <- axiSlave;
  AXI4_Shim#(`PARAMS) slvDeBurst <- mkBurstToNoBurst;
  mkConnection(slvDeBurst.master, slave);
  mkConnection(master, slvDeBurst.slave);
endmodule

`undef PARAMS
