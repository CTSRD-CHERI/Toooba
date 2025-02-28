import GlobalBranchHistory::*;
import FoldedHistory::*;
import BrPred::*;
import BranchParams::*;
import ProcTypes::*;
import Types::*;
import Util::*;
import RWBramCore::*;

import RegFile::*;
import Vector::*;


`define MAX_TAGGED 12
`define MAX_INDEX_SIZE 10

typedef 3 PredCtrSz;
typedef Bit#(PredCtrSz) PredCtr;

typedef 2 UsefulCtrSz;
typedef Bit#(UsefulCtrSz) UsefulCtr;

typedef TaggedTableEntry#(`MAX_TAGGED) WrappedEntry;

typedef struct {
    PredCtr predictionCounter;
    UsefulCtr usefulCounter;
    Bit#(tagSize) tag;
} TaggedTableEntry#(numeric type tagSize) deriving(Bits, Eq, FShow);

typedef struct {
    PredCtr predictionCounter;
    Bit#(tagSize) tag;
} InternalTaggedEntry#(numeric type tagSize) deriving(Bits, Eq, FShow);

typedef enum {
    INCREMENT,
    PRESERVE,
    DECREMENT
} UsefulCtrUpdate deriving (Bits, Eq, FShow);

typedef enum {
    BEFORE_RECOVERY,
    AFTER_RECOVERY
} HistoryRetrieve deriving (Bits, Eq, FShow);

function Bool takenFromCounter(PredCtr ctr);
    return unpack(pack(ctr)[valueOf(TSub#(PredCtrSz,1))]);
endfunction


// 100
// 011
function Bool weakCounter(PredCtr ctr);
    return (pack(ctr) == (1 << valueOf(TSub#(PredCtrSz,1)))) || (pack(ctr) == ((1 << valueOf(TSub#(PredCtrSz,1)))-1));
endfunction

interface TaggedTableRead#(numeric type tagSize, numeric type indexSize);
    method ActionValue#(Tuple2#(Bit#(`MAX_TAGGED), Bit#(`MAX_INDEX_SIZE))) lookupStart(Addr pc);
    method TaggedTableEntry#(`MAX_TAGGED) read;
endinterface

interface TaggedTableBRAM#(numeric type indexSize, numeric type tagSize, numeric type historyLength);
    
    //method TaggedTableEntry#(`MAX_TAGGED) access_wrapped_entry(Addr pc, Bit#(indexSize) index);

    interface Vector#(SupSize, TaggedTableRead#(tagSize, indexSize)) taggedTableRead;
    //method TaggedTableEntry#(`MAX_TAGGED) access_wrapped_entry(Addr pc);
    method Tuple2#(Bit#(tagSize), Bit#(indexSize)) trainingInfo(Addr pc, HistoryRetrieve recovered); // To be used in training

    method Action updateEntry(Bit#(`MAX_INDEX_SIZE) index, TaggedTableEntry#(`MAX_TAGGED) currentEntry, Bool taken, UsefulCtrUpdate usefulUpdate);        
    method Action updateHistory(Bit#(SupSize) results, SupCnt count);
    method Action updateRecovered(Bit#(1) taken);
    method Action recoverHistory(Bit#(TLog#(MaxSpecSize)) numRecovery);
    method Action decrementUsefulCounter(Bit#(indexSize) index, UsefulCtr ctr); // Many alternative options here, seperate useful counters?
    method Action allocateEntry(Bit#(indexSize) index, Bit#(tagSize) tag, Bool taken);

    /// Debug
    `ifdef DEBUG
        method Action debugUnsetEntry(Addr pc);
        method TaggedTableEntry#(tagSize) debugGetEntry(Bit#(indexSize) index);
    `endif

    `ifdef DEBUG_TAGETEST
        method Bit#(TAdd#(tagSize, indexSize)) debugGetHistory(HistoryRetrieve hr, Maybe#(Bit#(TLog#(SupSize))) count);
    `endif
endinterface

module mkTaggedTableBRAM#(GlobalBranchHistory#(GlobalHistoryLength) global) (TaggedTableBRAM#(indexSize, tagSize, historyLength)) provisos(
    Add#(a__, indexSize, 64), 
    Add#(b__, tagSize, 64), 
    Add#(indexSize, tagSize, foldedSize),
    Add#(f__, TAdd#(tagSize, indexSize), 64),
    Add#(d__, tagSize, `MAX_TAGGED),
    Add#(c__, indexSize, `MAX_INDEX_SIZE));
    
    FoldedHistory#(TAdd#(tagSize, indexSize)) folded <- mkFoldedHistory(valueOf(historyLength), global);
    //RegFile#(Bit#(indexSize), TaggedTableEntry#(tagSize)) tab <- mkRegFileWCFLoad(regInitTaggedTableFilename, 0, maxBound);

    Vector#(SupSize, RWBramCore#(Bit#(indexSize), InternalTaggedEntry#(tagSize))) entryTabs <- replicateM(mkRWBramCoreUGLoaded);
    Vector#(SupSize, RWBramCore#(Bit#(indexSize), UsefulCtr)) usefulTabs <- replicateM(mkRWBramCoreUGLoaded);

    Vector#(SupSize, TaggedTableRead#(tagSize, indexSize)) taggedTableReadIfc;
//    Reg#(Maybe#(Bit#(indexSize))) decrementReadFrom <- mkDReg(tagged Invalid);

    function Tuple2#(Bit#(tagSize), Bit#(indexSize)) getHistory(HistoryRetrieve hr, Addr pc, Maybe#(Bit#(TLog#(SupSize))) count);
        Bit#(TAdd#(tagSize, indexSize)) hist = 0;
        if(hr == AFTER_RECOVERY)
            hist = folded.recoveredHistory;
        else if(hr == BEFORE_RECOVERY)
            if(count matches tagged Valid .num)
                hist = folded.sameWindowHistory[num].history;
            else
                hist = folded.history;

        let combined = (pack(pc) ^ (pack(pc) >> 2) ^ (pack(pc) >> 5)) ^ zeroExtend(hist);
        
        let index = combined[valueOf(indexSize)-1:0];
        let tag = combined[valueOf(tagSize)+valueOf(indexSize)-1:valueOf(indexSize)] ^ truncate(pack(pc));
        return tuple2(tag, index);
    endfunction

    for(Integer i = 0; i < valueOf(SupSize); i = i+1) begin
        taggedTableReadIfc[i] = (interface TaggedTableRead#(tagSize, indexSize);
            method ActionValue#(Tuple2#(Bit#(`MAX_TAGGED), Bit#(`MAX_INDEX_SIZE))) lookupStart(Addr pc);
                match {.tag, .index} = getHistory(BEFORE_RECOVERY, pc, tagged Valid fromInteger(i));
                entryTabs[i].rdReq(index);
                usefulTabs[i].rdReq(index);
                return tuple2(zeroExtend(tag), zeroExtend(index));
            endmethod

            method WrappedEntry read;
                Maybe#(WrappedEntry) readVal = tagged Invalid;
                let respEntry = entryTabs[i].rdResp;
                let respUseful = usefulTabs[i].rdResp;
                TaggedTableEntry#(`MAX_TAGGED) ret = TaggedTableEntry{tag: zeroExtend(respEntry.tag), predictionCounter: respEntry.predictionCounter, usefulCounter: respUseful};
                return ret;
            endmethod
        endinterface);
    end
    interface taggedTableRead = taggedTableReadIfc;

    method Action updateEntry(Bit#(`MAX_INDEX_SIZE) index, TaggedTableEntry#(`MAX_TAGGED) currentEntry, Bool taken, UsefulCtrUpdate usefulUpdate);        
        TaggedTableEntry#(`MAX_TAGGED) newEntry = currentEntry;
        let ind = truncate(index);
        // Update prediction and useful counter
        newEntry.predictionCounter = boundedUpdate(currentEntry.predictionCounter, taken);
        if (usefulUpdate != PRESERVE) begin
            newEntry.usefulCounter = boundedUpdate(currentEntry.usefulCounter, usefulUpdate == INCREMENT);
        end

        for(Integer i = 0; i < valueOf(SupSize); i = i + 1) begin
            entryTabs[i].wrReq(ind, InternalTaggedEntry{tag: truncate(newEntry.tag), predictionCounter: newEntry.predictionCounter});
            usefulTabs[i].wrReq(ind, newEntry.usefulCounter);
        end
    endmethod

    // 3 bits 100 011
    method Action allocateEntry(Bit#(indexSize) index, Bit#(tagSize) tag, Bool taken);
        Bit#(PredCtrSz) counter_init = 1 << (valueOf(PredCtrSz)-1);
        if (!taken) begin
            counter_init = (1 << (valueOf(PredCtrSz)-1))-1;
        end
        
        InternalTaggedEntry#(tagSize) toWrite = InternalTaggedEntry{predictionCounter: counter_init, tag: tag};

        for(Integer i = 0; i < valueOf(SupSize); i = i + 1) begin
            entryTabs[i].wrReq(index, toWrite);
            usefulTabs[i].wrReq(index, 0);
        end
    endmethod

    method Action decrementUsefulCounter(Bit#(indexSize) index, UsefulCtr usefulCounter);
        let newUsefulCounter = boundedUpdate(usefulCounter, False);
        for(Integer i = 0; i < valueOf(SupSize); i = i + 1) begin
            usefulTabs[i].wrReq(index, newUsefulCounter);
        end
    endmethod
    
    // ----------------- DEBUG
    `ifdef DEBUG
    method TaggedTableEntry#(tagSize) debugGetEntry(Bit#(indexSize) index);
        return tab.sub(index);
    endmethod

    method Action debugUnsetEntry(Addr pc);
        match {.tag, .index} = getHistory(AFTER_RECOVERY, pc, tagged Invalid);
        tab.upd(index, TaggedTableEntry{tag: 0, predictionCounter:0, usefulCounter:0});
    endmethod
    `endif

    `ifdef DEBUG_TAGETEST
        method Bit#(TAdd#(tagSize, indexSize)) debugGetHistory(HistoryRetrieve hr, Maybe#(Bit#(TLog#(SupSize))) count);
            Bit#(TAdd#(tagSize, indexSize)) hist = 0;
            if(hr == AFTER_RECOVERY)
                hist = folded.recoveredHistory;
            else if(hr == BEFORE_RECOVERY)
                if(count matches tagged Valid .num)
                    hist = folded.sameWindowHistory[num].history;
                else
                    hist = folded.history;
            return hist;
        endmethod
    `endif
    
    
    
    // ----------------- DEBUG



    method Action updateHistory(Bit#(SupSize) results, SupCnt count) = folded.updateHistory(results, count);
    method Action updateRecovered(Bit#(1) taken) = folded.updateRecoveredHistory(taken);
    method Action recoverHistory(Bit#(TLog#(MaxSpecSize)) numRecovery);
        //sameCycleRecovery.send;
        folded.recoverFrom[numRecovery].undo;
    endmethod

  
    method Tuple2#(Bit#(tagSize), Bit#(indexSize)) trainingInfo(Addr pc, HistoryRetrieve recovered); // To be used in training
        return getHistory(recovered, pc, tagged Invalid);
    endmethod

endmodule