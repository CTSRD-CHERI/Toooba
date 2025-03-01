import BrPred::*;
import RegFile::*;
import LFSR::*;
import Vector::*;

import TaggedTable::*;
import ProcTypes::*;
import Types::*;
import Tage::*;
import GlobalBranchHistory::*;
import Fifos::*;
// For debugging
import Cur_Cycle :: *;

export TageTestTrainInfo;
export TageTestSpecInfo;
export TageTestFastTrainInfo;
export Entry;
export PCIndex;
export PCIndexSz;
export mkTageTest;

`define NUM_TABLES 7
typedef TageTrainInfo#(`NUM_TABLES) TageTestTrainInfo;
typedef TageSpecInfo TageTestSpecInfo;
typedef TageFastTrainInfo TageTestFastTrainInfo;
//typedef TagePred2ToPred3Data#(`NUM_TABLES) TageTestPred2ToPred3Info;

//(* synthesize *)
module mkTageTest(DirPredictor#(TageTrainInfo#(`NUM_TABLES), TageSpecInfo, TageTestFastTrainInfo));
    Reg#(Bool) starting <- mkReg(True);
    Tage#(7) tage <- mkTage;
    Reg#(UInt#(64)) predCount <- mkReg(0);
    Reg#(UInt#(64)) misPredCount <- mkReg(0);

    method Action update(Bool taken, TageTrainInfo#(`NUM_TABLES) train, Bool mispred);
        if(train.confirmed) begin // Take account of this
            predCount <= predCount+1;
            if(mispred)
                misPredCount <= misPredCount + 1;
        end
        $display("Cycle %0d, TAGETEST, predCount = %d, mispred Count = %d\n", cur_cycle, predCount, misPredCount);
        
        tage.dirPredInterface.update(taken, train, mispred);
    endmethod

    interface pred = tage.dirPredInterface.pred;
    interface clearIfc = tage.dirPredInterface.clearIfc;

    /*method Action confirmPred(Bit#(SupSize) results, SupCnt count);
        tage.dirPredInterface.confirmPred(results, count);
    endmethod*/

    method Action nextPc(Vector#(SupSize,Maybe#(PredIn#(TageFastTrainInfo))) next);
        tage.dirPredInterface.nextPc(next);
    endmethod

    method ActionValue#(Vector#(SupSizeX2, FastPredictResult#(TageFastTrainInfo))) fastPred(Addr pc); // No training
        let a <- tage.dirPredInterface.fastPred(pc);
        return a;
    endmethod

    method Action specRecover(TageSpecInfo specInfo, Bool taken, Bool nonBranch);
        tage.dirPredInterface.specRecover(specInfo, taken, nonBranch);
    endmethod

    method Vector#(SupSizeX2, TageSpecInfo) getSpec(Bit#(SupSizeX2) mask);
        return tage.dirPredInterface.getSpec(mask);
    endmethod

    method Action updateSpec(Bit#(TAdd#(TLog#(SupSizeX2),1)) i);
        tage.dirPredInterface.updateSpec(i);
    endmethod

    method flush = noAction;
    method flush_done = True;
endmodule