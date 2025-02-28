import RegFile::*;
import LFSR::*;
import Vector::*;
import List::*;
import HList::*;
import DReg::*;

import ProcTypes::*;
import Types::*;
import BrPred::*;
import BranchParams::*;
import BimodalTable::*;
import TaggedTableBRAM::*;
import GlobalBranchHistory::*;
import Ehr::*;
import Util::*;
import CircBuff::*;
import Fifos::*;

// For debugging
import Cur_Cycle :: *;
/*
export DirPredTrainInfo(..);
export TageTrainInfo(..);
export Addr;
export Entry;
export PCIndex;
export PCIndexSz;
export Tage;
export mkTage;
*/

// Not a reasonable solution


`define WRAP_CODE(body) \
    action /* body */ endaction

`define WRAP_CODE_NON_ACTION(body) \
    /* body */

`define CASE_ALL_TABLES(varName, body) \
    case (varName) matches \
    tagged T_9_9_5 .t : begin  \
        `WRAP_CODE_NON_ACTION(body) \
    end \
    tagged T_9_9_9 .t : begin \
        `WRAP_CODE_NON_ACTION(body) \
    end \
    tagged T_9_10_15 .t : begin \
        `WRAP_CODE_NON_ACTION(body) \
    end \
    tagged T_9_10_25 .t : begin \
        `WRAP_CODE_NON_ACTION(body) \
    end \
    tagged T_9_11_44 .t : begin \
        `WRAP_CODE_NON_ACTION(body) \
    end \
    tagged T_9_11_76 .t : begin \
        `WRAP_CODE_NON_ACTION(body) \
    end \
    tagged T_9_12_130 .t : begin \
        `WRAP_CODE_NON_ACTION(body) \
    end \
    endcase \

// Macro or type definition?
`define MAX_TAGGED 12
`define MAX_INDEX_SIZE 10
`define METAPREDICTOR_CTR_SIZE 4 //ALT_ON_NA

typedef 12 PCIndexSz;
typedef Bit#(PCIndexSz) PCIndex;

typedef 13 BimodalPredSz;
typedef 11 BimodalHystSz;

typedef Bit#(2) Entry;
typedef Bit#(TLog#(numTables)) TableIndex#(numeric type numTables);

typedef Tuple2#(Maybe#(Tuple3#(Bit#(TLog#(num)), TaggedTableEntry#(`MAX_TAGGED), Bit#(`MAX_INDEX_SIZE))), Maybe#(Tuple2#(Bit#(TLog#(num)), TaggedTableEntry#(`MAX_TAGGED)))) PredictionTableInfo#(numeric type num);

typedef struct {
    Bit#(TLog#(numTables)) provider_table;
    Bit#(`MAX_INDEX_SIZE) index;
    TaggedTableEntry#(`MAX_TAGGED) provider_entry;
} ProviderTrainInfo#(numeric type numTables) deriving (Eq, FShow, Bits);

typedef struct{
    Bool use_alt;
    Bool provider_prediction; // prediction of the provider
    Bool alt_prediction; // prediction of the alternative table
    Bool taken; // Outcome
    BimodalTableEntry bimodal_prediction; //Also need index 

    // Not a fan, also could be improved with a table
    Vector#(numTables, Bit#(`MAX_INDEX_SIZE)) indices; //These two are necessary for allocate (avoid need for history)
    Vector#(numTables, Bit#(`MAX_TAGGED)) tags;
    Vector#(numTables, UsefulCtr) usefulCounters; // Add 14 bits


    Maybe#(ProviderTrainInfo#(numTables)) provider_info;
    Maybe#(Bit#(TLog#(numTables))) alt_table;
    // Redundancy, can easily be checked with taken and provider but not efficient?

    Bit#(numTables) replaceableEntries;

    // May not be necessary
    Addr pc;
    Bool confirmed;
} TageTrainInfo#(numeric type numTables) deriving(Bits, Eq, FShow);

//
typedef struct {
    BimodalTableEntry counter;
} TageFastTrainInfo deriving(Bits, Eq, FShow);

typedef struct {
    Bool confirmed;    
    CircBuffIndex#(MaxSpecSize) ooIndex;
} TageSpecInfo deriving(Bits, Eq, FShow);

typedef struct {
    TageTrainInfo#(numTables) tageInfo;
    Bool mispred;
    Bool taken;
} UpdateInfo#(numeric type numTables) deriving(Bits, Eq, FShow);

typedef struct {
    TageSpecInfo specInfo;
    Bool taken;
    Bool nonBranch;
} SpecUpdateInfo deriving(Bits, Eq, FShow);

typedef struct {
    TageTrainInfo#(numTables) train;
    PredictionTableInfo#(numTables) predInfo;
    Addr pc; // Only for debugging
    Bool alt_use;
} Pred2ToPred3#(numeric type numTables) deriving(Bits, Eq, FShow);

typedef struct {
    GuardedResult#(Tuple2#(TageTrainInfo#(numTables), Addr)) res;
} Pred1ToPred2Data#(numeric type numTables) deriving(Bits, Eq, FShow);

typedef GuardedResult#(Pred2ToPred3#(numTables)) Pred2ToPred3Data#(numeric type numTables);

// Abolutely terrible, is there an easier way to parametrise this?
typedef union tagged {
    TaggedTableBRAM#(9,9,5) T_9_9_5;
    TaggedTableBRAM#(9,9,9) T_9_9_9;
    TaggedTableBRAM#(9,10,15) T_9_10_15;
    TaggedTableBRAM#(9,10,25) T_9_10_25;
    TaggedTableBRAM#(9,11,44) T_9_11_44;
    TaggedTableBRAM#(9,11,76) T_9_11_76;
    TaggedTableBRAM#(9,12, 130) T_9_12_130;
} ChosenTaggedTables deriving(Bits);

typedef union tagged {
    TaggedTableEntry#(9) Tag9;
    TaggedTableEntry#(10) Tag10;
    TaggedTableEntry#(11) Tag11;
    TaggedTableEntry#(12) Tag12;
} TaggedEntrySizes deriving(Bits);

interface Tage#(numeric type numTables);
    interface DirPredictor#(TageTrainInfo#(numTables), TageSpecInfo, TageFastTrainInfo) dirPredInterface;
    
    `ifdef DEBUG
        method Action debugTables(Addr pc);
        method ActionValue#(Maybe#(TableIndex#(numTables))) debugMispredictAllocation(TageTrainInfo#(numTables) train, Bool taken);
        method Action debugAllocate(Addr pc, Bit#(TLog#(numTables)) tableNum);
        method Action debugResetEntry(Addr pc, Bit#(TLog#(numTables)) tableNum);
        method TaggedTableEntry#(`MAX_TAGGED) debugGetEntry(Addr pc, Bit#(TLog#(numTables)) tableNum);
        method PredictionTableInfo#(numTables) debugPredAltpred;
    `endif
endinterface

/*
    Recover spec more urgent than update history - should be fine

*/
module mkTage(Tage#(numTables)) provisos(
    Bits#(TageTrainInfo#(numTables), a__),
    Add#(1, b__, TLog#(TAdd#(1, numTables))),
    Add#(c__, numTables, 20)
);
    GlobalBranchHistory#(GlobalHistoryLength) global <- mkGlobalBranchHistory;

    TaggedTableBRAM#(9,9,5)     t1 <- mkTaggedTableBRAM(global);
    TaggedTableBRAM#(9,9,9)     t2 <- mkTaggedTableBRAM(global);
    TaggedTableBRAM#(9,10,15)   t3 <- mkTaggedTableBRAM(global);
    TaggedTableBRAM#(9,10,25)   t4 <- mkTaggedTableBRAM(global);
    TaggedTableBRAM#(9,11,44)   t5 <- mkTaggedTableBRAM(global);
    TaggedTableBRAM#(9,11,76)   t6 <- mkTaggedTableBRAM(global);
    TaggedTableBRAM#(9,12,130)  t7 <- mkTaggedTableBRAM(global);

    BimodalTable#(BimodalPredSz, BimodalHystSz) bimodalTable <- mkBimodalTable(regInitFilenameBimodalPred, regInitFilenameBimodalHyst);
    Vector#(7, ChosenTaggedTables) taggedTablesVector = cons(T_9_9_5(t1), cons(T_9_9_9(t2), cons(T_9_10_15(t3), cons(T_9_10_25(t4), cons(T_9_11_44(t5), cons(T_9_11_76(t6), cons(T_9_12_130(t7), nil)))))));
    Reg#(UInt#(`METAPREDICTOR_CTR_SIZE)) alt_on_na <- mkReg(1 << (`METAPREDICTOR_CTR_SIZE-1));
    CircBuff#(MaxSpecSize, Bool) ooBuff <- mkCircBuff;

    Ehr#(TAdd#(1, SupSize), SupCnt) numPred <- mkEhr(0);
    Ehr#(TAdd#(1, SupSize), Bit#(SupSize)) predResults <- mkEhr(0);

    // For the LFSR
    LFSR#(Bit#(4)) lfsr <- mkLFSR_4;
    Reg#(Bool) starting <- mkReg(True);

    Vector#(SupSize, RWire#(PredIn#(TageFastTrainInfo))) predIn <- replicateM(mkRWire);
    // Could be DREGs
    Vector#(SupSize, Reg#(Maybe#(Pred1ToPred2Data#(numTables)))) pred1ToPred2 <- replicateM(mkDReg(tagged Invalid));
    Vector#(SupSize, Reg#(Maybe#(Pred2ToPred3Data#(numTables)))) pred2ToPred3 <- replicateM(mkDReg(tagged Invalid));
    
    Vector#(SupSize, RWire#(GuardedResult#(DirPredResult#(TageTrainInfo#(numTables))))) bypassPred <- replicateM(mkRWire);
    
    SupFifo#(SupSize, 6, GuardedResult#(DirPredResult#(TageTrainInfo#(numTables)))) resultFifo <- mkUGSupFifo; // Check size
    Ehr#(TAdd#(SupSize,1), SupCnt) bypassedCount <- mkEhr(0);
    //Vector#(SupSize, PulseWire) usedPred <- replicateM(mkUnsafePulseWireOR);
    Ehr#(TAdd#(SupSize,1), Bit#(SupSize)) enqMask <- mkEhr(0);// Can't use a pulse wire :( scheduling conflict in same rule,   usedPred[bypassCount[i]].send
    Ehr#(TAdd#(SupSize,1), Bit#(TLog#(SupSize))) currentPred <- mkEhr(0);

    PulseWire recovered <- mkPulseWireOR;
    RWire#(SpecUpdateInfo) specInfoUpdate <- mkRWire;
  
    function Bool useAlt;
        return unpack(pack(alt_on_na)[`METAPREDICTOR_CTR_SIZE-1]);
    endfunction

    function Tuple2#(Vector#(numTables,Maybe#(Bit#(TLog#(numTables)))), Vector#(numTables,Maybe#(Bit#(TLog#(numTables))))) treeFindPred(Integer len, Integer depth, Vector#(numTables,Maybe#(Bit#(TLog#(numTables)))) entries_compare, Vector#(numTables,Maybe#(Bit#(TLog#(numTables)))) altpred_compare);
        
        if (depth == 0) return tuple2(entries_compare, altpred_compare);
        else begin
            Vector#(numTables,Maybe#(Bit#(TLog#(numTables)))) pred = replicate(tagged Invalid);
            Vector#(numTables,Maybe#(Bit#(TLog#(numTables)))) altpred = replicate(tagged Invalid);

                // Is this compile time or is it forced to be sequential???
            for (Integer j = 0; j < 2*(len/2); j = j + 2) begin
                if (entries_compare[j+1] matches tagged Valid .x) begin
                    if(altpred_compare[j+1] matches tagged Valid .x)
                        altpred[j / 2] = altpred_compare[j+1];
                    else
                        altpred[j / 2] = entries_compare[j];  
                    pred[j / 2] = entries_compare[j+1];
                    
                end
                else begin
                    pred[j / 2] = entries_compare[j];
                    altpred[j / 2] = altpred_compare[j];
                end
            end
            if (len % 2 == 1) begin
                pred[(len/2)] = entries_compare[len-1];
                altpred[(len/2)] = tagged Invalid;
            end
            Integer len2 = (len / 2) + (len % 2);
        return treeFindPred(len2, depth - 1, pred, altpred);
        end
    endfunction

    function Tuple3#(PredictionTableInfo#(numTables), Bit#(numTables), Vector#(numTables, UsefulCtr)) find_pred_altpred(Addr pc, Bit#(TLog#(SupSize)) numPred, TageTrainInfo#(numTables) train);
        Vector#(numTables,Maybe#(Bit#(TLog#(numTables)))) entries_compare = replicate(tagged Invalid);
        Vector#(numTables,Maybe#(Bit#(TLog#(numTables)))) altpred_compare = replicate(tagged Invalid);
        Vector#(numTables,UsefulCtr) usefulCounters = replicate(0);
        Bit#(numTables) replaceableEntries = 0;
        
        Vector#(numTables,TaggedTableEntry#(`MAX_TAGGED)) entries = replicate(TaggedTableEntry{tag:0, predictionCounter:0, usefulCounter:0});
        let indices = train.indices;
        let tags = train.tags;
        
        for(Integer j = 0; j < valueOf(numTables); j=j+1) begin
            ChosenTaggedTables tab = taggedTablesVector[j];    
            `CASE_ALL_TABLES(tab, 
            (*/
                // Could do this in one
                let entry = t.taggedTableRead[numPred].read;
                replaceableEntries[j] = pack(entry.usefulCounter == 0);
                usefulCounters[j] = entry.usefulCounter;

                entries[j] = entry;
                if (tags[j] == entry.tag) begin
                    entries_compare[j] = tagged Valid fromInteger(j);
                end
                /*)
            )
        end
        
        Integer len = valueOf(numTables);
        match{.pred_vec, .altpred_vec} = treeFindPred(len, valueOf(TLog#(numTables)), entries_compare, altpred_compare);

        PredictionTableInfo#(numTables) ret = tuple2(tagged Invalid, tagged Invalid);
        
        // formout output
        if (pred_vec[0] matches tagged Valid .x)
            if (altpred_vec[0] matches tagged Valid .y)
                ret = tuple2(tagged Valid tuple3(x, entries[x], indices[x]), tagged Valid tuple2(y, entries[y]));
            else
                ret = tuple2(tagged Valid tuple3(x, entries[x], indices[x]), tagged Invalid);
        
        return tuple3(ret, replaceableEntries, usefulCounters);
    endfunction

    // WARNING - REMOVE ACTIONVALUE AFTER DEBUG
    function Action allocate(TageTrainInfo#(numTables) train, Bool taken);
        action
        Maybe#(TableIndex#(numTables)) ret = tagged Invalid;
        
        if(train.provider_info matches tagged Valid .inf &&& inf.provider_table == fromInteger(valueOf(numTables)-1)) begin
            `ifdef DEBUG_TAGETEST
                $display("Do Nothing\n");
            `endif
        end
        else begin
            // Do this on prediction as we access all tables then anyway (?)
            Bit#(TLog#(numTables)) start = 0;
            if(train.provider_info matches tagged Valid .inf) begin
                // Is this too expensive? Is there a better way to implement the circuit than adding?
                start = inf.provider_table+1; // Could use a mask for start instead?
            end

            // Remove all entries before the starting table we are considering
            Bit#(numTables) tabsReplaceable = (train.replaceableEntries >> start) << start;
            if(tabsReplaceable == 0) begin
                // Decrement all counters as in original TAGE, worried about the circuitry there
                `ifdef DEBUG_TAGETEST
                    $display("TAGETEST DECREMENT ENTRIES FOR %x %b %d\n",train.pc, train.replaceableEntries, start);
                `endif
                for(Integer i = 0; i < valueOf(numTables); i = i + 1) begin    
                    if  (fromInteger(i) >= start) begin
                        let tab = taggedTablesVector[i];
                        let index = train.indices[i];
                        `CASE_ALL_TABLES(tab, (*/ t.decrementUsefulCounter(truncate(index), train.usefulCounters[i]); /*))
                    end
                end
            end
            else begin
                // overkill?
                Bit#(TAdd#(numTables,1)) num = 1 << countOnes(tabsReplaceable);
                
                Bit#(3) randNum = {lfsr.value[2:1], lfsr.value[0] | lfsr.value[3]};
                Bool found = False;
                TableIndex#(numTables) ind = 0;
                
                `ifdef DEBUG
                $display(fshow(start), " Rand:", fshow(randNum),  " Number to choose:", fshow(num), "\n");
                $display("%b\n",train.replaceableEntries);
                $display("%b\n",tabsReplaceable);
                `endif

                // A better way than sequential?
                for(Integer i = 0; i < valueOf(numTables); i = i + 1) begin
                    if(unpack(tabsReplaceable[i])) begin
                        if(!found && (num == 'b10 || unpack(randNum[2]))) begin
                            ind = fromInteger(i);
                            found = True;
                        end
                        randNum = randNum << 1;
                        num = num >> 1;
                    end
                end

                `ifdef DEBUG_TAGETEST
                    Bit#(20) index = 0;
                    Bit#(`MAX_TAGGED) tag = 0;
                    let tab = taggedTablesVector[ind];
                    //`CASE_ALL_TABLES(tab, (*/ index = zeroExtend(tpl_2(t.trainingInfo(train.pc, AFTER_RECOVERY))); tag = zeroExtend(tpl_1(t.trainingInfo(train.pc, AFTER_RECOVERY))); /*))
                    $display("TAGETEST ALLOCATE FOR %x %d %d %d\n",train.pc, ind, train.indices[ind], train.tags[ind]);
                `endif

                `CASE_ALL_TABLES(taggedTablesVector[ind], (*/ t.allocateEntry(truncate(train.indices[ind]), truncate(train.tags[ind]), taken); /*))
            end
        end
    endaction
    endfunction

    function Action updateWithTrain(Bool taken, TageTrainInfo#(numTables) train, Bool mispred);
        action
        // Update bimodal table either way
        bimodalTable.updateEntry(train.pc, taken);
        Bool mispredict = taken != train.taken;

        // Tagged tables update
        if(train.provider_info matches tagged Valid .info) begin
            let entry = info.provider_entry;
            // Useful counters
            UsefulCtrUpdate u = PRESERVE;
            if(train.provider_prediction == taken && train.alt_prediction != taken)
                u = INCREMENT;
            else if(train.provider_prediction != taken && train.alt_prediction == taken)
                u = DECREMENT;

            ChosenTaggedTables providerTable = taggedTablesVector[info.provider_table];
            `CASE_ALL_TABLES(providerTable, (*/ t.updateEntry(info.index, entry, taken, u); /*))

            // ALT_ON_NA
            `ifdef DEBUG_TAGETEST
                if(train.alt_table matches tagged Valid .alt_t) begin
                $display("TAGETEST UPDATE ALT PRED TABLE %d\n", alt_t);
                end
                else
                    $display("TAGETEST UPDATE ALT PRED BIMODAL\n");
                $display("TAGETEST UPDATE ALT PRED TAKEN %d\n", train.alt_prediction);
                $display("TAGETEST PROVIDR ENTRY COUNTER %d\n", entry.predictionCounter);
                $display("TAGETEST PROVIDR ENTRY USEFUL %d\n", entry.usefulCounter);
            `endif

            if(entry.usefulCounter == 0 && weakCounter(entry.predictionCounter)) begin
                if(train.alt_prediction != train.provider_prediction)
                    alt_on_na <= unpack(boundedUpdate(pack(alt_on_na), train.alt_prediction == taken));
            end
        end

        // Update LSFR
        `ifdef GOLD_STANDARD
            lfsr.next;
        `endif
    endaction
    endfunction

    
    //rule updateHistory(!mispredictWire); NOT SURE ABOUT THIS -------------------------------------
    
    (* no_implicit_conditions, fire_when_enabled *)
    rule updateHistory(!recovered);
        //if(!mispredictWire) begin
        // Update history speculatively
            let num = numPred[valueOf(SupSize)];
            let results = predResults[valueOf(SupSize)];
            //ooBuff.specAssignConfirmed(num);

            if(num != 0) begin
                `ifdef DEBUG_TAGETEST   
                $display("TAGETEST Update history, cycle %d\n", cur_cycle);
                $display("TAGETEST Global %b\n", global.history);
                `endif

                global.addHistoryBits(results, num);
                for(Integer i = 0; i < valueOf(numTables); i = i+1) begin
                    let tab = taggedTablesVector[i];
                    `CASE_ALL_TABLES(tab, (*/ t.updateHistory(results, num); /*))
                end
            end
      //  end
    endrule

    (* no_implicit_conditions, fire_when_enabled *)
    rule recoverSpecHistory(recovered &&& specInfoUpdate.wget matches tagged Valid .specUpdate);
        let numBits <- ooBuff.handleMispred(specUpdate.specInfo.ooIndex, !specUpdate.nonBranch);
        if(!(specUpdate.nonBranch && numBits == 0)) begin
            if(specUpdate.nonBranch)
                numBits = numBits - 1;
            // Recover histories first, then update bit
            let recoverNumber = numBits;
            global.recoverFrom[recoverNumber].undo;

            if(!specUpdate.nonBranch)
                global.updateRecoveredHistory(pack(specUpdate.taken));

            `ifdef DEBUG_TAGETEST   
                $display("TAGETEST Recovery by %d Misprediction on %d, cycle %d %d\n", numBits, specUpdate.specInfo.ooIndex, cur_cycle, specUpdate.nonBranch);
            `endif
            for (Integer i = 0; i < valueOf(numTables); i = i +1) begin
                let tab = taggedTablesVector[i];
                `CASE_ALL_TABLES(tab, (*/ 
                t.recoverHistory(recoverNumber); 
                if(!specUpdate.nonBranch)
                    t.updateRecovered(pack(specUpdate.taken)); /*))
            end 
        end
    endrule

    (* no_implicit_conditions, fire_when_enabled *)
    rule canonUpdate;
        //Update LFSR
        if(starting) begin
            lfsr.seed('d9);
            starting <= False;
        end
        else begin
            `ifndef GOLD_STANDARD
                lfsr.next;
            `endif

            numPred[valueOf(SupSize)] <= 0;
            predResults[valueOf(SupSize)] <= 0;
            bypassedCount[valueof(SupSize)] <= 0;
            enqMask[valueOf(SupSize)] <= 0;
            currentPred[valueOf(SupSize)] <= 0;
        end
    endrule

    for (Integer i = 0; i < valueOf(SupSize); i = i + 1) begin
        (* no_implicit_conditions, fire_when_enabled *)
        rule predStageOne(predIn[i].wget matches tagged Valid .in);
            Vector#(numTables,Bit#(`MAX_INDEX_SIZE)) indices = replicate(0);
            Vector#(numTables,Bit#(`MAX_TAGGED)) tags = replicate(0);

            for(Integer j = 0; j < valueOf(numTables); j = j + 1) begin
                let tab = taggedTablesVector[j];
                `CASE_ALL_TABLES(tab, (*/
                    match {.tag, .index} <- t.taggedTableRead[i].lookupStart(in.pc);
                    indices[j] = index;
                    tags[j] = tag;
                /*)
                )
            end
            
            `ifdef DEBUG_TAGETEST
            $display("TAGETEST Pred1 on %x\n", in.pc);
            `endif

            TageTrainInfo#(numTables) ret = unpack(0);
            
            Addr pc = in.pc;
            ret.pc = pc;
            ret.indices = indices;
            ret.tags = tags;
            ret.confirmed = True;
            ret.bimodal_prediction = in.fastTrainInfo.train.counter;

            numPred[i] <= numPred[i] + 1;
            let results = predResults[i];
            results[numPred[i]] = pack(in.fastTrainInfo.taken);
            predResults[i] <= results;
                
            //let spec <- ooBuff.specAssign[i].specAssign; // Need action, but fragment should have corresponding original index
            pred1ToPred2[i] <= tagged Valid Pred1ToPred2Data{
                res: GuardedResult{
                    result: tuple2(ret, in.pc), //Passing of the PC is all for debugging
                    main_epoch: in.main_epoch,
                    decode_epoch: in.decode_epoch
                }
            };
        endrule
    end

    for (Integer i = 0; i < valueOf(SupSize); i = i + 1) begin
        (* no_implicit_conditions, fire_when_enabled *)
        rule predStageTwo(pred1ToPred2[i] matches tagged Valid .in);
            match {.ret, .pc} = in.res.result;
            
            `ifdef DEBUG_TAGETEST
            $display("TAGETEST Pred2 on %x\n", pc);
            `endif

            `ifdef DEBUG_TAGETEST
                $display("TAGETEST LFSR %d\n", lfsr.value);
                $display("TAGETEST ALT_ON_NA %d\n", alt_on_na);
            `endif

            // Retrieve provider and alternative table
            match {.predInfo, .replaceableEntries, .usefulCounters} = find_pred_altpred(ret.pc, fromInteger(i), ret);
            ret.replaceableEntries = replaceableEntries;
            ret.usefulCounters = usefulCounters;
                
            let result = GuardedResult {
                result: Pred2ToPred3{
                    train: ret,
                    predInfo: predInfo,
                    pc: pc,
                    alt_use: useAlt
                },
                main_epoch: in.res.main_epoch,
                decode_epoch: in.res.decode_epoch
            };

            pred2ToPred3[i] <= tagged Valid result;
        endrule      
    end

    for (Integer i = 0; i < valueOf(SupSize); i = i + 1) begin
        (* no_implicit_conditions, fire_when_enabled *)
        rule predStageThree(pred2ToPred3[i] matches tagged Valid .in);
            let entry = in;
            let result = entry.result;
            let ret = result.train;
            match {.predInfo, .altpred} = result.predInfo;
            if(predInfo matches tagged Valid {.pred_index, .pred_entry, .pred_table_index}) begin 
                Bool prediction = takenFromCounter(pred_entry.predictionCounter);
                ret.provider_prediction = prediction;

                `ifdef DEBUG_TAGETEST
                    $display("TAGETEST TABLE INDEX %d %d %d\n",pred_index, pred_table_index, pred_entry.tag);
                `endif
                
                // Get the index to avoid recomputing on update (not possible unless mispredict)
                ret.provider_info = tagged Valid ProviderTrainInfo{index: pred_table_index, provider_table: pred_index, provider_entry: pred_entry};
                if (altpred matches tagged Valid {.alt_index, .alt_entry}) begin
                    ret.alt_table = tagged Valid alt_index;

                    `ifdef DEBUG_TAGETEST
                    $display("TAGETEST ALT ENTRY %d tag:%d\n", alt_index, alt_entry.tag);
                    `endif
                    
                    Bool alt_prediction = takenFromCounter(alt_entry.predictionCounter);                 
                    ret.alt_prediction = alt_prediction;

                    if(pred_entry.usefulCounter == 0 && weakCounter(pred_entry.predictionCounter) && result.alt_use) begin
                        ret.taken = alt_prediction;
                        ret.use_alt = True;
                    end
                    else begin
                        ret.use_alt = False;
                        ret.taken = prediction;
                    end
                end
                else begin
                    ret.alt_table = tagged Invalid;
                    Bool bimodal_prediction = unpack(pack(ret.bimodal_prediction.pred));
                    ret.alt_prediction = bimodal_prediction;
                    ret.use_alt = False;
                    ret.taken = prediction;
                end
            end
            else begin
                `ifdef DEBUG_TAGETEST
                    $display("TAGETEST USE BIMODAL\n");
                `endif
                ret.alt_table = tagged Invalid;
                ret.provider_info = tagged Invalid;
                ret.use_alt = False;
                // Maybe automatically trigger a read from bimodal table ever time nextPc is set?
                Bool prediction = unpack(pack(ret.bimodal_prediction.pred));
                ret.provider_prediction = prediction;
                ret.taken = prediction;
            end

            `ifdef DEBUG_TAGETEST   
                $display("TAGETEST Prediction on: %x,%d, Taken: %d, cycle %d\n", ret.pc , i, ret.taken, cur_cycle);
            `endif

            let res =  GuardedResult{
                result: DirPredResult{
                    taken: ret.taken,
                    train: ret,
                    pc: result.pc
                },
                main_epoch: in.main_epoch,
                decode_epoch: in.decode_epoch
            };

            `ifdef DEBUG_TAGETEST
            $display("Pred3 on %x\n", result.pc);
            `endif
            
            bypassPred[i].wset(res);
        endrule      
    end

    
    (* no_implicit_conditions, fire_when_enabled *)
    rule enqWithoutBypass;
        SupCnt count = 0;
        Vector#(SupSize, Maybe#(GuardedResult#(DirPredResult#(TageTrainInfo#(numTables))))) toEnq = replicate(tagged Invalid);
        for (Integer i = 0; i < valueOf(SupSize); i = i + 1) begin
            if(bypassPred[i].wget matches tagged Valid .res &&& !unpack(enqMask[valueOf(SupSize)][i])) begin
                toEnq[count] = tagged Valid res;
                count = count + 1;
            end
        end

        for (Integer i = 0; i < valueOf(SupSize); i = i + 1) begin
            if(toEnq[i] matches tagged Valid .res) begin
                if(resultFifo.enqS[i].canEnq) begin
                    resultFifo.enqS[i].enq(res);
                    `ifdef DEBUG_TAGETEST
                    $display("TAGETEST Enqueued on %x, port %d\n", res.result.pc, i);
                    `endif
                end
                else
                    doAssert(False, "Cannot enqueue prediction");
            end
        end
    endrule      


    `ifdef DEBUG
    method Action debugTables(Addr pc);
        for(Integer i = 0; i < 7; i=i+1) begin
            ChosenTaggedTables tab = taggedTablesVector[i];
            `CASE_ALL_TABLES(tab, (*/match {.c, .d} = t.trainingInfo(pc, BEFORE_RECOVERY); $display("%d %d\n", c, d);/*))    
        end
    endmethod


    method PredictionTableInfo#(numTables) debugPredAltpred;
        return tpl_1(find_pred_altpred(currentPc));
    endmethod

    method Action debugAllocate(Addr pc, Bit#(TLog#(numTables)) tableNum);
        ChosenTaggedTables tab = taggedTablesVector[tableNum];
        //`CASE_ALL_TABLES(tab, (*/ t.allocateEntry(pc, True); /*))
    endmethod

    method Action debugResetEntry(Addr pc, Bit#(TLog#(numTables)) tableNum);
        ChosenTaggedTables tab = taggedTablesVector[tableNum];
        `CASE_ALL_TABLES(tab, (*/ t.debugUnsetEntry(pc); /*))
    endmethod

    method ActionValue#(Maybe#(TableIndex#(numTables))) debugMispredictAllocation(TageTrainInfo#(numTables) train, Bool taken);
        let ind <- allocateGivenEntry(train, taken);
        return ind;
    endmethod

    method TaggedTableEntry#(`MAX_TAGGED) debugGetEntry(Addr pc, Bit#(TLog#(numTables)) tableNum);
        ChosenTaggedTables tab = taggedTablesVector[tableNum];
        `CASE_ALL_TABLES(tab, (*/ return t.access_wrapped_entry(pc); /*))
    endmethod
    `endif
    
    Vector#(SupSize, DirPred#(TageTrainInfo#(numTables))) predIfc;
    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
        predIfc[i] = (interface DirPred;
            method ActionValue#(Maybe#(DirPredResult#(TageTrainInfo#(numTables)))) pred;
                DirPredResult#(TageTrainInfo#(numTables)) result = unpack(0);
                if(!resultFifo.deqS[currentPred[i]].canDeq) begin
                    if(bypassPred[bypassedCount[i]].wget matches tagged Valid .res) begin
                        result = res.result;
                        enqMask[i] <= enqMask[i] | (1 << bypassedCount[i]);
                        bypassedCount[i] <= bypassedCount[i]+1;
                    end
                    else begin
                        doAssert(False, "No prediction supplied when required\n");
                    end
                end
                else
                    result = resultFifo.deqS[currentPred[i]].first.result;
                
                currentPred[i] <= currentPred[i]+1;

                `ifdef DEBUG_TAGETEST
                $display("TAGETEST Pred called on %x, Taken: %d, Cycle:%d\n", result.pc, result.taken, cur_cycle);
                `endif

                return tagged Valid result;
            endmethod
        endinterface);
    end

    interface  dirPredInterface = interface DirPredictor#(TageTrainInfo#(numTables), TageSpecInfo);
        method Action update(Bool taken, TageTrainInfo#(numTables) train, Bool mispred);
            if(train.confirmed) begin
                (* split *)
                if(mispred) (* nosplit *) begin
                    // Retrieve allocation information for next update.
                    `ifdef DEBUG_TAGETEST
                    $display("TAGETEST Misprediction on %x, Actual: %d, Predicted:%d, cycle %d\n", train.pc, cur_cycle, taken, train.taken);
                    `endif
                    allocate(train, taken);
                    updateWithTrain(taken, train, mispred);
                end
                else (* nosplit *) begin
                    `ifdef DEBUG_TAGETEST
                    $display("TAGETEST correct prediction on %x, cycle %d\n", train.pc, cur_cycle);
                    `endif
                    updateWithTrain(taken, train, mispred);
                end
            end
        endmethod

        // Action value for flexibility, though I may not use it
        method ActionValue#(Vector#(SupSizeX2, FastPredictResult#(TageFastTrainInfo))) fastPred(Addr pc); // No training
            function FastPredictResult#(TageFastTrainInfo) bimodalPred(Addr pc, Integer i);
                let addr = pc + fromInteger(i*2);
                let pred = bimodalTable.accessPrediction(addr);
                return FastPredictResult{
                    taken: unpack(pack(pred.pred)),
                    train: TageFastTrainInfo{counter: pred}
                };
            endfunction
            
            return genWith(bimodalPred(pc));
        endmethod

        interface pred = predIfc;
        interface clearIfc = resultFifo.deqS;

        
        
        // Recover histories before table writes
        method Action specRecover(TageSpecInfo specInfo, Bool taken, Bool nonBranch);
            (* split *)
            if(specInfo.confirmed) begin
                recovered.send;
                specInfoUpdate.wset(SpecUpdateInfo{specInfo: specInfo, taken: taken, nonBranch: nonBranch});
            end
        endmethod

        method Vector#(SupSizeX2, TageSpecInfo) getSpec(Bit#(SupSizeX2) mask);
            let indices = ooBuff.specAssignUnconfirmed(mask);
            
            function TageSpecInfo form (Integer j);
                return TageSpecInfo{ooIndex: indices[j], confirmed: True};
            endfunction
            Vector#(SupSizeX2, TageSpecInfo) ret = genWith(form);
            return ret;
        endmethod

        method Action updateSpec(Bit#(TAdd#(TLog#(SupSizeX2),1)) i);
            ooBuff.specUpdate(i);
        endmethod

        /*
        method Bool stillUpdating;
            return decrementConflict;
        endmethod*/
    
        method Action nextPc(Vector#(SupSize,Maybe#(PredIn#(TageFastTrainInfo))) next);
            for(Integer i = 0; i < valueOf(SupSize); i = i + 1) begin
            if (next[i] matches tagged Valid .n)
                predIn[i].wset(n);
            end
        endmethod
    
        method Action flush = noAction;

        method flush_done = True;
    endinterface;
endmodule

/*
Functionality to check

- Remove CircBuff redundancy
*/