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
import ProcTypes::*;
import RegFile::*;
import Vector::*;
import Ehr::*;
import CHERICC_Fat::*;
import CHERICap::*;
import Ras_IFC::*;

// Local RAS Typedefs SHOULD BE A POWER OF TWO.
typedef 128 Entries;
typedef 16 SegSize;
typedef 1024 TimeoutSize;
typedef TDiv#(Entries, SegSize) SegNumber;
typedef TLog#(SegSize) SegBits;
typedef Bit#(TLog#(Entries)) EntriesIndex;
typedef Bit#(SegBits) SegIndex;
typedef Bit#(SegBits) Age;
typedef Bit#(TLog#(TimeoutSize)) TimeoutIndex;
typedef TSub#(SegSize, 1) MaxAge;

typedef struct {
    EntriesIndex start;
    EntriesIndex length;
    Bool v;
} CompPointer deriving (Bits, Eq, FShow);

typedef struct {
        CompIndex cid;
        Age age;
} SegAge deriving (Bits, Eq, FShow);

module mkCircularRas(ReturnAddrStack) provisos(NumAlias#(TExp#(TLog#(Entries)), Entries));
    Vector#(Entries, Ehr#(TAdd#(SupSize, 2), CapMem)) stack <- replicateM(mkEhr(0));
    Vector#(CompNumber, Reg#(CompPointer)) pointers <- replicateM(mkRegU);
    Vector#(SegNumber, Reg#(SegAge)) segs <- replicateM(mkRegU);
    Vector#(CompNumber, Ehr#(TAdd#(SupSize, 1), EntriesIndex)) heads <- replicateM(mkEhr(0));

    Reg#(CompIndex) rg_cid <- mkRegU;
    Reg#(TimeoutIndex) timeout <- mkReg(0);

    RWire#(CompIndex) updateCID <- mkRWire;

    function SegIndex findNextSeg();
        SegIndex id = 0;
        Age a = fromInteger(valueOf(TSub#(SegNumber, 1)));
        for(Integer i = 0; i < valueOf(SegNumber); i = i + 1) begin
            if(segs[i].age < a) begin
               id = fromInteger(i);
               a = segs[i].age;
            end
        end
        return id;
    endfunction

    rule doIncTimeout(updateCID.wget matches tagged Invalid);
        timeout <= timeout + 1;
    endrule

    rule canonUpdate(updateCID.wget matches tagged Valid .upd);
        rg_cid <= upd;
        let p = pointers[upd];
        let p_old = pointers[rg_cid];
        SegIndex amount_comps = truncate((p_old.length) >> fromInteger(valueOf(SegBits)));
        SegIndex start_seg = truncate ((p_old.start) >> fromInteger(valueOf(SegBits)));
        SegIndex counter = amount_comps - 1;
        for(Integer i = 0; i < valueOf(SegNumber); i = i + 1) begin
            if(fromInteger(i) < amount_comps) begin
                SegIndex cur_seg =  amount_comps + fromInteger(i);
                let a_old = segs[cur_seg];
                a_old.age = fromInteger(valueOf(MaxAge));
                counter = counter - 1;
                segs[cur_seg] <= a_old;
            end
        end
        if(!p.v) begin
            SegIndex id = findNextSeg();
            p.start = zeroExtend(id) << fromInteger(valueOf(SegBits));
            p.length = fromInteger(valueOf(SegSize));
            p.v = True;
            pointers[upd] <= p;
        end

    endrule

    rule doAging(timeout == fromInteger(valueOf(TSub#(TimeoutSize, 1))) &&& updateCID.wget matches tagged Invalid);
        $display("Aging happening");
        Vector#(CompNumber, Bool) v = replicate(False);
        for(Integer i = 0; i < valueOf(SegNumber); i = i + 1) begin
            let a = segs[i];
            if(a.cid != rg_cid) begin
                a.age = (a.age >> 1);
                if(a.age == 0) begin
                    v[a.cid] = True;
                end
            end
            segs[i] <= a;
        end
        for(Integer i = 0; i < valueOf(CompNumber); i = i + 1) begin
            let p = pointers[i];
            if(v[i]) begin
                if(p.length == fromInteger(valueOf(SegSize))) begin
                    p.v = False;
                end
                else begin
                    p.length = p.length - fromInteger(valueOf(SegSize));
                    p.start = p.start + fromInteger(valueOf(SegSize));
                end
            end
            else begin
                let a = segs[i];
                Bit#(SegBits) comp = truncate((p.start + p.length) >> fromInteger(valueOf(SegBits)));
                if(comp == fromInteger(i) && (a.age == 1 || a.age == 0)) begin
                    p.length = p.length + fromInteger(valueOf(SegSize));
                end
            end
            pointers[i] <= p;
        end
    endrule

    Vector#(SupSize, RAS) rasIfc;
    for(Integer i = 0; i < valueof(SupSize); i = i + 1) begin
        rasIfc[i] = (interface RAS;
            method CapMem first;
                return stack[heads[rg_cid][i]][i];
            endmethod
            method Action popPush(Bool pop, Maybe#(CapMem) pushAddr);
                // first pop, then push
                EntriesIndex h = heads[rg_cid][i];
                let p = pointers[rg_cid];
                if(pop) begin
                    h = ((h - 1) % p.length) + p.start;
                end
                if(pushAddr matches tagged Valid .addr) begin
                    h = ((h + 1) % p.length) + p.start;
                    stack[h][i] <= addr;
                end
                heads[rg_cid][i] <= h;
            endmethod
        endinterface);
    end

    interface ras = rasIfc;

    method Action setCID(CompIndex cid);
        updateCID.wset(cid);
    endmethod

    method flush = noAction;
    method flush_done = True;



endmodule
