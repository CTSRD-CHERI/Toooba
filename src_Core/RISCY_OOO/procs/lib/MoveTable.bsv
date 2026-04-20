import Vector::*;
import ProcTypes::*;
import Ehr::*;
import Types::*;

interface Commit;
    method Bool contains(PhyRIndx phy);
    // remove is left unguarded, but we do do not expect to call it 
    // when phy is not in table, and assume that it suceeds
    method Action remove(PhyRIndx phy);
    method ActionValue#(PhyRIndx) takeFreeReg; // take from auxiliary free list
endinterface

interface Rename;
    method Bool canAdd; // guard of add
    method Action add(PhyRIndx phy);
    method Action freeReg(PhyRIndx phy); // add to auxiliary free list
endinterface

interface MoveTable;
    // used to record source phy regs so we know to free/not free
    // MoveTable is functionally a multiset with limited capacity
    // we expose add, remove, and contains methods, pre-rename uses
    // first SupSize ports on commit interface, commit uses latter
    interface Vector#(TAdd#(SupSize, SupSize), Commit) commit; // commit and pre-rename port
    interface Vector#(SupSize, Rename) rename; // rename port
endinterface

module mkMoveTable(MoveTable) provisos ( 
    NumAlias#(moveTableSize, 7),
    NumAlias#(removeLanes, TAdd#(SupSize, SupSize)),
    Alias#(slotIndexT, Bit#(TLog#(moveTableSize))),
    Alias#(slotCountT, Bit#(TLog#(TAdd#(1, moveTableSize))))
);

    // ordering: pre-rename < commit < rename
    // rename need not see the freed slots from commit or pre-rename

    Vector#(moveTableSize, Reg#(PhyRIndx)) moveSources <- replicateM(mkRegU);
    Vector#(moveTableSize, Reg#(Bool)) valid <- replicateM(mkReg(False));
    Reg#(slotCountT) numFreeSlots <- mkReg(fromInteger(valueof(moveTableSize)));

    // aux free list
    Vector#(moveTableSize, Reg#(PhyRIndx)) auxFreeList <- replicateM(mkRegU);
    Reg#(slotIndexT) auxEnq <- mkReg(0);
    Reg#(slotIndexT) auxDeq <- mkReg(0);

    // wires for recording actions
    Vector#(removeLanes, RWire#(PhyRIndx)) removeEn <- replicateM(mkUnsafeRWire);
    Vector#(SupSize, RWire#(PhyRIndx)) addEn <- replicateM(mkUnsafeRWire);
    Vector#(removeLanes, PulseWire) takeFreeRegEn <- replicateM(mkUnsafePulseWire);
    Vector#(SupSize, RWire#(PhyRIndx)) freeRegEn <- replicateM(mkUnsafeRWire);

    (* fire_when_enabled, no_implicit_conditions *)
    rule updateNumFreeSlots;
        slotCountT numRemoves = 0;
        slotCountT numAdds = 0;
        for(Integer i = 0; i < valueof(SupSize); i = i+1) begin 
            if(addEn[i].wget() matches tagged Valid .*) begin 
                numAdds = numAdds + 1;
            end
        end
        for(Integer i = 0; i < valueof(removeLanes); i = i+1) begin 
            if(removeEn[i].wget() matches tagged Valid .*) begin 
                numRemoves = numRemoves + 1;
            end
        end
        numFreeSlots <= numFreeSlots + numRemoves - numAdds;
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule applyAdd;
        Vector#(moveTableSize, Bool) slotUsed = replicate(False);
        for(Integer i = 0; i < valueof(SupSize); i = i+1) begin 
            if(addEn[i].wget() matches tagged Valid .phy) begin 
                Bool addComplete = False;
                for(Integer j = 0; j < valueof(moveTableSize); j = j+1) begin 
                    if(!addComplete && !slotUsed[j] && !valid[j]) begin 
                        addComplete = True;
                        slotUsed[j] = True;
                        valid[j] <= False;
                        moveSources[j] <= phy;
                    end
                end
                // sanity check
                doAssert(addComplete, "free slot must exist in order to add to move table");
            end
        end
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule applyRemove;
        Vector#(moveTableSize, Bool) removed = replicate(False);
        for(Integer i = 0; i < valueof(removeLanes); i = i+1) begin 
            if(removeEn[i].wget() matches tagged Valid .phy) begin 
                Bool removeComplete = False;
                for(Integer j = 0; j < valueof(moveTableSize); j = j+1) begin 
                    if(!removeComplete && !removed[j] && valid[j] && moveSources[j] == phy) begin 
                        removeComplete = True;
                        removed[j] = True;
                        valid[j] <= False;
                    end
                end
                // sanity check
                doAssert(removeComplete, "phy reg must exist in move table to be removed");
            end
        end
    endrule

    function incrementIndex(slotIndexT index);
        slotIndexT newIndex;
        if(index == fromInteger(valueof(moveTableSize) - 1)) begin 
            newIndex = 0;
        end else begin 
            newIndex = index + 1;
        end
        return newIndex;
    endfunction

    (* fire_when_enabled, no_implicit_conditions *)
    rule updateAuxFreeList;
        slotIndexT newEnq = auxEnq;
        slotIndexT newDeq = auxDeq;

        // add new registers to aux free list and update enqueue pointer
        for(Integer i = 0; i < valueof(SupSize); i = i + 1) begin 
            if(freeRegEn[i].wget() matches tagged Valid .phy) begin 
                auxFreeList[newEnq] <= phy;
                newEnq = incrementIndex(newEnq);
            end
        end
        auxEnq <= newEnq;

        // move dequeue pointer (removes registers from free list, no need to update list)
        Bool emptied = (auxEnq == auxDeq); // for sanity check
        for(Integer i = 0; i < valueof(removeLanes); i = i+1) begin 
            if(takeFreeRegEn[i]) begin 
                newDeq = incrementIndex(newDeq);
                // sanity check
                doAssert(!emptied, "must not remove registers from empty aux free list");
                emptied = (auxEnq == newDeq);
            end
        end
        auxDeq <= newDeq;
    endrule 

    function Bool isPhyContained(Integer lane, PhyRIndx phy);
        slotCountT numPriorRemoves = 0;
        slotCountT numOccurances = 0;
        for(Integer i = 0; i < valueof(removeLanes); i = i+1) begin 
            if(i < lane && removeEn[i].wget() == Valid(phy)) begin 
                numPriorRemoves = numPriorRemoves + 1;
            end
        end
        for(Integer i = 0; i < valueof(moveTableSize); i = i+1) begin 
            if(valid[i] && moveSources[i] == phy) begin 
                numOccurances = numOccurances + 1;
            end
        end
        return !(numPriorRemoves == numOccurances);
    endfunction

    function PhyRIndx getFreeReg(Integer lane);
        Integer numPriorFrees = 0;
        for(Integer i = 0; i < valueof(removeLanes); i = i+1) begin 
            if(i < lane && takeFreeRegEn[i]) begin 
                numPriorFrees = numPriorFrees + 1;
            end
        end
        return auxFreeList[auxDeq + fromInteger(numPriorFrees)];
    endfunction

    Vector#(removeLanes, Commit) commitIfc;
    for(Integer i = 0; i < valueof(removeLanes); i = i+1) begin 
        commitIfc[i] = (interface Commit;
            method Bool contains(PhyRIndx phy);
                return isPhyContained(i, phy);
            endmethod

            // unguarded, we assume it succeeds
            method Action remove(PhyRIndx phy);
                removeEn[i].wset(phy);
            endmethod

            method ActionValue#(PhyRIndx) takeFreeReg();
                takeFreeRegEn[i].send();
                return getFreeReg(i);
            endmethod
        endinterface);
    end

    function Bool isSlotAvailable(Integer lane);
        slotCountT numPriorAdds = 0;
        for(Integer i = 0; i < valueof(SupSize); i = i+1) begin 
            if(i < lane) begin
                if(addEn[i].wget() matches tagged Valid .*) begin 
                    numPriorAdds = numPriorAdds + 1;
                end
            end
        end
        return !(numPriorAdds == numFreeSlots);
    endfunction

    Vector#(SupSize, Rename) renameIfc;
    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin 
        Bool addGuard = isSlotAvailable(i);
        renameIfc[i] = (interface Rename;
            method canAdd = addGuard;

            method Action add(PhyRIndx phy) if(addGuard);
                addEn[i].wset(phy);
            endmethod

            method Action freeReg(PhyRIndx phy);
                freeRegEn[i].wset(phy);
            endmethod
        endinterface);
    end

    interface commit = commitIfc;
    interface rename = renameIfc;
endmodule