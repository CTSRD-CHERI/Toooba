/*-
 * Copyright (c) 2021 Franz Fuchs
 * Copyright (c) 2021 Jonathan Woodruff
 * All rights reserved.
 *
 * This software was developed by the University of  Cambridge
 * Department of Computer Science and Technology under the
 * SIPP (Secure IoT Processor Platform with Remote Attestation)
 * project funded by EPSRC: EP/S030868/1
 *
 * This work was supported by NCSC programme grant 4212611/RFA 15971 ("SafeBet").
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

import Types::*;
import ProcTypes::*;
import ConfigReg::*;
import Map::*;
import Vector::*;
import CHERICC_Fat::*;
import CHERICap::*;
import Btb_IFC::*;
import BtbCore::*;
import BtbDynamic::*;

export mkBtbPartition;

(* synthesize *)
module mkBtbPartition(NextAddrPred#(16));
    Vector#(CompNumber, NextAddrPred#(16)) btbs <- replicateM(mkBtbCore);
    Reg#(CompIndex) rg_cid <- mkReg(0);
    method Action setCID(CompIndex cid);
        rg_cid <= cid;
    endmethod
    method Action put_pc(CapMem pc);
        btbs[rg_cid].put_pc(pc);
    endmethod
    interface pred = btbs[rg_cid].pred;
    method Action update(CapMem pc, CapMem brTarget, Bool taken);
        btbs[rg_cid].update(pc, brTarget, taken);
    endmethod
    method Action flush;
        btbs[rg_cid].flush;
    endmethod
    method Bool flush_done = btbs[rg_cid].flush_done;
endmodule

