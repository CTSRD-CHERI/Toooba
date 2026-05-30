/* Copyright 2018 Jonathan Woodruff
 * Copyright 2022 Alexandre Joannou
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

import DefaultValue::*;
import SourceSink::*;
import BlueAXI4::*;

interface AXITagShim#(
  numeric type id_,
  numeric type addr_,
  numeric type data_,
  numeric type awuser_,
  numeric type wuser_,
  numeric type buser_,
  numeric type aruser_,
  numeric type ruser_);
  interface AXI4_Master#(
    id_, addr_, data_, awuser_, wuser_, buser_, aruser_, ruser_
  ) master;
  interface AXI4_Slave#(
    id_, addr_, TAdd#(data_,TDiv#(data_,128)), awuser_, wuser_, buser_, aruser_, ruser_
  ) slave;
endinterface

module mkDummyDUT(AXITagShim#(0,addrWidth,128,0,0,0,0,0));
  AXI4_Shim#(0, addrWidth, 129, 0, 0, 0, 0, 0) shimSlave  <- mkAXI4Shim;
  AXI4_Shim#(0, addrWidth, 128, 0, 0, 0, 0, 0) shimMaster <- mkAXI4Shim;

  rule getWrite;
    let awreq <- get(shimSlave.master.aw);
    shimMaster.slave.aw.put(awreq);
    let wreq <- get(shimSlave.master.w);
    AXI4_WFlit#(128, 0) noTagReq = AXI4_WFlit{
      wdata: truncate(wreq.wdata),
      wstrb: truncate(wreq.wstrb),
      wlast: wreq.wlast,
      wuser: wreq.wuser
    };
    shimMaster.slave.w.put(noTagReq);
    $display("Write req ", fshow(wreq));
  endrule
  rule putBFlit;
    let rsp <- get(shimMaster.slave.b);
    shimSlave.master.b.put(rsp);
    $display("Write rsp ", fshow(rsp));
  endrule
  rule getARFlit;
    let req <- get(shimSlave.master.ar);
    shimMaster.slave.ar.put(req);
    $display("Read req ", fshow(req));
  endrule
  rule putRFlit;
    let resp <- get(shimMaster.slave.r);
    AXI4_RFlit#(0, 129, 0) taggedResp = AXI4_RFlit{
      rid: resp.rid,
      rdata: {resp.rdata[16],resp.rdata},
      rresp: resp.rresp,
      rlast: resp.rlast,
      ruser: resp.ruser
    };
    shimSlave.master.r.put(taggedResp);
    $display("Read rsp ", fshow(resp));
  endrule

  interface slave  = shimSlave.slave;
  interface master = shimMaster.master;
endmodule
