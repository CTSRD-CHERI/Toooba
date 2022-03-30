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
import CHERICC_Fat :: *;

interface CIDLogging;
    method Action setFP(File fpointer);
    method Action logPrediction(CompIndex cid, ToReorderBuffer x);
    method Action logCommittedInstr(CompIndex cid, ToReorderBuffer x);
endinterface

typedef enum {
    Call,
    Jump,
    Ret,
    Other
} InstType deriving (Bits, Eq, FShow);

typedef struct {
    CompIndex cid;
    InstType iType;
    CapMem pc;
    CapMem actualNextPc;
    CapMem retPc;
} ArchTrace deriving (Bits, Eq, FShow);

typedef struct {
    CompIndex cid;
    InstType iType;
    CapMem target;
} TransientTrace deriving (Bits, Eq, FShow);

// return address stack link reg is x1 or x5
function Bool linkedR(Maybe#(ArchRIndx) register);
    Bool res = False;
    if (register matches tagged Valid .r &&& (r == tagged Gpr 1 || r == tagged Gpr 5)) begin
        res = True;
    end
    return res;
endfunction

// return whether register is x0
function Bool isZeroReg(Maybe#(ArchRIndx) register);
    Bool res = True;
    if (register matches tagged Valid .r &&& (r != tagged Gpr 0)) begin
        res = False;
    end
    return res;
endfunction

function InstType getInstType(IType iType, Maybe#(ArchRIndx) rs1, Maybe#(ArchRIndx) rd);
    InstType retval = Other;
    if(iType == CJALR || iType == Jr) begin
        if(linkedR(rs1) && isZeroReg(rd)) retval = Ret;
        else if(linkedR(rd)) retval = Call;
        else retval = Jump;
    end
    return retval;
endfunction

function Bool is_16b_inst (Bit #(32) inst);
    return (inst [1:0] != 2'b11);
endfunction


module mkCIDLogging(CIDLogging);

    Reg#(File) fp <- mkReg(InvalidFile);

    method Action setFP(File fpointer);
        fp <= fpointer;
    endmethod

    method Action logPrediction(CompIndex cid, ToReorderBuffer x);
        $display("logPrediction");
        TransientTrace tt = unpack(0);
        tt.cid = cid;
        tt.iType = getInstType(x.iType, x.rs1, x.dst);
        tt.target = x.ppc_vaddr_csrData.PPC;
        $fwrite(fp, fshow(tt), "\n");
        //$fwrite(fp, fshow(tt), "%t", $time, "\n");
    endmethod

    method Action logCommittedInstr(CompIndex cid, ToReorderBuffer x);
        $display("CIDLogging ",fshow(x));
        ArchTrace at = unpack(0);
        at.cid = cid;
        at.iType = getInstType(x.iType, x.rs1, x.dst);
        at.pc = x.pc;
        if(at.iType == Call) at.retPc = is_16b_inst(x.orig_inst) ? x.pc + 2 : x.pc + 4;
        // read out ppc from the rob
        at.actualNextPc = x.ppc_vaddr_csrData.PPC;
        $fwrite(fp, fshow(at), "\n");
        //$fwrite(fp, fshow(at), "%t", $time, "\n");
    endmethod
endmodule
