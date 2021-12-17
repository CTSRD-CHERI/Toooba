
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
//
// Bram implementation:
//     Copyright (c) 2021 Franz Fuchs
//     All rights reserved.
//
//     This software was developed by the University of  Cambridge
//     Department of Computer Science and Technology under the
//     SIPP (Secure IoT Processor Platform with Remote Attestation)
//     project funded by EPSRC: EP/S030868/1

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
        bram.rdReq(head[valueOf(SupSize) + 1]);// - zeroExtend(bottom[valueOf(SupSize) + 1])); //- fromInteger(valueOf(SupSize)));
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
