
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
import RWBramCore::*;

/*
STATE INVARIANT...
*/

interface RAS;
    method CapMem first;
    // first pop, then push
    method Action popPush(Bool pop, Maybe#(CapMem) pushAddr);
endinterface

interface ReturnAddrStack;
    // naming
    // 1: push 0x0
    // 2:
    // 3:
    // 4: push 0xc
    interface Vector#(SupSize, RAS) ras;
    method Action rdReq;
    //method Vector#(SupSize, CapMem) rdData;
    //method Action writeback(Vector#(SupSize, Maybe#(CapMem)) v, Bit#(TLog#(SupSize)) popNum, Bit#(TLog#(SupSize)) pushNum);
    method Action flush;
    method Bool flush_done;
endinterface

// Local RAS Typedefs SHOULD BE A POWER OF TWO.
typedef 64 StackEntries;
typedef TLog#(StackEntries) StackSize;

(* synthesize *)
module mkRas(ReturnAddrStack); // provisos(NumAlias#(TExp#(TLog#(RasEntries)), RasEntries));
    RWBramCoreVector#(Bit#(StackSize), CapMem, SupSize) bram <- mkRWBramCoreVector;

    // current addr to the BRAM
    Ehr#(TAdd#(SupSize, 1), Bit#(StackSize)) head <- mkEhr(0);

    Vector#(SupSize, Wire#(Maybe#(CapMem))) push_wires <- replicateM(mkDWire(tagged Invalid));

    /*rule canon;
        bram.wrReq(head[valueOf(SupSize)], readVReg(push_wires));
    endrule*/

    // rule to constantly start read from head[last]

    // rule to read data into Ehr and use for first



// we get a vector of addresses from the BRAM of size SupSize
// we read write and write multiple times in once cycle to that
// we need to write back to


 // needs to be solved with wires
    Vector#(SupSize, RAS) rasIfc;
    //Vector#(SupSize, Maybe#(CapMem)) vec = replicate(tagged Invalid);
    Vector#(SupSizeX2, Ehr#(SupSizeX2, CapMem)) topElems <- replicateM(mkEhr(0));
    Vector#(SupSizeX2, Ehr#(SupSizeX2, Bool)) newlyPushed <- replicateM(mkEhr(False));
    Ehr#(SupSizeX2, Bit#(TLog#(SupSizeX2))) h <- mkEhr(fromInteger(valueof(SupSize)));
    Reg#(Bit#(2)) some <- mkReg(0);

    rule readData;
        let rd = bram.rdResp;
        for(Integer i = 0; i < valueOf(SupSize); i = i + 1) begin
            topElems[i][0] <= rd[i];
        end
    endrule

    rule writeData;
        Vector#(SupSize, Maybe#(CapMem)) v = replicate(tagged Invalid);
        Bit#(TLog#(SupSizeX2)) idx = 0;
        Bit#(TLog#(SupSize)) start = 0;
        for(Integer i = 0; i < valueOf(SupSizeX2); i = i + 1) begin
            if(newlyPushed[i][3]) begin
                v[idx] = tagged Valid topElems[i][3];
                if(idx == 0) start = fromInteger(i);
                idx = idx + 1;

            end
        end
        some <= 0;
        //bram.wrReq(0, v);
    endrule

    rule startRead;
        bram.rdReq(head[2] - fromInteger(valueOf(SupSize)));
    endrule

    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
        Integer idx = i + 1;
        rasIfc[i] = (interface RAS;
            method CapMem first;
                // returns the top of the stack
                return topElems[h[idx]][idx];
            endmethod
            method Action popPush(Bool pop, Maybe#(CapMem) pushAddr);
                // first pop, then push
                Bit#(TLog#(SupSizeX2)) x = h[idx];
                if(pop) begin
                    x = x - 1;
                end
                if(pushAddr matches tagged Valid .addr) begin
                    x = x + 1;
                    // write addr to wire
                    //push_wires[i].wset(pushAddr);
                    topElems[x][idx] <= addr;
                end
                h[idx] <= x;
            endmethod
        endinterface);
    end

    interface ras = rasIfc;

    /*method Action rdReq();
        bram.rdReq(head[2]);
    endmethod*/

    /*method Vector#(SupSize, CapMem) rdData;
        return bram.rdResp;
    endmethod*/

    /*method Action writeback(Vector#(SupSize, Maybe#(CapMem)) v, Bit#(TLog#(SupSize)) popNum, Bit#(TLog#(SupSize)) pushNum);
        let diff = popNum - pushNum;
        head[2] <= head[1] + signExtend(diff);
        Vector#(SupSize, Maybe#(CapMem)) ret = replicate(tagged Invalid);
        Bit#(TLog#(SupSize)) c = 0;
        if(diff != 0 && pushNum > 0) begin
            for(Integer i = 0; i < valueOf(SupSize); i = i + 1) begin
                if(v[i] matches tagged Valid .addr) v[c] = tagged Valid addr;
            end
            bram.wrReq(head[2], ret);
        end
    endmethod*/


endmodule
