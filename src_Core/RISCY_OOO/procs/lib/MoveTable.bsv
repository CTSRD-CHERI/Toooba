import Vector::*;
import ProcTypes::*;
import HasSpecBits::*;
import Ehr::*;
import Types::*;

interface Lookup;
    method Bool contains(PhyRIndx phy);
endinterface

interface Update;
    method Bool canAdd; // guard of add
    method Action add(PhyRIndx phy, SpecBits sb);
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

    // This subinterface contains the methods specifying correct and incorrect
    // speculation. If the speculation is correct, the dependencies on that
    // SpecTag should be removed from all SpecBits. If the speculation is
    // incorrect, then all renamings that depended on the SpecTag should be
    // reverted.
    interface SpeculationUpdate specUpdate;
    // methods: method Action incorrectSpeculation(SpecTag tag);
    //          method Action correctSpeculation(SpecTag tag);
endinterface

module mkMoveTable(MoveTable) provisos ( 
    NumAlias#(moveTableSize, 7),
    Alias#(slotCountT, Bit#(TLog#(moveTableSize)))
);

    // ordering: commit < rename < correctSpec
    // commit < wrongSpec
    // wrongSpec C rename

    Integer sb_correctSpec_port = valueof(SupSize);
    Integer sb_wrongSpec_port = 1;
    Integer valid_wrongSpec_port = 1;

    Vector#(moveTableSize, Ehr#(SupSize, PhyRIndx)) moveSources <- replicateM(mkEhr(0));
    Vector#(moveTableSize, Ehr#(SupSize, Bool)) valid <- replicateM(mkEhr(False));
    Vector#(moveTableSize, Ehr#(TAdd#(1, SupSize), SpecBits)) specBits <- replicateM(mkEhr(0));
    Ehr#(TAdd#(1, SupSize), slotCountT) numFreeSlots <- mkEhr(fromInteger(valueof(moveTableSize)));

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

            method Action add(PhyRIndx phy, SpecBits sb) if(addGuard);
                numFreeSlots[i] <= numFreeSlots[i] - 1;
                Bool addSuccess = False;
                for(Integer j = 0; j < valueof(moveTableSize); j = j+1) begin 
                    if(!addSuccess && !valid[i][j]) begin 
                        valid[i][j] <= True;
                        moveSources[i][j] <= phy;
                        specBits[i][j] <= sb;
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

    interface SpeculationUpdate specUpdate;
        method Action incorrectSpeculation(Bool killAll, SpecTag specTag);
            function Bool needKill(Integer i);
                return killAll || specBits[i][sb_wrongSpec_port][specTag] == 1;
            endfunction

            for(Integer i = 0; i < valueof(moveTableSize); i = i+1) begin 
                if(needKill(i)) begin 
                    valid[i][valid_wrongSpec_port] <= False;
                end
            end
        endmethod
        method Action correctSpeculation(SpecBits mask);
            for(Integer i = 0; i < valueof(moveTableSize); i = i+1) begin 
                specBits[i][sb_correctSpec_port] <= specBits[i][sb_correctSpec_port] & mask;
            end
        endmethod
    endinterface
endmodule