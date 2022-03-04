/*-
 * Copyright (c) 2022 Franz Fuchs
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

/*
This module logs reported instructions in the transient trace format
*/

import ReorderBuffer :: *;
import ProcTypes :: *;
//import CHERICap :: *;
import CHERICC_Fat :: *;

interface CIDLogging;
    method Action setFP(File fpointer);
    method Action log(CompIndex cid, ToReorderBuffer x);
endinterface

typedef struct {
    CompIndex cid;
    IType iType;
    CapMem predNextPc;
    CapMem actualNextPc;
} TransientTrace deriving (Bits, Eq, FShow);


module mkCIDLogging(CIDLogging);

    Reg#(File) fp <- mkReg(InvalidFile);

    method Action setFP(File fpointer);
        fp <= fpointer;
    endmethod

    method Action log(CompIndex cid, ToReorderBuffer x);
        $display("CIDLogging");
        TransientTrace tt = unpack(0);
        tt.cid = cid;
        tt.iType = x.iType;
        $fwrite(fp, fshow(tt));
    endmethod
endmodule
