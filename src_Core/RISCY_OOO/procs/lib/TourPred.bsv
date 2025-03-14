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

import Types::*;
import ProcTypes::*;
import RegFile::*;
import Ehr::*;
import Vector::*;
import GlobalBrHistReg::*;
import BrPred::*;

export TourLocalHistSz;
export TourLocalHist;
export TourGlobalHistSz;
export TourGlobalHist;
export TourTrainInfo(..);
export TourGHistReg(..);
export mkTourGHistReg;
export mkTourPred;
export PCIndexSz;
export PCIndex;

`ifdef SMALL_BRANCH_PREDICTOR
    // 512B tournament predictor
    typedef 9 TourGlobalHistSz;
    typedef 7 TourLocalHistSz;
    typedef 7 PCIndexSz;
`else
    // 4KB tournament predictor
    typedef 12 TourGlobalHistSz;
    typedef 10 TourLocalHistSz;
    typedef 10 PCIndexSz;
`endif

typedef Bit#(TourGlobalHistSz) TourGlobalHist;
typedef Bit#(TourLocalHistSz) TourLocalHist;
typedef Bit#(PCIndexSz) PCIndex;

typedef struct {
    TourGlobalHist globalHist;
    TourLocalHist localHist;
    Bool globalTaken;
    Bool localTaken;
    PCIndex pcIndex;
} TourTrainInfo deriving(Bits, Eq, FShow);

// global history reg
typedef GlobalBrHistReg#(TourGlobalHistSz) TourGHistReg;

(* synthesize *)
module mkTourGHistReg(TourGHistReg);
    let m <- mkGlobalBrHistReg;
    return m;
endmodule

(* synthesize *)
module mkTourPred(DirPredictor#(TourTrainInfo));
    // local history: MSB is the latest branch
    RegFile#(PCIndex, TourLocalHist) localHistTab <- mkRegFileWCF(0, maxBound);
    // local sat counters
    RegFile#(TourLocalHist, Int#(3)) localBht <- mkRegFileWCF(0, maxBound);
    // global history reg
    TourGHistReg gHistReg <- mkTourGHistReg;
    // global sat counters
    RegFile#(TourGlobalHist, Int#(2)) globalBht <- mkRegFileWCF(0, maxBound);
    // choice sat counters: large (taken) -- use local, small (not taken) -- use global
    RegFile#(TourGlobalHist, Int#(2)) choiceBht <- mkRegFileWCF(0, maxBound);

    // Lookup PC
    Reg#(Addr) pc_reg <- mkRegU;
    Reg#(Vector#(SupSize, PCIndex)) pcIndex <- mkRegU;

    // EHR to record predict results in this cycle
    Ehr#(TAdd#(1, SupSize), SupCnt) predCnt <- mkEhr(0);
    Ehr#(TAdd#(1, SupSize), Bit#(SupSize)) predRes <- mkEhr(0);

    function PCIndex getPCIndex(Addr pc);
        return truncate(pc >> 1);
    endfunction

    // common sat counter operations
    function Bool isTaken(Int#(n) cnt) = (cnt < 0);
    function Int#(n) updateCnt(Int#(n) cnt, Bool taken) =
        boundedPlus(cnt, (taken) ? -1 : 1);

    TourGlobalHist curGHist = gHistReg.history; // global history: MSB is the latest branch
    Reg#(TourGlobalHist) prevGHist <- mkRegU;
    Reg#(Vector#(SupSize, Bool)) globalTakenVec <- mkRegU;
    Reg#(Vector#(SupSize, Bool)) useLocalVec <- mkRegU;

    Vector#(SupSize, DirPred#(TourTrainInfo)) predIfc;
    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
        predIfc[i] = (interface DirPred;
            method ActionValue#(DirPredResult#(TourTrainInfo)) pred;
                // get local history & prediction
                TourLocalHist localHist = localHistTab.sub(pcIndex[i]);
                Bool localTaken = isTaken(localBht.sub(localHist));

                // get the global history
                // all previous branch in this cycle must be not taken
                // otherwise this branch should be on wrong path
                // because all inst in same cycle are fetched consecutively
                // get global prediction
                // XXX This isn't true anymore...
                // The current pipeline does not keep fetched bundles
                // together at decode; you might get decoded next
                // to an instruction from the next bundle.
                Bool globalTaken = globalTakenVec[predCnt[i]];

                // make choice
                Bool useLocal = useLocalVec[predCnt[i]];
                Bool taken = useLocal ? localTaken : globalTaken;

                // record prediction
                predCnt[i] <= predCnt[i] + 1;
                Bit#(SupSize) res = predRes[i];
                res[predCnt[i]] = pack(taken);
                predRes[i] <= res;

                // return
                return DirPredResult {
                    taken: taken,
                    train: TourTrainInfo {
                        globalHist: prevGHist >> predCnt[i],
                        localHist: localHist,
                        globalTaken: globalTaken,
                        localTaken: localTaken,
                        pcIndex: pcIndex[i]
                    }
                };
            endmethod
        endinterface);
    end

    (* fire_when_enabled, no_implicit_conditions *)
    rule canonGlobalHist;
        // Update history for next cycle's lookup.
        gHistReg.addHistory(predRes[valueof(SupSize)], predCnt[valueof(SupSize)]);
        // Reproduce next history; this would ideally be done in GlobalBrHistReg to avoid duplicating logic.
        TourGlobalHist nHist = truncate({predRes[valueof(SupSize)], curGHist} >> predCnt[valueof(SupSize)]);
        function Bool globalTakenLookup (Integer i) = isTaken(globalBht.sub(nHist >> i));
        function Bool useLocalLookup (Integer i) = isTaken(choiceBht.sub(nHist >> i));
        globalTakenVec <= genWith(globalTakenLookup);
        useLocalVec <= genWith(useLocalLookup);
        // Reset counters and prediction.
        predRes[valueof(SupSize)] <= 0;
        predCnt[valueof(SupSize)] <= 0;
        prevGHist <= nHist;
    endrule

    method Action nextPc(Addr pc);
        pc_reg <= pc;
        function PCIndex genPcIndex(Integer i) = getPCIndex(offsetPc(pc, i));
        pcIndex <= genWith(genPcIndex); // Call getPCIndex with 0-SupSize.
    endmethod

    interface pred = predIfc;

    method Action update(Bool taken, TourTrainInfo train, Bool mispred);
        // update history if mispred
        if(mispred) begin
            TourGlobalHist newHist = truncateLSB({pack(taken), train.globalHist});
            gHistReg.redirect(newHist);
        end
        // update local history (assume only 1 branch for an PC in flight)
        localHistTab.upd(train.pcIndex, truncateLSB({pack(taken), train.localHist}));
        // update local sat cnt
        let localCnt = localBht.sub(train.localHist);
        localBht.upd(train.localHist, updateCnt(localCnt, taken));
        // update global sat cnt
        let globalCnt = globalBht.sub(train.globalHist);
        globalBht.upd(train.globalHist, updateCnt(globalCnt, taken));
        // update choice cnt
        if(train.globalTaken != train.localTaken) begin
            Bool useLocal = train.localTaken == taken;
            let choiceCnt = choiceBht.sub(train.globalHist);
            choiceBht.upd(train.globalHist, updateCnt(choiceCnt, useLocal));
        end
    endmethod

    method flush = noAction;
    method flush_done = True;
endmodule
