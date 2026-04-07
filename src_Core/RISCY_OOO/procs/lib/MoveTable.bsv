import Vector::*;
import ProcTypes::*;
import Ehr::*;
import Types::*;

interface Lookup;
    method Bool contains(PhyRIndx phy);
endinterface

interface Update;
    method Bool canAdd; // guard of add
    method Action add(PhyRIndx phy);
    // remove is left unguarded, but we do do not expect to call it 
    // when phy is not in table, and assume that it suceeds
    method Action remove(PhyRIndx phy);
endinterface

interface MoveTable;
    // used to record source phy regs so we know to free/not free
    // MoveTable is functionally a multiset with limited capacity
    // we expose add, remove, and contains methods
    interface Vector#(SupSize, Lookup) lookup;
    interface Vector#(SupSize, Update) update;
endinterface

module mkMoveTable(MoveTable) provisos ( 
    NumAlias#(moveTableSize, 7),
    Alias#(slotCountT, Bit#(TLog#(moveTableSize)))
);

    Vector#(moveTableSize, Ehr#(SupSize, PhyRIndx)) moveSources <- replicateM(mkEhr(0));
    Vector#(moveTableSize, Ehr#(SupSize, Bool)) valid <- replicateM(mkEhr(False));
    Ehr#(SupSize, slotCountT) numFreeSlots <- mkEhr(fromInteger(valueof(moveTableSize)));

    Vector#(SupSize, Lookup) lookupIfc;
    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin 
        lookupIfc[i] = (interface Lookup;
            method Bool contains(PhyRIndx phy);
                Bool doesContain = False;
                for(Integer j = 0; j < valueof(moveTableSize); j = j+1) begin 
                    doesContain = doesContain || (valid[i][j] && moveSources[i][j] == phy);
                end
                return doesContain;
            endmethod
        endinterface);
    end

    Vector#(SupSize, Update) updateIfc;
    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin 
        Bool addGuard = !(numFreeSlots[i] == 0);
        updateIfc[i] = (interface Update;
            method canAdd = addGuard;

            method Action add(PhyRIndx phy) if(addGuard);
                numFreeSlots[i] <= numFreeSlots[i] - 1;
                Bool addSuccess = False;
                for(Integer j = 0; j < valueof(moveTableSize); j = j+1) begin 
                    if(!addSuccess && !valid[i][j]) begin 
                        valid[i][j] <= True;
                        moveSources[i][j] <= phy;
                        addSuccess = True;
                    end
                end
                doAssert(addSuccess, "adding to the move table must succeed");
            endmethod

            // we assume it will suceed
            method Action remove(PhyRIndx phy);
                numFreeSlots[i] <= numFreeSlots[i] + 1;
                Bool removeSuccess = False;
                for(Integer j = 0; j < valueof(moveTableSize); j = j+1) begin 
                    if(!removeSuccess && valid[i][j] && moveSources[i][j] == phy) begin 
                        valid[i][j] <= False;
                        removeSuccess = True;
                    end
                end
                doAssert(removeSuccess, "removing from the move table must succeed");
            endmethod
        endinterface);
    end

    interface lookup = lookupIfc;
    interface update = updateIfc;
endmodule