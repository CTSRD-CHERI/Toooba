/*-
 * Copyright (c) 2021 Franz Fuchs
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
//import CsrFile :: *;
import ProcTypes :: *;

interface CIDReport;
    method Action reportInstr(ToReorderBuffer x);
endinterface

// events that cause a compartment change:
// - write to the CID CSR
function Bool isCompChange(ToReorderBuffer x);
    let retval = False;
    if(x.csr matches tagged Valid .csr_idx) begin
        if(csr_idx == csrAddrCID) retval = True;
    end
    return retval;
endfunction

module mkCIDReport(CIDReport);

    /*Reg#(File) fp <- mkReg(InvalidFile);

    method Action setFP*/

    method Action reportInstr(ToReorderBuffer x);
        $display("reportInstr ", fshow(x));
        //$fwrite(fp, "reportInstr ", fshow(x));
    endmethod
endmodule

