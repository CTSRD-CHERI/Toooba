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

import AXI4 :: *;

import MemSim :: *;
import MemUtils :: *;
import SourceSink :: *;
import StmtFSM :: *;

import Connectable :: *;

typedef  0 IdT;
typedef 32 AddrT;
typedef 512 DataT;

module mkAXI4TraficGenerator (AXI4_Master #( IdT, AddrT, DataT
                                           , 0, 0, 0, 0, 0));

  // AXI master shim
  AXI4_Shim #(IdT, AddrT, DataT, 0, 0, 0, 0, 0) shim <- mkAXI4Shim;

  let arlen = 5;
  // traffic state machine definition
  Stmt driveTraffic = (seq
    shim.slave.aw.put (AXI4_AWFlit { awid: ?
                                   , awaddr: 32'h00000010
                                   , awlen: 1
                                   , awsize: 4
                                   , awburst: ?
                                   , awlock: ?
                                   , awcache: ?
                                   , awprot: ?
                                   , awqos: ?
                                   , awregion: ?
                                   , awuser: ? });
    shim.slave.w.put (AXI4_WFlit { wdata: zeroExtend (32'hdeadbeef)
                                 , wstrb: zeroExtend (4'b1111)
                                 , wlast: False
                                 , wuser: ? });
    shim.slave.w.put (AXI4_WFlit { wdata: zeroExtend (32'hdeadbeef)
                                 , wstrb: zeroExtend (4'b0101)
                                 , wlast: True
                                 , wuser: ? });
    noAction;
    noAction;
    noAction;
    noAction;
    noAction;
    shim.slave.ar.put (AXI4_ARFlit { arid: ?
                                   , araddr: zeroExtend (32'h00000010)
                                   , arlen: arlen
                                   , arsize: 4
                                   , arburst: ?
                                   , arlock: ?
                                   , arcache: ?
                                   , arprot: ?
                                   , arqos: ?
                                   , arregion: ?
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
    if (cnt == arlen) $finish (0);
  endrule

  // return AXI interface
  return shim.master;

endmodule

module top (Empty);
  AXI4_Master #(IdT, AddrT, DataT, 0, 0, 0, 0, 0)
    m <- mkAXI4TraficGenerator;
  AXI4_Slave #(IdT, AddrT, DataT, 0, 0, 0, 0, 0)
    s <- mkAXI4Mem (4096, UnInit);
  mkConnection( debugAXI4_Master (m, $format ("traffic generator"))
              , debugAXI4_Slave (s, $format ("memory")) );
endmodule
