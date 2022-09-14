
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

 import RegFile::*;
 import Ehr::*;
 import Vector::*;

interface RegFileSD #(type index_t, type data_t);
    method Action upd(index_t addr, data_t d);
    method data_t sub(index_t addr);
    method Action shootdown();
endinterface

module mkRegFileSD#(index_t lo, index_t hi, data_t default_value)(RegFileSD#(index_t, data_t)) provisos (
    Bits#(index_t, index_sz),
    Bits#(data_t, data_sz),
    Literal#(index_t),
    PrimIndex#(index_t, a__));
    
    RegFile#(index_t, data_t) rf <- mkRegFileWCF(lo, hi);
    Vector#(SizeOf#(index_t), Ehr#(2, Bool)) valids <- replicateM(mkEhr(False));

    method Action upd(index_t addr, data_t d);
        rf.upd(addr, d);
        valids[addr][0] <= True;
    endmethod

    method data_t sub(index_t addr);
        if(valids[addr][0]) return rf.sub(addr);
        else return default_value;
    endmethod

    method Action shootdown();
        writeVReg(getVEhrPort(valids, 1), replicate(False));
    endmethod
endmodule