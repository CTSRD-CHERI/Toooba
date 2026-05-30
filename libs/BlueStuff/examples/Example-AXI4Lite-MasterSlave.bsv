/*-
 * Copyright (c) 2018-2021 Alexandre Joannou
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

import AXI4Lite :: *;

import SourceSink :: *;

import Connectable :: *;
import FIFOF :: *;
import SpecialFIFOs :: *;

typedef  20 ADDR_sz;
typedef  32 DATA_sz;
typedef   0 AWUSER_sz;
typedef   0 WUSER_sz;
typedef   0 BUSER_sz;
typedef   0 ARUSER_sz;
typedef   0 RUSER_sz;

`define PARAMS ADDR_sz, DATA_sz, AWUSER_sz, WUSER_sz, BUSER_sz, ARUSER_sz, RUSER_sz

module axiLiteMaster (AXI4Lite_Master#(`PARAMS));

  // AXI master shim
  AXI4Lite_Shim#(`PARAMS) shim <- mkAXI4LiteShim;

  // counter
  Reg#(Bit#(DATA_sz)) cnt <- mkReg(0);
  rule counteUp; cnt <= cnt + 1; endrule

  // arbitrary work for each channel
  Bool sendWrite = cnt[3:0] == 0;
  rule putAWFlit (sendWrite);
    AXI4Lite_AWFlit#(ADDR_sz, AWUSER_sz) f = ?;
    shim.slave.aw.put(f);
    $display("%0t - MASTER - sending ", $time, fshow(f));
  endrule
  rule putWFlit (sendWrite);
    AXI4Lite_WFlit#(DATA_sz, WUSER_sz) f = AXI4Lite_WFlit{wdata: cnt, wstrb: ?, wuser: ?};
    shim.slave.w.put(f);
    $display("%0t - MASTER - sending ", $time, fshow(f));
  endrule
  rule getBFlit;
    let rsp <- get(shim.slave.b);
    $display("%0t - MASTER - received ", $time, fshow(rsp));
  endrule
  rule putARFlit; shim.slave.ar.put(?); endrule
  rule dropRFlit; shim.slave.r.drop; endrule

  // return AXI interface
  return shim.master;

endmodule

module axiLiteMasterSig (AXI4Lite_Master_Sig#(`PARAMS));
  let noSig <- axiLiteMaster;
  let sig <- toAXI4Lite_Master_Sig (noSig);
  return sig;
endmodule

module axiLiteSlave (AXI4Lite_Slave#(`PARAMS));

  // AXI slave shim
  AXI4Lite_Shim#(`PARAMS) shim <- mkAXI4LiteShim;

  // arbitrary work for each channel
  FIFOF#(Bit#(0)) writeResp <- mkFIFOF;
  FIFOF#(Bit#(32)) readResp <- mkFIFOF;
  rule getAWFlit;
    let req <- get(shim.master.aw);
    $display("%0t - SLAVE - received ", $time, fshow(req));
  endrule
  rule getWFlit;
    let req <- get(shim.master.w);
    $display("%0t - SLAVE - received ", $time, fshow(req));
    writeResp.enq(?);
  endrule
  rule putBFlit;
    writeResp.deq;
    AXI4Lite_BFlit#(BUSER_sz) f = ?;
    shim.master.b.put(f);
    $display("%0t - SLAVE - sending ", $time, fshow(f));
  endrule
  rule getARFlit;
    let req <- get(shim.master.ar);
    readResp.enq(zeroExtend(req.araddr));
  endrule
  rule putRFlit;
    readResp.deq;
    shim.master.r.put(AXI4Lite_RFlit{
      rresp: OKAY, rdata: readResp.first, ruser: ?
    });
  endrule

  // return AXI interface
  return shim.slave;

endmodule

module axiLiteSlaveSig (AXI4Lite_Slave_Sig#(`PARAMS));
  let noSig <- axiLiteSlave;
  let sig <- toAXI4Lite_Slave_Sig (noSig);
  return sig;
endmodule

module top (Empty);
  AXI4Lite_Master#(`PARAMS) master <- axiLiteMaster;
  AXI4Lite_Slave#(`PARAMS)  slave  <- axiLiteSlave;
  mkConnection(master, slave);
endmodule

`undef PARAMS
