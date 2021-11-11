
// Copyright (c) 2017 Massachusetts Institute of Technology
//
//-
// RVFI_DII + CHERI modifications:
//     Copyright (c) 2020 Jessica Clarke
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

import Types::*;
import ProcTypes::*;
import ConfigReg::*;
import Map::*;
import Vector::*;
import CHERICC_Fat::*;
import CHERICap::*;
import Btb_IFC::*;
import BtbCore::*;
import BtbDynamic::*;

export mkBtb;

(* synthesize *)
module mkBtb(NextAddrPred#(16));
    NextAddrPred#(16) btb <- mkBtbDynamic;
    return btb;
endmodule

//(* synthesize *)
//module mkBtb#(BtbInput inIfc)(NextAddrPred#(16));
//    NextAddrPred#(16) btb <- mkBtbCoreCID(inIfc);
//    return btb;
//endmodule

//(* synthesize *)
//module mkBtb(NextAddrPred#(16));
//    Vector#(CompNumber, NextAddrPred#(16)) btbs <- replicateM(mkBtbCore);
//    Reg#(CompIndex) rg_cid <- mkReg(0);
//    method Action setCID(CompIndex cid);
//        rg_cid <= cid;
//    endmethod
//    method Action put_pc(CapMem pc);
//        btbs[rg_cid].put_pc(pc);
//    endmethod
//    interface pred = btbs[rg_cid].pred;
//    method Action update(CapMem pc, CapMem brTarget, Bool taken);
//        btbs[rg_cid].update(pc, brTarget, taken);
//    endmethod
//    method Action flush;
//        btbs[rg_cid].flush;
//    endmethod
//    method Bool flush_done = btbs[rg_cid].flush_done;
//endmodule

