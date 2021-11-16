
// Copyright (c) 2017 Massachusetts Institute of Technology
//
//-
// RVFI_DII + CHERI modifications:
//     Copyright (c) 2020 Jonathan Woodruff
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

interface RAS;
    method CapMem first;
    // first pop, then push
    method ActionValue#(RasIndex) popPush(Bool pop, Maybe#(CapMem) pushAddr);
endinterface

// Local RAS Typedefs SHOULD BE A POWER OF TWO.
typedef 16 RasEntries;
typedef Bit#(TLog#(RasEntries)) RasIndex;
typedef RasIndex RasPredTrainInfo;

interface ReturnAddrStack;
    interface Vector#(SupSize, RAS) ras;
    method Action setHead(RasIndex h);
    method Action flush;
    method Bool flush_done;
endinterface

(* synthesize *)
module mkRas(ReturnAddrStack) provisos(NumAlias#(TExp#(TLog#(RasEntries)), RasEntries));
    Vector#(RasEntries, Ehr#(TAdd#(SupSize, 1), CapMem)) stack <- replicateM(mkEhr(nullCap));
    // head points past valid data
    // to gracefully overflow, head is allowed to overflow to 0 and overwrite the oldest data
    Ehr#(TAdd#(SupSize, 2), RasIndex) head <- mkEhr(0);

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
            method ActionValue#(RasIndex) popPush(Bool pop, Maybe#(CapMem) pushAddr);
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
                return h;
            endmethod
        endinterface);
    end

    method Action setHead(RasIndex h);
        head[valueof(SupSize) + 1] <= h;
    endmethod

    interface ras = rasIfc;

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
