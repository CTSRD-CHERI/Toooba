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
export Entry;
export PCIndex;
export PCIndexSz;
export mkTageTest;

`define NUM_TABLES 7
typedef TageTrainInfo#(`NUM_TABLES) TageTestTrainInfo;
typedef TageSpecInfo TageTestSpecInfo;

module mkTageTest#(Vector#(SupSize, SupFifoEnq#(GuardedResult#(TageTestTrainInfo, TageTestSpecInfo))) outInf)(DirPredictor#(TageTrainInfo#(`NUM_TABLES), TageSpecInfo));
    Reg#(Bool) starting <- mkReg(True);
    Tage#(7) tage <- mkTage(outInf);
    Reg#(UInt#(64)) predCount <- mkReg(0);
    Reg#(UInt#(64)) misPredCount <- mkReg(0);

    method Action update(Bool taken, TageTrainInfo#(`NUM_TABLES) train, Bool mispred);
        predCount <= predCount+1;
        if(mispred)
            misPredCount <= misPredCount + 1;
        $display("Cycle %0d, TAGETEST, predCount = %d, mispred Count = %d\n", cur_cycle, predCount, misPredCount);
        
        tage.dirPredInterface.update(taken, train, mispred);
    endmethod

    method Action confirmPred(Bit#(SupSize) results, SupCnt count);
        tage.dirPredInterface.confirmPred(results, count);
    endmethod

    method Action nextPc(Vector#(SupSize,Maybe#(PredIn)) next);
        tage.dirPredInterface.nextPc(next);
    endmethod

    method Action specRecover(TageSpecInfo specInfo, Bool taken);
        tage.dirPredInterface.specRecover(specInfo, taken);
    endmethod

    method flush = noAction;
    method flush_done = True;
endmodule