
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


module mkTourPredCore(DirPredictor#(TourTrainInfo));
    // local history: MSB is the latest branch
    RegFileSD#(PCIndex, TourLocalHist) localHistTab <- mkRegFileWCFSD(0, maxBound, fromInteger(valueOf(DefValue)));
    // local sat counters
    RegFileSD#(TourLocalHist, Int#(3)) localBht <- mkRegFileWCFSD(0, maxBound, fromInteger(valueOf(DefValue)));
    // global history reg
    TourGHistReg gHistReg <- mkTourGHistReg;
    // global sat counters
    RegFileSD#(TourGlobalHist, Int#(2)) globalBht <- mkRegFileWCFSD(0, maxBound, fromInteger(valueOf(DefValue)));
    // choice sat counters: large (taken) -- use local, small (not taken) -- use global
    RegFileSD#(TourGlobalHist, Int#(2)) choiceBht <- mkRegFileWCFSD(0, maxBound, fromInteger(valueOf(DefValue)));

    // Lookup PC
    Reg#(Addr) pc_reg <- mkRegU;

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
    Reg#(Vector#(SupSize, Bool)) globalTakenVec <- mkRegU;
    Reg#(Vector#(SupSize, Bool)) useLocalVec <- mkRegU;

    Vector#(SupSize, DirPred#(TourTrainInfo)) predIfc;
    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
        predIfc[i] = (interface DirPred;
            method ActionValue#(DirPredResult#(TourTrainInfo)) pred;
                PCIndex pcIndex = getPCIndex(offsetPc(pc_reg, i));
                // get local history & prediction
                TourLocalHist localHist = localHistTab.sub(pcIndex);
                Bool localTaken = isTaken(localBht.sub(localHist));

                // get the global history
                // all previous branch in this cycle must be not taken
                // otherwise this branch should be on wrong path
                // because all inst in same cycle are fetched consecutively
                // get global prediction
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
                let ret_val = DirPredResult {
                    taken: taken,
                    train: TourTrainInfo {
                        globalHist: curGHist >> predCnt[i],
                        localHist: localHist,
                        globalTaken: globalTaken,
                        localTaken: localTaken,
                        pcIndex: pcIndex
                    }
                };
                return ret_val;
            endmethod
        endinterface);
    end

    (* fire_when_enabled, no_implicit_conditions *)
    rule canonGlobalHist;
        gHistReg.addHistory(predRes[valueof(SupSize)], predCnt[valueof(SupSize)]);
        // Buffer useLocalVec
        // Reproduce next history; this would ideally be done in GlobalBrHistReg to avoid duplicating logic.
        TourGlobalHist nHist = truncate({predRes[valueof(SupSize)], curGHist} >> predCnt[valueof(SupSize)]);
        function Bool globalTakenLookup (Integer i) = isTaken(globalBht.sub(nHist >> i));
        function Bool useLocalLookup (Integer i) = isTaken(choiceBht.sub(nHist >> i));
        globalTakenVec <= genWith(globalTakenLookup);
        useLocalVec <= genWith(useLocalLookup);
        // Reset counters and prediction.
        predRes[valueof(SupSize)] <= 0;
        predCnt[valueof(SupSize)] <= 0;
    endrule

    method nextPc = pc_reg._write;

    interface pred = predIfc;

`ifdef CID
    method Action setCID(CompIndex cid) = noAction;
    method Action shootdown(CompIndex cid);
        localHistTab.shootdown();
        localBht.shootdown();
        gHistReg.shootdown();
        globalBht.shootdown();
        choiceBht.shootdown();
    endmethod
`endif

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


interface RegFileSD #(type index_t, type data_t);
    method Action upd(index_t addr, data_t d);
    method data_t sub(index_t addr);
    method Action shootdown();
endinterface

module mkRegFileWCFSD#(index_t lo, index_t hi, data_t default_value)(RegFileSD#(index_t, data_t)) provisos (
    Bits#(index_t, index_sz),
    Bits#(data_t, data_sz),
    Literal#(index_t),
    PrimIndex#(index_t, a__));
    
    RegFile#(index_t, data_t) rf <- mkRegFileWCF(lo, hi);
    Vector#(SizeOf#(index_t), Ehr#(2, Bool)) valids <- replicateM(mkEhr(False));

    method Action upd(index_t addr, data_t d);
        rf.upd(addr, d);
        valids[addr][0] <= True;
    endmethod

    method data_t sub(index_t addr);
        if(valids[addr][0]) return rf.sub(addr);
        else return default_value;
    endmethod

    method Action shootdown();
        writeVReg(getVEhrPort(valids, 1), replicate(False));
    endmethod
endmodule