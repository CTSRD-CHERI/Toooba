/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2021 Franz Fuchs
 * All rights reserved
 *
 *
 * TODO: is this the correct copyright header
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory (Department of Computer Science and
 * Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
 * DARPA SSITH research programme.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
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
typedef Bit#(TLog#(Entries)) EntriesIndex;
typedef Bit#(SegNumber) Age;
typedef Bit#(TLog#(TimeoutSize)) TimeoutIndex;

typedef struct {
    EntriesIndex start;
    EntriesIndex length;
    Bool v;
} CompPointer deriving (Bits, Eq, FShow);

typedef struct {
        CompIndex cid;
        Age age;
} CompAge deriving (Bits, Eq, FShow);

module mkCircularRas(ReturnAddrStack) provisos(NumAlias#(TExp#(TLog#(Entries)), Entries));
    Vector#(Entries, Ehr#(TAdd#(SupSize, 1), CapMem)) stack <- replicateM(mkEhr(0));
    Vector#(CompNumber, Reg#(CompPointer)) pointers <- replicateM(mkRegU);
    Vector#(SegNumber, Reg#(CompAge)) ages <- replicateM(mkRegU);
    Vector#(CompNumber, Ehr#(TAdd#(SupSize, 1), EntriesIndex)) heads <- replicateM(mkEhr(0));

    Reg#(CompIndex) rg_cid <- mkRegU;
    Reg#(TimeoutIndex) timeout <- mkReg(0);

    RWire#(CompIndex) updateCID <- mkRWire;

    function CompIndex findFreeSeg();
        CompIndex id = 0;
        Age a = 15;
        for(Integer i = 0; i < valueOf(SegNumber); i = i + 1) begin
            if(ages[i].age <= a) begin
               id = fromInteger(i);
               a = ages[i].age;
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
        if(!p.v) begin
            CompIndex id = findFreeSeg();
            p.start = zeroExtend(id) << 4;
            p.length = 16;
            pointers[upd] <= p;
        end

    endrule

    rule doAging(timeout == 1023 &&& updateCID.wget matches tagged Invalid);
        $display("Aging happening");
        Vector#(CompNumber, Bool) v = replicate(False);
        for(Integer i = 0; i < valueOf(SegNumber); i = i + 1) begin
            let a = ages[i];
            if(a.cid != rg_cid) begin
                a.age = (a.age >> 1);
                if(a.age == 0) begin
                    v[a.cid] = True;
                end
            end
            ages[i] <= a;
        end
        for(Integer i = 0; i < valueOf(CompNumber); i = i + 1) begin
            let p = pointers[i];
            if(v[i]) begin
                if(p.length == 16) begin
                    p.v = False;
                end
                else begin
                    p.length = p.length - 16;
                    p.start = p.start + 16;
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
