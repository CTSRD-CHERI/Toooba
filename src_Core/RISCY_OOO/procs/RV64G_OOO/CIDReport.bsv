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
 This module collects all information that need to be known for checking. It allows
 for loogging information, and is extensible for plugging in a checking module, e.g.,
 in Bluespec.
 */

import ReorderBuffer :: *;
import CIDLogging :: *;
import ProcTypes :: *;
import CHERICC_Fat :: *;
import CHERICap :: *;

interface CIDReport;
    method Action setFP(File fpointer);
    method Action setCID(CompIndex cid);
    method Action reportPred(ToReorderBuffer x);
    method Action reportInstr(ToReorderBuffer x);
endinterface

// events that cause a compartment change:
// - write to the CID CSR and if the value is about to change
function Bool isCompChange(ToReorderBuffer x, CompIndex cid);
    let retval = False;
    if(x.csr matches tagged Valid .csr_idx) begin
        let write_val = x.ppc_vaddr_csrData.CSRData;
        if(csr_idx == csrAddrCID && write_val != zeroExtend(cid)) retval = True;
    end
    return retval;
endfunction

module mkCIDReport(CIDReport);

    CIDLogging log <- mkCIDLogging;
    Reg#(CompIndex) rg_cid <- mkRegU;

    method Action setFP(File fpointer);
        log.setFP(fpointer);
    endmethod

    method Action setCID(CompIndex cid);
        rg_cid <= cid;
    endmethod

    method Action reportPred(ToReorderBuffer x);
        $display("reportPred");
        let ppc = x.ppc_vaddr_csrData.PPC;
        let addr = getAddr(ppc);
        if (x.iType == CJALR && addr != 0) begin
            $display("CJALR instruction");
            log.logPrediction(rg_cid, x);
        end
    endmethod

    method Action reportInstr(ToReorderBuffer x);
        $display("reportInstr ", fshow(x));
        if (x.iType == CJALR || x.iType == Jr) begin
            $display("CJALR instruction");
            log.logCommittedInstr(rg_cid, x);
        end
    endmethod
endmodule

