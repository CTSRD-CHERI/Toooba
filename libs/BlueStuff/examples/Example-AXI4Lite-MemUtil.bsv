/*-
 * Copyright (c) 2021 Alexandre Joannou
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

import MemUtils :: *;
import SourceSink :: *;
import StmtFSM :: *;

import Connectable :: *;

typedef 32 AddrT;
typedef 32 DataT;

module mkAXI4LiteTraficGenerator (AXI4Lite_Master #( AddrT, DataT
                                               , 0, 0, 0, 0, 0));

  // AXI4Lite shim
  AXI4Lite_Shim #(AddrT, DataT, 0, 0, 0, 0, 0) shim <- mkAXI4LiteShim;

  // traffic state machine definition
  Stmt driveTraffic = (seq
    shim.slave.aw.put (AXI4Lite_AWFlit { awaddr: 32'h00000010
                                       , awprot: ?
                                       , awuser: ? });
    shim.slave.w.put (AXI4Lite_WFlit { wdata: 32'hdeadbeef
                                     , wstrb: 4'b1111
                                     , wuser: ? });
    shim.slave.aw.put (AXI4Lite_AWFlit { awaddr: 32'h00000014
                                       , awprot: ?
                                       , awuser: ? });
    shim.slave.w.put (AXI4Lite_WFlit { wdata: 32'hdeadbeef
                                     , wstrb: 4'b0101
                                     , wuser: ? });
    noAction;
    noAction;
    noAction;
    noAction;
    noAction;
    shim.slave.ar.put (AXI4Lite_ARFlit { araddr: 32'h00000010
                                       , arprot: ?
                                       , aruser: ? });
    shim.slave.ar.put (AXI4Lite_ARFlit { araddr: 32'h00000014
                                       , arprot: ?
                                       , aruser: ? });
  endseq);
  FSM driveTrafficFSM <- mkFSM(driveTraffic);
  // trigger the state machine
  Reg #(Bool) going <- mkReg (False);
  rule start (!going);
    going <= True;
    driveTrafficFSM.start;
  endrule

  rule drainBFlit;
    shim.slave.b.drop;
  endrule

  let cnt <- mkReg (0);
  rule drainRFlit;
    shim.slave.r.drop;
    cnt <= cnt + 1;
    if (cnt == 1) $finish (0);
  endrule

  // return AXI4Lite interface
  return shim.master;

endmodule

module top (Empty);
  AXI4Lite_Master #(AddrT, DataT, 0, 0, 0, 0, 0)
    m <- mkAXI4LiteTraficGenerator;
  AXI4Lite_Slave #(AddrT, DataT, 0, 0, 0, 0, 0)
    s <- mkAXI4LiteMem (4096, UnInit);
  mkConnection( debugAXI4Lite_Master (m, $format ("traffic generator"))
              , debugAXI4Lite_Slave (s, $format ("memory")) );
endmodule
