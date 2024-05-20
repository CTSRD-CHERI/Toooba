/*-
 * Copyright (c) 2024 Franz Fuchs
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
import Types::*;
import ProcTypes::*;
import RegFile::*;
import Vector::*;
import Ehr::*;
import CHERICC_Fat::*;
import CHERICap::*;
import Ras_IFC::*;
import RasSingle::*;

module mkRasPartition(ReturnAddrStack);
    Vector#(PTNumber, ReturnAddrStack) rases <- replicateM(mkRasSingle);
    Reg#(PTIndex) rg_ptid <- mkReg(0); // default zero id

    interface ras = rases[rg_ptid].ras;
    method Action setPTID(PTIndex ptid);
        rg_ptid <= ptid;
    endmethod
    method shootdown = rases[rg_ptid].shootdown;
    method pendingPush = rases[rg_ptid].pendingPush;
    method push = rases[rg_ptid].push;
    method write = rases[rg_ptid].write;
    method setHead = rases[rg_ptid].setHead;
    method flush = rases[rg_ptid].flush;
    method flush_done = rases[rg_ptid].flush_done;
endmodule
`endif