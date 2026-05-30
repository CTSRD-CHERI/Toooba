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

import SourceSink :: *;

import Connectable :: *;
import FIFOF :: *;
import SpecialFIFOs :: *;

typedef   0 ID_sz;
typedef  32 ADDR_sz;
typedef  64 DATA_sz;
typedef 128 WIDEDATA_sz;
typedef   0 AWUSER_sz;
typedef   0 WUSER_sz;
typedef   0 BUSER_sz;
typedef   0 ARUSER_sz;
typedef   0 RUSER_sz;

`define PARAMS ID_sz, ADDR_sz, DATA_sz, AWUSER_sz, WUSER_sz, BUSER_sz, ARUSER_sz, RUSER_sz
`define WIDEPARAMS ID_sz, ADDR_sz, WIDEDATA_sz, AWUSER_sz, WUSER_sz, BUSER_sz, ARUSER_sz, RUSER_sz

module axiMaster (AXI4_Master#(`PARAMS));

  // AXI4 master shim
  AXI4_Shim#(`PARAMS) shim <- mkAXI4Shim;

  // counter
  Reg#(Bit#(DATA_sz)) cnt <- mkReg(0);
  rule counteUp; cnt <= cnt + 1; endrule

  // arbitrary work for each channel
  Bool sendWrite = cnt[3:0] == 0;
  rule putAXI4_AWFlit (sendWrite);
    AXI4_AWFlit#(ID_sz, ADDR_sz, AWUSER_sz) f = AXI4_AWFlit {
      awid:     0,
      awaddr:   0,
      awlen:    0,
      awsize:   2,
      awburst:  INCR,
      awlock:   NORMAL,
      awcache:  0,
      awprot:   0,
      awqos:    0,
      awregion: 0,
      awuser:   0
    };
    shim.slave.aw.put(f);
    $display("%0t - MASTER - sending ", $time, fshow(f));
  endrule
  rule putAXI4_WFlit (sendWrite);
    AXI4_WFlit#(DATA_sz, WUSER_sz) f = AXI4_WFlit {
      wdata: cnt, wstrb: 'h3, wlast: True, wuser: 0
    };
    shim.slave.w.put(f);
    $display("%0t - MASTER - sending ", $time, fshow(f));
  endrule
  rule getAXI4_BFlit;
    let rsp <- get(shim.slave.b);
    $display("%0t - MASTER - received ", $time, fshow(rsp));
  endrule
  //rule putAXI4_ARFlit; shim.slave.ar.put(?); endrule
  //rule dropAXI4_RFlit; shim.slave.r.drop; endrule

  // return AXI4 interface
  return shim.master;

endmodule

module axiSlave (AXI4_Slave#(`WIDEPARAMS));

  // AXI4 slave shim
  AXI4_Shim#(`WIDEPARAMS) shim <- mkAXI4Shim;

  // arbitrary work for each channel
  let writeResp <- mkFIFOF;
  rule getAXI4_AWFlit;
    let awreq <- get(shim.master.aw);
    $display("%0t - SLAVE - received ", $time, fshow(awreq));
    let wreq <- get(shim.master.w);
    $display("%0t - SLAVE - received ", $time, fshow(wreq));
    writeResp.enq(awreq);
  endrule
  rule putAXI4_BFlit;
    writeResp.deq;
    let awflit = writeResp.first;
    AXI4_BFlit#(ID_sz, BUSER_sz) f = AXI4_BFlit {
      bid:    awflit.awid,
      bresp:  OKAY,
      buser: awflit.awuser
    };
    shim.master.b.put(f);
    $display("%0t - SLAVE - sending ", $time, fshow(f));
  endrule
  //rule dropAXI4_ARFlit; shim.master.ar.drop; endrule
  //rule putAXI4_RFlit; shim.master.r.put(?); endrule

  // return AXI4 interface
  return shim.slave;

endmodule

module top (Empty);
  AXI4_Master#(`PARAMS)     master <- axiMaster;
  AXI4_Master#(`WIDEPARAMS) widemaster <- toWider_AXI4_Master(master);
  AXI4_Slave#(`WIDEPARAMS)  wideslave  <- axiSlave;
  mkConnection(widemaster, wideslave);
endmodule

`undef PARAMS
