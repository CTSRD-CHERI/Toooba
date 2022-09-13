
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
import RWBramCore::*;


module mkTourPredBram(DirPredictor#(TourTrainInfo));
    // local history: MSB is the latest branch
    RegFileSD#(PCIndex, TourLocalHist) localHistTab <- mkRegFileWCFSD(0, maxBound, fromInteger(valueOf(DefValue)));
    // global history reg
    TourGHistReg gHistReg <- mkTourGHistReg;
    // global sat counters
    Vector#(SupSize, RWBramCoreDual#(TourGlobalHist, Int#(2))) globalBhtBram <- replicateM(mkRWBramCoreDualUG);
    // choice sat counters: large (taken) -- use local, small (not taken) -- use global
    Vector#(SupSize, RWBramCoreDual#(TourGlobalHist, Int#(2))) choiceBhtBram <- replicateM(mkRWBramCoreDualUG);
    // local sat counters
    Vector#(SupSize, RWBramCoreDual#(TourLocalHist, Int#(3))) localBhtBram <- replicateM(mkRWBramCoreDualUG);

    // Lookup PC
    Reg#(Addr) pc_reg <- mkRegU;

    // registers/EHRs for two-cycle update
    Ehr#(2, Bool) updateNeeded <- mkEhr(False);
    Reg#(Bool) updateTaken <- mkReg(False);
    Reg#(TourTrainInfo) updateInfo <- mkRegU;

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

    rule doUpdate(updateNeeded[0]);
        updateNeeded[0] <= False;
        let taken = updateTaken;
        let localTaken = updateInfo.localTaken;
        let globalTaken = updateInfo.globalTaken;
        let localHist = updateInfo.localHist;
        let globalHist = updateInfo.globalHist;
        let localCnt = localBhtBram[0].rdRespB;
        for(Integer i = 0; i < valueof(SupSize); i = i + 1) localBhtBram[i].wrReq(localHist, updateCnt(localCnt, taken));
        // update global sat cnt
        let globalCnt = globalBhtBram[0].rdRespB();
        for(Integer i = 0; i < valueof(SupSize); i = i + 1) globalBhtBram[i].wrReq(globalHist, updateCnt(globalCnt, taken));
        // update choice cnt
        if(globalTaken != localTaken) begin
            Bool useLocal = localTaken == taken;
            let choiceCnt = choiceBhtBram[0].rdRespB();
            for(Integer i = 0; i < valueof(SupSize); i = i + 1) choiceBhtBram[i].wrReq(globalHist, updateCnt(choiceCnt, useLocal));
        end
    endrule
    Vector#(SupSize, Bool) ulv;
    for(Integer i = 0; i < valueof(SupSize); i = i + 1) ulv[i] = isTaken(choiceBhtBram[i].rdRespA());
    Vector#(SupSize, Bool) ugv;
    for(Integer i = 0; i < valueof(SupSize); i = i + 1) ugv[i] = isTaken(globalBhtBram[i].rdRespA());

    Vector#(SupSize, DirPred#(TourTrainInfo)) predIfc;
    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
        predIfc[i] = (interface DirPred;
            method ActionValue#(DirPredResult#(TourTrainInfo)) pred;

                PCIndex pcIndex = getPCIndex(offsetPc(pc_reg, i));
                // get local history & prediction
                TourLocalHist localHist = localHistTab.sub(pcIndex);

                Bool localTaken = isTaken(localBhtBram[i].rdRespA());

                // get the global history
                // all previous branch in this cycle must be not taken
                // otherwise this branch should be on wrong path
                // because all inst in same cycle are fetched consecutively
                // get global prediction

                Bool globalTaken = ugv[predCnt[i]];

                // make choice
                Bool useLocal = ulv[predCnt[i]];
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
        predRes[valueof(SupSize)] <= 0;
        predCnt[valueof(SupSize)] <= 0;
    endrule


    method Action nextPc(Addr nexgtPc);
        pc_reg <= nexgtPc;
        for(Integer i = 0; i < valueof(SupSize); i = i + 1) begin
            PCIndex pcIndex = getPCIndex(offsetPc(nexgtPc, i));
            // get local history & prediction
            TourLocalHist localHist = localHistTab.sub(pcIndex);
            TourGlobalHist nHist = truncate({predRes[valueof(SupSize)], curGHist} >> predCnt[valueof(SupSize)]);
            globalBhtBram[i].rdReqA(nHist >> i);
            choiceBhtBram[i].rdReqA(nHist >> i);
            localBhtBram[i].rdReqA(localHist);
        end
    endmethod

    interface pred = predIfc;

`ifdef CID
    method Action setCID(CompIndex cid) = noAction;
    //method Action shootdown(CompIndex cid);
    //    localHistTab.shootdown();
    //    localBht.shootdown();
    //    gHistReg.shootdown();
    //    globalBht.shootdown();
    //    choiceBht.shootdown();
    //endmethod
`endif

    method Action update(Bool taken, TourTrainInfo train, Bool mispred);
        // update history if mispred
        if(mispred) begin
            TourGlobalHist newHist = truncateLSB({pack(taken), train.globalHist});
            gHistReg.redirect(newHist);
        end
        // update local history (assume only 1 branch for an PC in flight)
        localHistTab.upd(train.pcIndex, truncateLSB({pack(taken), train.localHist}));
        updateNeeded[1] <= True;
        updateTaken <= taken;
        updateInfo <= train;
        // update local sat cnt
        localBhtBram[0].rdReqB(train.localHist);
        globalBhtBram[0].rdReqB(train.globalHist);
        choiceBhtBram[0].rdReqB(train.globalHist);

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