/* Copyright 2015 Matthew Naylor
 * Copyright 2022 Alexandre Joannou
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-10-C-0237
 * ("CTSRD"), as part of the DARPA CRASH research programme.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249
 * ("MRC2"), as part of the DARPA MRC research programme.
 *
 * This software was developed by the University of Cambridge Computer
 * Laboratory as part of the Rigorous Engineering of Mainstream
 * Systems (REMS) project, funded by EPSRC grant EP/K008528/1.
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

import Vector::*;
import SourceSink::*;
import Connectable::* ;
import MemoryClient::*;
import BlueAXI4::*;
import TestEquiv::*;
import ModelDRAM :: *;
import Clocks::*;
import BlueCheck::*;
import StmtFSM::*;
import DUT::*;
import TagControllerAXI::*;

(* synthesize *)
module mkTestMemTop (Empty);
  mkTestMemTopSingle;
endmodule

module [Module] mkTestMemTopSingle (Empty);
  // Make a reset signal for testing by iterative deepening
  Clock clk      <- exposeCurrentClock;
  MakeResetIfc r <- mkReset(0, True, clk);

  // Implementation
  //AXITagShim#(0,32,128,0) dut <- mkDummyDUT(reset_by r.new_rst);
  TagControllerAXI#(4,32,128) dut <- mkTagControllerAXI(reset_by r.new_rst);
  // Instantiate DRAM model
  // (max oustanding requests = 4)
  AXI4_Slave#(8, 32, 128, 0, 0, 0, 0, 0) dram <- mkModelDRAMAssoc(4, reset_by r.new_rst);
  // Connect core to DRAM
  mkConnection(dut.master, dram, reset_by r.new_rst);
  // Create test client for DUT
  MemoryClient dutClient <- mkMemoryClient(dut.slave, reset_by r.new_rst);

  // Golden model
  MemoryClient goldClient <- mkMemoryClientGolden(reset_by r.new_rst);

  // Make equivalence checker
  // BlueCheck parameters
  BlueCheck_Params params = bcParamsID(r);
  params.wedgeDetect = True;
  function double(x) = x*2;
  params.id.incDepth = double;
  params.id.initialDepth = 4;
  params.id.testsPerDepth = 10000;
  params.numIterations = 12;

  // Generate checker
  Stmt s <- mkModelChecker(checkSingle(dutClient, goldClient), params);
  mkAutoFSM(s);
endmodule
