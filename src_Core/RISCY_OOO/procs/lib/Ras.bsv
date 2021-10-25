
// Copyright (c) 2017 Massachusetts Institute of Technology
//
//-
// RVFI_DII + CHERI modifications:
//     Copyright (c) 2020 Jonathan Woodruff
//     Copyright (c) 2021 Franz Fuchs
//     All rights reserved.
//
//     This software was developed by SRI International and the University of
//     Cambridge Computer Laboratory (Department of Computer Science and
//     Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
//     DARPA SSITH research programme.
//
//     This work was supported by NCSC programme grant 4212611/RFA 15971 ("SafeBet").
//-
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

`include "ProcConfig.bsv"
import Types::*;
import ProcTypes::*;
import RegFile::*;
import Vector::*;
import Ehr::*;
import CHERICC_Fat::*;
import CHERICap::*;

//export ReturnAddrStack(..);
//export mkRas;
//export RAS;

interface RAS;
    method CapMem first;
    // first pop, then push
    method Action popPush(Bool pop, Maybe#(CapMem) pushAddr);
endinterface

interface ReturnAddrStack;
    interface Vector#(SupSize, RAS) ras;
    method Action setCID(CompIndex cid);
    method Action flush;
    method Bool flush_done;
endinterface

// Local RAS Typedefs SHOULD BE A POWER OF TWO.
typedef 8 RasEntries;
typedef Bit#(TLog#(RasEntries)) RasIndex;

//(* synthesize *)
//module mkRas(ReturnAddrStack);
//    ReturnAddrStack ras <- mkRasPartition(inIfc);
//    return ras;
//endmodule

(* synthesize *)
module mkRas(ReturnAddrStack);
    Vector#(CompNumber, ReturnAddrStack) rases <- replicateM(mkRasSingle);
    Reg#(CompIndex) rg_cid <- mkReg(0);
    interface ras = rases[rg_cid].ras;
    method Action setCID(CompIndex cid);
        rg_cid <= cid;
    endmethod
    method flush = rases[rg_cid].flush;
    method flush_done = rases[rg_cid].flush_done;
endmodule

module mkRasSingle(ReturnAddrStack) provisos(NumAlias#(TExp#(TLog#(RasEntries)), RasEntries));
    Vector#(RasEntries, Ehr#(TAdd#(SupSize, 1), CapMem)) stack <- replicateM(mkEhr(nullCap));
    // head points past valid data
    // to gracefully overflow, head is allowed to overflow to 0 and overwrite the oldest data
    Ehr#(TAdd#(SupSize, 1), RasIndex) head <- mkEhr(0);

`ifdef SECURITY
    Reg#(Bool) flushDone <- mkReg(True);

    rule doFlush(!flushDone);
        writeVReg(getVEhrPort(stack, valueof(SupSize)), replicate(0));
        head[valueof(SupSize)] <= 0;
        flushDone <= True;
    endrule
`endif

    Vector#(SupSize, RAS) rasIfc;
    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
        rasIfc[i] = (interface RAS;
            method CapMem first;
                return stack[head[i]][i];
            endmethod
            method Action popPush(Bool pop, Maybe#(CapMem) pushAddr);
                // first pop, then push
                RasIndex h = head[i];
                if(pop) begin
                    h = h - 1;
                end
                if(pushAddr matches tagged Valid .addr) begin
                    h = h + 1;
                    stack[h][i] <= addr;
                end
                head[i] <= h;
            endmethod
        endinterface);
    end

    interface ras = rasIfc;

    method Action setCID(CompIndex cid) = noAction;

`ifdef SECURITY
    method Action flush if(flushDone);
        flushDone <= False;
    endmethod
    method flush_done = flushDone._read;
`else
    method flush = noAction;
    method flush_done = True;
`endif
endmodule


module mkRasPartition(ReturnAddrStack) provisos(NumAlias#(TExp#(TLog#(RasEntries)), RasEntries));
    Vector#(CompNumber, Vector#(RasEntries, Ehr#(TAdd#(SupSize, 1), CapMem))) stack;
    for(Integer i = 0; i < valueOf(CompNumber); i = i + 1)
            stack[i] <- replicateM(mkEhr(nullCap));
    // head points past valid data
    // to gracefully overflow, head is allowed to overflow to 0 and overwrite the oldest data
    Vector#(CompNumber, Ehr#(TAdd#(SupSize, 1), RasIndex)) head <- replicateM(mkEhr(0));

    Reg#(CompIndex) rg_cid <- mkReg(0);

`ifdef SECURITY
    Reg#(Bool) flushDone <- mkReg(True);

    rule doFlush(!flushDone);
        writeVReg(getVEhrPort(stack, valueof(SupSize)), replicate(0));
        head[valueof(SupSize)] <= 0;
        flushDone <= True;
    endrule
`endif

    Vector#(SupSize, RAS) rasIfc;
    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
        rasIfc[i] = (interface RAS;
            method CapMem first;
                return stack[rg_cid][head[rg_cid][i]][i];
            endmethod
            method Action popPush(Bool pop, Maybe#(CapMem) pushAddr);
                // first pop, then push
                RasIndex h = head[rg_cid][i];
                if(pop) begin
                    h = h - 1;
                end
                if(pushAddr matches tagged Valid .addr) begin
                    h = h + 1;
                    stack[rg_cid][h][i] <= addr;
                end
                head[rg_cid][i] <= h;
            endmethod
        endinterface);
    end

    interface ras = rasIfc;

    method Action setCID(CompIndex cid);
        rg_cid <= cid;
    endmethod

`ifdef SECURITY
    method Action flush if(flushDone);
        flushDone <= False;
    endmethod
    method flush_done = flushDone._read;
`else
    method flush = noAction;
    method flush_done = True;
`endif
endmodule
