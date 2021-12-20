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


`include "ProcConfig.bsv"
import Types::*;
import ProcTypes::*;
import Vector::*;
import Ehr::*;
import CHERICC_Fat::*;
import CHERICap::*;
import RWBramCore::*;
import Ras_IFC::*;


// Local RAS Typedefs SHOULD BE A POWER OF TWO.
typedef 64 StackEntries;
typedef TLog#(StackEntries) StackSize;

(* synthesize *)
module mkRasBram(ReturnAddrStack);
    RWBramCoreVector#(Bit#(StackSize), CapMem, SupSize) bram <- mkRWBramCoreVector;

    // current addr to the BRAM
    Ehr#(TAdd#(SupSize, 2), Bit#(StackSize)) head <- mkEhr(0);


    Vector#(SupSize, RAS) rasIfc;

    // allocation of ehr interfaces:
    // 0: for reading in the values from the Bram
    // [1, SupSize + 1[: Actions of the ras interface take place
    // SupSize: write back to Bram
    Vector#(SupSize, Ehr#(TAdd#(SupSize, 2), CapMem)) topElems <- replicateM(mkEhr(0));
    Ehr#(TAdd#(SupSize, 2), Bit#(TLog#(SupSize))) bottom <- mkEhr(0);

    rule readData;
        let rd = bram.rdResp;
        for(Integer i = 0; i < valueOf(SupSize); i = i + 1) begin
            topElems[i][0] <= rd[i];
        end
        bottom[0] <= 0;
    endrule

    rule writeData;
        Vector#(SupSize, Maybe#(CapMem)) v = replicate(tagged Invalid);
        for(Integer i = 0; i < valueOf(SupSize); i = i + 1) begin
            if(bottom[valueOf(SupSize) + 1] <= fromInteger(i)) begin
                v[i] = tagged Valid topElems[i][valueOf(SupSize) + 1];
            end
        end
        bram.wrReq(head[valueOf(SupSize) + 1], v);
    endrule

    rule startRead;
        bram.rdReq(head[valueOf(SupSize) + 1]);
    endrule

    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
        Integer idx = i + 1;
        rasIfc[i] = (interface RAS;
            method CapMem first;
                // returns the top of the stack
                return topElems[valueOf(SupSize) - 1][idx];
            endmethod
            method Action popPush(Bool pop, Maybe#(CapMem) pushAddr);
                // first pop, then push
                Bit#(StackSize) x = head[idx];
                if(pop &&& pushAddr matches tagged Valid .addr) begin
                    topElems[valueOf(SupSize) - 1][idx] <= addr;
                end
                else if(pop) begin
                    x = x - 1;
                    bottom[idx] <= bottom[idx] + 1;
                    for(Integer j = 1; j < valueOf(SupSize); j = j + 1) topElems[j][idx] <= topElems[j-1][idx];
                    // no need to write topElems[0]
                end
                else if(pushAddr matches tagged Valid .addr) begin
                    x = x + 1;
                    if(bottom[idx] > 0) bottom[idx] <= bottom[idx] - 1;
                    for(Integer j = 1; j < valueOf(SupSize); j = j + 1) topElems[j-1][idx] <= topElems[j][idx];
                    topElems[valueOf(SupSize) - 1][idx] <= addr;
                end
                head[idx] <= x;
            endmethod
        endinterface);
    end

    interface ras = rasIfc;

    method Action flush = noAction;

    method Bool flush_done = True;



endmodule
