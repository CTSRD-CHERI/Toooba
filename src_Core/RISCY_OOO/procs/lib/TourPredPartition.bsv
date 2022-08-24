
// Copyright (c) 2017 Massachusetts Institute of Technology
//
//-
// RVFI_DII + CHERI modifications:
//     Copyright (c) 2020 Jonathan Woodruff
//     Copyright (c) 2021-2022 Franz Fuchs
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

import Types::*;
import ProcTypes::*;
import RegFile::*;
import Ehr::*;
import Vector::*;
import GlobalBrHistReg::*;
import BrPred::*;
import SDPMem::*;
import TourPredCore::*;
import TourPredBram::*;



`ifdef CID
(* synthesize *)
module mkTourPredPartition(DirPredictor#(TourTrainInfo));
    Vector#(CompNumber, DirPredictor#(TourTrainInfo)) preds <- replicateM(mkTourPredCore);
    Reg#(CompIndex) rg_cid <- mkReg(0);
    interface pred = preds[rg_cid].pred;
    method nextPc = preds[rg_cid].nextPc;
    method Action setCID(CompIndex cid);
        rg_cid <= cid;
    endmethod
    method Action shootdown(CompIndex cid);
        preds[cid].shootdown(cid);
    endmethod
    method update = preds[rg_cid].update;
    method flush = preds[rg_cid].flush;
    method flush_done = preds[rg_cid].flush_done;
endmodule
`endif