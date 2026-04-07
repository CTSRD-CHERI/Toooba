import Vector::*;
import ProcTypes::*;
import Ehr::*;

interface Lookup;
    method Bool contains(PhyRIndx phy);
endinterface

interface Update;
    method Bool canAdd; // guard of add
    method Action add(PhyRIndx phy);
    // remove can be unguarded, but we do do not expect to call it 
    // when phy is not in table
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
    NumAlias#(moveTableSize, 7)
);

    Vector#(SupSize, Lookup) lookupIfc;
    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin 
        lookupIfc[i] = (interface Lookup;
            method Bool contains(PhyRIndx phy);
                return False;
            endmethod
        endinterface);
    end

    Vector#(SupSize, Update) updateIfc;
    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin 
        Bool addGuard = False;
        updateIfc[i] = (interface Update;
            method canAdd = addGuard;

            method Action add(PhyRIndx phy) if(addGuard);
                noAction;
            endmethod

            // unguarded
            method Action remove(PhyRIndx phy);
                noAction;
            endmethod
        endinterface);
    end

    interface lookup = lookupIfc;
    interface update = updateIfc;
endmodule