/*-
 * Copyright (c) 2021 Jonathan Woodruff
 * Copyright (c) 2022-2024 Franz Fuchs
 * All rights reserved.
 *
 * This software was developed by the University of  Cambridge
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

`ifdef ParTag
`include "ProcConfig.bsv"
import Map::*;
import STLPred_IFC::*;
import STLPredCore::*;
import ProcTypes::*;
import Vector::*;


module mkSTLPredPartition(STLPred);
    Vector#(PTNumber, STLPred) stlpreds <- replicateM(mkSTLPredCore);
    Reg#(PTIndex) rg_ptid <- mkReg(0); // default zero id

    //method update = stlpreds[rg_ptid].update;
    method Action update(HashValue pc_hash, Bool waited, Bool killedLd, Maybe#(PTIndex) ptid);
        if(ptid matches tagged Valid .p) stlpreds[p].update(pc_hash, waited, killedLd, ptid);
        else noAction;
    endmethod
    //method pred = stlpreds[rg_ptid].pred;
    method Bool pred(HashValue pc_hash, Maybe#(PTIndex) ptid);
        if(ptid matches tagged Valid .p) return stlpreds[p].pred(pc_hash, ptid);
        else return True;
    endmethod
`ifdef ParTag
    method Action setPTID(PTIndex ptid);
        rg_ptid <= ptid;
    endmethod
    method shootdown = stlpreds[rg_ptid].shootdown;
`endif
endmodule
`endif