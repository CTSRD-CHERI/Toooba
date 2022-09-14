/*-
 * Copyright (c) 2022 Franz Fuchs
 * All rights reserved.
 *
 * This software was developed by the University of Cambridge
 * Department of Computer Science and Technology under the
 * SIPP (Secure IoT Processor Platform with Remote Attestation)
 * project funded by EPSRC: EP/S030868/1
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
import RegFile::*;
import Ehr::*;
import Vector::*;
import GlobalBrHistReg::*;
import BrPred::*;
import SDPMem::*;
import TourPredCore::*;
import TourPredBram::*;



`ifdef CID
(* synthesize *)
module mkTourPredPartition(DirPredictor#(TourTrainInfo));
    Vector#(CompNumber, DirPredictor#(TourTrainInfo)) preds <- replicateM(mkTourPredBram);
    Reg#(CompIndex) rg_cid <- mkReg(0);
    interface pred = preds[rg_cid].pred;
    method nextPc = preds[rg_cid].nextPc;
    method Action setCID(CompIndex cid);
        rg_cid <= cid;
    endmethod
    method Action shootdown(CompIndex cid);
        preds[cid].shootdown(cid);
    endmethod
    method update = preds[rg_cid].update;
    method flush = preds[rg_cid].flush;
    method flush_done = preds[rg_cid].flush_done;
endmodule
`endif