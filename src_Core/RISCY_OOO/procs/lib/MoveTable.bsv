import Vector::*;
import ProcTypes::*;
import Ehr::*;
import Types::*;

interface Commit;
    method Bool contains(PhyRIndx phy);
    // remove is left unguarded, but we do do not expect to call it 
    // when phy is not in table, and assume that it suceeds
    method Action remove(PhyRIndx phy);
endinterface

interface Rename;
    method Bool canAdd; // guard of add
    method Action add(PhyRIndx phy);
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
    Alias#(slotIndexT, Bit#(TLog#(TAdd#(1, moveTableSize)))),
    Alias#(slotCountT, Bit#(TLog#(TAdd#(1, moveTableSize))))
);

    // ordering: pre-rename < commit < rename
    // rename need not see the freed slots from commit or pre-rename

    Vector#(moveTableSize, Reg#(PhyRIndx)) moveSources <- replicateM(mkRegU);
    Vector#(moveTableSize, Reg#(Bool)) valid <- replicateM(mkReg(False));
    Reg#(slotCountT) numFreeSlots <- mkReg(fromInteger(valueof(moveTableSize)));

    // wires for recording actions
    Vector#(removeLanes, RWire#(PhyRIndx)) removeEn <- replicateM(mkUnsafeRWire);
    Vector#(SupSize, RWire#(PhyRIndx)) addEn <- replicateM(mkUnsafeRWire);

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

    Vector#(removeLanes, Commit) commitIfc;
    for(Integer i = 0; i < valueof(removeLanes); i = i+1) begin 
        commitIfc[i] = (interface Commit;
            method Bool contains(PhyRIndx phy);
                return False;
            endmethod

            method Action remove(PhyRIndx phy);
                removeEn[i].wset(phy);
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
        endinterface);
    end

    interface commit = commitIfc;
    interface rename = renameIfc;
endmodule