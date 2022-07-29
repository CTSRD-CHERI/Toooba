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

import CHERICC_Fat :: *;
import ProcTypes :: *;
import Vector :: *;

interface CIDTableInput;
    method Action shootdown(CompIndex cid);
endinterface

interface CIDTable;
    method Action setNewCID(CapMem cid);
    method CompIndex getCID();
endinterface

function CompIndex reduce(CapMem acid);
    // currently a hash implementation
    return hash(acid);
endfunction

typedef struct {
    CapMem acid;
    Bool v;
} CIDTableEntry deriving (Bits, Eq, FShow);

module mkCIDTable#(CIDTableInput inIfc)(CIDTable);

    Reg#(CapMem) rg_cur_cid <- mkReg(0);

    // used a direct mapped cache, where mcid is the index
    Vector#(CompNumber, Reg#(CIDTableEntry)) tab <- replicateM(mkReg(unpack(0)));

    method Action setNewCID(CapMem acid);
        rg_cur_cid <= acid;
        let mcid = reduce(acid);
        $display("setNewCID - acid: ", fshow(acid), "; mcid: ", fshow(mcid));
        let entry = tab[mcid];
        if(!entry.v && acid != entry.acid) begin
            inIfc.shootdown(mcid);
            CIDTableEntry e = CIDTableEntry{acid: acid, v: True};
            tab[mcid] <= e;
        end

        $display("CIDTable:");
        for(Integer i = 0; i < valueOf(CompNumber); i = i + 1) begin
            $display("tab: ", fshow(tab[i]));
        end
    endmethod

    method CompIndex getCID();
        return reduce(rg_cur_cid);
    endmethod
endmodule