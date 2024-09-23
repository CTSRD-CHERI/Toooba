// Copyright (c) 2017 Massachusetts Institute of Technology
//
//-
// RVFI_DII + CHERI modifications:
//     Copyright (c) 2020 Jonathan Woodruff
//     Copyright (c) 2020 Franz Fuchs
//     All rights reserved.
//
//     This software was developed by SRI International and the University of
//     Cambridge Computer Laboratory (Department of Computer Science and
//     Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
//     DARPA SSITH research programme.
//
//     This work was supported by NCSC programme grant 4212611/RFA 15971 ("SafeBet").
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
`ifdef ParTag
import BrPred::*;
import TourPredCore::*;
import Vector::*;
import ProcTypes::*;
import Types::*;
import Ehr::*;

(* synthesize *)
module mkTourPredPartition(DirPredictor#(TourTrainInfo));

    Vector#(PTNumber, DirPredictor#(TourTrainInfo)) dir_preds <- replicateM(mkTourPredCore);
    Reg#(PTIndex) rg_ptid <- mkReg(0); // default zero id
    Ehr#(2, Maybe#(PTIndex)) curr_ptid <- mkEhr(?);


    Vector#(SupSize, DirPred#(TourTrainInfo)) predIfc;
    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
        predIfc[i] = (interface DirPred;
            method ActionValue#(DirPredResult#(TourTrainInfo)) pred;
                if(curr_ptid[0] matches tagged Valid .cp) begin
                    let x <- dir_preds[cp].pred[i].pred; 
                    return x;
                end
                else begin
                return DirPredResult {
                    taken: False,
                    train: ?
                };
                end
            endmethod
        endinterface);
    end

    method Action nextPc(Addr nextPC);
        if(curr_ptid[1] matches tagged Valid .cp) dir_preds[cp].nextPc(nextPC);
        else noAction;
    endmethod
    interface pred = predIfc;
    method Action update(Bool taken, TourTrainInfo train, Bool mispred, Maybe#(PTIndex) ptid);
        if (ptid matches tagged Valid .p) dir_preds[p].update(taken, train, mispred, ptid);
        else noAction;
    endmethod
`ifdef ParTag
    method Action setPTID(PTIndex ptid);
        rg_ptid <= ptid;
    endmethod
    method Action setCurrPTID(Maybe#(PTIndex) ptid);
        curr_ptid[0] <= ptid;
    endmethod
    method shootdown = dir_preds[rg_ptid].shootdown;
`endif
    method flush = dir_preds[rg_ptid].flush;
    method flush_done = dir_preds[rg_ptid].flush_done;
endmodule
`endif