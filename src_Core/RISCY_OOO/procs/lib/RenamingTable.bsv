
// Copyright (c) 2017 Massachusetts Institute of Technology
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

// Alternate free list design:
// The FreeList has the same number of slots as #PhyReg - #ArchReg. When the
// ROB is empty, the FreeList is full. When the ROB is full, the FreeList is
// empty. The FreeList deq method takes the old name for the renamed register
// and writes it to the location just dequeued. On step-by-step rollback, the
// old name is taken from the FreeList and moved back to the RenamingTable.

import Vector::*;
import GetPut::*;
import List::*;
import RevertingVirtualReg::*;
import Types::*;
import ProcTypes::*;
import HasSpecBits::*;
import Ehr::*;

typedef struct {
    PhyRegs phy_regs;
} RenameResult deriving(Bits, Eq, FShow);

interface RTRename;
    // This will rename the architectural registers in r to physical registers.
    // XXX This will **ALWAYS** claim a new physical register as a speculative
    // in-flight renaming, no matter whether the dst reg is valid or not.
    // This simplifies the implementation for superscalar renaming
    method RenameResult getRename(ArchRegs r);
    method Action claimRename(ArchRegs r, SpecBits sb);
    method Bool canRename; // guard of rename
endinterface

interface RTCommit;
    // Commits the oldest instructions. This will free the previous physical
    // register used to hold the value for the architectural destination
    // register.
    method Action commit;
    method Bool canCommit; // guard of commit
endinterface

interface RTMove;
    // Interface to claim move from src to dst register
    method RenameResult getMoveResult(Move m, ArchRegs r);
    method Action claimMove(Move m, SpecBits sb);
    method Bool canMove; // guard of move
endinterface

interface RegRenamingTable;
    interface Vector#(SupSize, RTRename) rename; // rename port
    interface Vector#(SupSize, RTCommit) commit; // commit port
    interface Vector#(SupSize, RTMove) move; // move port

    // This subinterface contains the methods specifying correct and incorrect
    // speculation. If the speculation is correct, the dependencies on that
    // SpecTag should be removed from all SpecBits. If the speculation is
    // incorrect, then all renamings that depended on the SpecTag should be
    // reverted.
    interface SpeculationUpdate specUpdate;
    // methods: method Action incorrectSpeculation(SpecTag tag);
    //          method Action correctSpeculation(SpecTag tag);
endinterface

// actions when we claim a new phy reg in rename
typedef struct {
    Maybe#(ArchRIndx) arch;
    PhyRIndx phy;
    SpecBits specBits;
    Bool isMove;
} RenameClaim deriving(Bits, Eq, FShow);

// actions in case of wrongSpec
typedef struct {
    Bool killAll;
    SpecTag specTag;
} RTWrongSpec deriving(Bits, Eq, FShow);

(* synthesize *)
module mkRegRenamingTable(RegRenamingTable) provisos (
    NumAlias#(size, TSub#(NumPhyReg, NumArchReg)),
    NumAlias#(freeListSize, TSub#(NumPhyReg, 1)),
    Alias#(renamingIndexT, Bit#(TLog#(size))),
    Alias#(freeIndexT, Bit#(TLog#(freeListSize))),
    Alias#(freeCountT, Bit#(TLog#(TAdd#(freeListSize, 1)))),
    Alias#(vTagT, Bit#(TLog#(TMul#(2, size)))) // virtual tag: 0 -- size*2-1
);
    // ordering: commit < rename < correctSpec
    // commit < wrongSpec
    // wrongSpec C rename
    
    // NOTES:
    // rename do not need to see the effect of commit
    // rename is conflict with wrongSpec, so don't need to see its effect
    // The real actions of commit, wrongSpec and rename will be done in canon rule

    // rename is split into two parts in EHR port assignment:
    // - get (get the phy reg for src and dst arch regs, in rename method)
    // - claim (truly claim a free phy reg for dst arch reg, in canon rule)

    // Although the EHR ports of commit should also be split into two parts,
    // we don't need to do so, because the method of commit is directly followed by canon rule.

    // EHR ports for renaming_table
    Integer rt_get_port = 0;
    function Integer rt_commit_port(Integer i) = i;
    Integer rt_post_commit_port = valueof(SupSize);

    // EHR ports for valid
    Integer valid_get_port = 0;
    Integer valid_commit_port = 0;
    Integer valid_wrongSpec_port = 1;
    Integer valid_claim_port = 1;
    Integer valid_post_commit_port = 1;

    // EHR ports for spec_bits
    Integer sb_wrongSpec_port = 0;
    Integer sb_claim_port = 0;
    Integer sb_correctSpec_port = 1;

    // non-speculative renaming table at commit port
    // initially arch reg i --> phy reg i
    Vector#(NumArchReg, Ehr#(TAdd#(SupSize, 1), PhyRIndx)) renaming_table <- genWithM(compose(mkEhr, fromInteger));

    // A FIFO of
    // - in-flight renaming: when valid = True i.e. within [renamings_enqP, renamings_deqP)
    // We store the arch reg and phy reg separately to reduce EHR ports
    // XXX A valid in-flight renaming may have arch reg being invalid
    // This happens in case we claim a phy reg while the dst arch reg is invalid
    Vector#(size, Reg#(Maybe#(ArchRIndx))) new_renamings_arch <- replicateM(mkRegU);
    Vector#(size, Reg#(PhyRIndx)) new_renamings_phy <- replicateM(mkRegU);
    Vector#(size, Ehr#(2, Bool)) valid <- replicateM(mkEhr(False));
    Vector#(size, Ehr#(2, SpecBits)) spec_bits <- replicateM(mkEhr(0));
    Reg#(renamingIndexT) renamings_enqP <- mkReg(0); // point to claim free phy reg
    Reg#(renamingIndexT) renamings_deqP <- mkReg(0); // point to commit renaming and make phy reg free

    // A FIFO of free physical registers
    function m#(Reg#(PhyRIndx)) genFreePhyRegs(Integer i) provisos (IsModule#(m, a__));
        if(i < valueof(size)) begin 
            return mkReg(fromInteger(i + valueOf(NumArchReg))); // free phy regs initially
        end else begin 
            return mkReg(0); // i >= size is invalid, can be anything
        end
    endfunction
    Vector#(TSub#(NumPhyReg, 1), Reg#(PhyRIndx)) free_phy_regs <- genWithM(genFreePhyRegs);
    Reg#(freeIndexT) free_phy_enqP <- mkReg(fromInteger(valueof(size))); // point to release new free phy reg
    Reg#(freeIndexT) free_phy_deqP <- mkReg(0); // point to claim free phy reg

    // wires/EHRs to record actions
    Vector#(SupSize, RWire#(RenameClaim)) claimEn <- replicateM(mkUnsafeRWire);
    Vector#(SupSize, PulseWire) commitEn <- replicateM(mkPulseWire);
    RWire#(RTWrongSpec) wrongSpecEn <- mkRWire;

    // ordering regs
    Vector#(SupSize, Reg#(Bool)) commit_SB_rename <- replicateM(mkRevertingVirtualReg(True));
    Reg#(Bool) commit_SB_wrongSpec <- mkRevertingVirtualReg(True);

    // wrong spec conflict with rename
    Vector#(SupSize, RWire#(void)) wrongSpec_rename_conflict <- replicateM(mkRWire);

    function renamingIndexT getNextRenamingIndex(renamingIndexT idx);
        return idx == fromInteger(valueof(size) - 1) ? 0 : idx + 1;
    endfunction

    function renamingIndexT incrRenamingIndex(renamingIndexT idx, SupCnt incr);
        Bit#(TLog#(TAdd#(size, SupSize))) newIdx = zeroExtend(idx) + zeroExtend(incr);
        if(newIdx >= fromInteger(valueof(size))) begin
            newIdx = newIdx - fromInteger(valueof(size));
        end
        return truncate(newIdx);
    endfunction

    function freeIndexT getNextFreeIndex(freeIndexT idx);
        return idx == fromInteger(valueof(freeListSize) - 1) ? 0 : idx + 1;
    endfunction

    function freeIndexT incrFreeIndex(freeIndexT idx, SupCnt incr);
        Bit#(TLog#(TAdd#(freeListSize, SupSize))) newIdx = zeroExtend(idx) + zeroExtend(incr);
        if(newIdx >= fromInteger(valueof(freeListSize))) begin
            newIdx = newIdx - fromInteger(valueof(freeListSize));
        end
        return truncate(newIdx);
    endfunction

    function freeIndexT decrFreeIndex(freeIndexT idx, freeCountT decr);
        Bit#(TLog#(TAdd#(freeListSize, 1))) i = zeroExtend(idx);
        Bit#(TLog#(TAdd#(freeListSize, 1))) d = zeroExtend(decr);
        Bit#(TLog#(TAdd#(freeListSize, 1))) newIdx = i-d;
        if(d > i) begin
            newIdx = fromInteger(valueof(freeListSize)) - (d - i);
        end
        return truncate(newIdx);
    endfunction

    // get the index to query renaming_table
    function Bit#(TLog#(NumArchReg)) getRTIndex(ArchRIndx arch) = pack(arch);

    // vector of index to claim new in flight renaming for each rename port
    Vector#(SupSize, renamingIndexT) renamingsClaimIndex;
    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
        renamingsClaimIndex[i] = incrRenamingIndex(renamings_enqP, fromInteger(i));
    end

    // vector of index to claim free phy regs for each rename port
    Vector#(SupSize, freeIndexT) freeClaimIndex;
    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
        freeClaimIndex[i] = incrFreeIndex(free_phy_deqP, fromInteger(i));
    end

    // vector of index to commit phy regs for each commit port
    Vector#(SupSize, renamingIndexT) renamingsCommitIndex;
    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
        renamingsCommitIndex[i] = incrRenamingIndex(renamings_deqP, fromInteger(i));
    end

    // vector of index to release new free phy regs for each commit port
    Vector#(SupSize, freeIndexT) freeReleaseIndex;
    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
        freeReleaseIndex[i] = incrFreeIndex(free_phy_enqP, fromInteger(i));
    end

    // similar to LSQ, get virtual tag by using renamings_enqP as pivot (renamings_enqP is changed at end of cycle)
    // valid entry i --> i < renamings_enqP ? i + size : i
    // NOTE that virtual tag only works for **valid** entry
    function vTagT getVTag(renamingIndexT i);
        return i < renamings_enqP ? zeroExtend(i) + fromInteger(valueof(size)) : zeroExtend(i);
    endfunction
    Vector#(size, vTagT) vTags = map(getVTag, genWith(fromInteger));

    // find oldest entry using virtual tag (i.e. smallest)
    function Maybe#(renamingIndexT) findOldest(Vector#(size, Bool) pred);
        function renamingIndexT getOlder(renamingIndexT a, renamingIndexT b);
            if(!pred[a]) begin
                return b;
            end
            else if(!pred[b]) begin
                return a;
            end
            else begin
                return vTags[a] < vTags[b] ? a : b;
            end
        endfunction
        Vector#(size, renamingIndexT) idxVec = genWith(fromInteger);
        renamingIndexT tag = fold(getOlder, idxVec);
        return pred[tag] ? Valid (tag) : Invalid;
    endfunction

    // find youngest entry using virtual tag (i.e. largest)
    function Maybe#(renamingIndexT) findYoungest(Vector#(size, Bool) pred);
        function renamingIndexT getOlder(renamingIndexT a, renamingIndexT b);
            if(!pred[a]) begin
                return b;
            end
            else if(!pred[b]) begin
                return a;
            end
            else begin
                return vTags[a] < vTags[b] ? b : a;
            end
        endfunction
        Vector#(size, renamingIndexT) idxVec = genWith(fromInteger);
        renamingIndexT tag = fold(getOlder, idxVec);
        return pred[tag] ? Valid (tag) : Invalid;
    endfunction

    // find the nth freed phy reg to be added to the free list, invalid if not present
    function Maybe#(PhyRIndx) nthFreedPhy(Integer n, Vector#(SupSize, Maybe#(PhyRIndx)) freed_by_lane);
        SupCnt num_freed_prior = 0;
        Maybe#(PhyRIndx) out = Invalid;
        for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
            if (freed_by_lane[i] matches tagged Valid .p) begin 
                if (num_freed_prior == fromInteger(n)) begin 
                    out = Valid(p);
                end
                num_freed_prior = num_freed_prior + 1;
            end
        end
        return out;
    endfunction

    // canonicalize deq, wrongSpec/enq
    (* fire_when_enabled, no_implicit_conditions *)
    rule canon;
        Vector#(SupSize, SupWaySel) supIdxVec = genWith(fromInteger);

        // apply commit actions
        SupCnt num_phy_freed = 0;
        Vector#(SupSize, Maybe#(PhyRIndx)) freed_by_lane = replicate(Invalid);
        for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
            if(commitEn[i]) begin
                renamingIndexT curDeqP = renamingsCommitIndex[i];
                PhyRIndx commit_phy_reg = new_renamings_phy[curDeqP];
                Maybe#(ArchRIndx) commit_arch_reg = new_renamings_arch[curDeqP];
                PhyRIndx freed_phy_reg;
                // Commit will add to free list if phy reg in renaming_table not otherwise in use (right now no move elimination, so should be always)
                if(commit_arch_reg matches tagged Valid .arch) begin
                    let rtIdx = getRTIndex(arch);
                    // find phy reg freed in renaming_table
                    freed_phy_reg = renaming_table[rtIdx][rt_commit_port(i)];
                    // update renaming_table
                    renaming_table[rtIdx][rt_commit_port(i)] <= commit_phy_reg;
                end
                else begin
                    // free the phy reg claimed by this renaming (arch reg is don't care)
                    freed_phy_reg = commit_phy_reg;
                end
                // check if phy reg no longer in use
                Bool in_use = False;
                // check if phy_reg will end up in in-flight renamings
                for(Integer j=0; j<valueof(size); j = j+1) begin 
                    in_use = in_use || (new_renamings_phy[j] == freed_phy_reg && valid[j][valid_post_commit_port]);
                end
                // check if phy reg will end up in renaming table
                for(Integer j=0; j<valueof(NumArchReg); j = j+1) begin 
                    in_use = in_use || (renaming_table[fromInteger(j)][rt_post_commit_port] == freed_phy_reg);
                end
                // check if phy reg already freed this cycle
                for(Integer j = 0; j < valueof(SupSize); j = j+1) begin 
                    if(j < i && freed_by_lane[j] == Valid(freed_phy_reg)) begin 
                        in_use = True;
                    end
                end
                // mark phy reg to be fully freed if not in use
                if(!in_use) begin 
                    num_phy_freed = num_phy_freed + 1;
                    freed_by_lane[i] = Valid (freed_phy_reg);
                end
                // mark old in-flight renaming invalid
                valid[curDeqP][valid_commit_port] <= False;
                // sanity check
                doAssert(valid[curDeqP][valid_commit_port], "committing entry must be valid");
            end
        end

        // move freed phy registers into the free list
        for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
            freeIndexT curFreeEnqP = freeReleaseIndex[i];
            Maybe#(PhyRIndx) free_phy_reg = nthFreedPhy(i, freed_by_lane);
            if (free_phy_reg matches tagged Valid .p) begin 
                free_phy_regs[curFreeEnqP] <= p;
            end
        end

        // move renamings_deqP and free_phy_enqP: find the first non-commit port
        function Bool notCommit(SupWaySel i) = !commitEn[i];
        renamingIndexT nextDeqP;
        if(find(notCommit, supIdxVec) matches tagged Valid .idx) begin
            nextDeqP = renamingsCommitIndex[idx];
            // sanity check: commit is done consecutively
            for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
                doAssert((fromInteger(i) < idx) == commitEn[i], "commit must be consecutive");
            end
        end
        else begin
            nextDeqP = incrRenamingIndex(renamings_deqP, fromInteger(valueof(SupSize)));
        end
        renamings_deqP <= nextDeqP;
        free_phy_enqP <= incrFreeIndex(free_phy_enqP, num_phy_freed);

        // do wrongSpec OR claim free phy reg
        if(wrongSpecEn.wget matches tagged Valid .x) begin
            Bool killAll = x.killAll;
            SpecTag specTag = x.specTag;
            Vector#(size, renamingIndexT) idxVec = genWith(fromInteger);
            // do wrongSpec, first kill entries (make in-flight renaming to free phy reg)
            function Bool needKill(renamingIndexT i);
                return killAll || spec_bits[i][sb_wrongSpec_port][specTag] == 1;
            endfunction
            Vector#(size, Bool) isKill = map(needKill, idxVec);
            function Action kill(renamingIndexT i);
            action
                if(isKill[i]) begin
                    valid[i][valid_wrongSpec_port] <= False;
                end
            endaction
            endfunction
            joinActions(map(kill, idxVec));

            // find **valid** entries being killed
            Vector#(size, Bool) killValid = zipWith( \&& , isKill , readVEhr(valid_wrongSpec_port, valid) );

            // re-free the most recently dequeued free physical registers (1 for each killed valid and otherwise unused renaming)
            freeCountT numKilled = 0;
            for(Integer i = 0; i < valueof(size); i = i+1) begin
                if(killValid[i]) begin 
                    // check if unused
                    Bool in_use = False;
                    Bool first_in_killValid = True;
                    PhyRIndx phy_reg = new_renamings_phy[i];
                    // not in rename table
                    for(Integer j = 0; j < valueof(NumArchReg); j = j+1) begin 
                        in_use = in_use || (renaming_table[j][rt_post_commit_port] == phy_reg);
                    end
                    // not (valid and not killed)
                    for(Integer j=0; j < valueof(size); j = j+1) begin 
                        in_use = in_use || (new_renamings_phy[j] == phy_reg && valid[j][valid_wrongSpec_port] && !killValid[j]);
                        // only count each freed phy reg once
                        if(killValid[j] && new_renamings_phy[j] == phy_reg && j<i) begin 
                            first_in_killValid = False;
                        end
                    end
                    if(first_in_killValid && !in_use) begin
                        numKilled = numKilled+1;
                    end
                end
            end
            freeIndexT next_free_phy_deqP = decrFreeIndex(free_phy_deqP, numKilled);
            free_phy_deqP <= next_free_phy_deqP;

            // move renamings_enqP: find the oldest **valid** entry being killed
            renamingIndexT nextEnqP = renamings_enqP;
            if(findOldest(killValid) matches tagged Valid .idx) begin
                nextEnqP = idx;
            end
            renamings_enqP <= nextEnqP;
        end
        else begin
            // claim phy reg
            SupCnt num_non_move_renames = 0;
            for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
                if(claimEn[i].wget matches tagged Valid .claim) begin
                    renamingIndexT curEnqP = renamingsClaimIndex[i];
                    freeIndexT curFreeDeqP = freeClaimIndex[num_non_move_renames];
                    new_renamings_arch[curEnqP] <= claim.arch;
                    new_renamings_phy[curEnqP] <= claim.phy;
                    valid[curEnqP][valid_claim_port] <= True;
                    spec_bits[curEnqP][sb_claim_port] <= claim.specBits;
                    if(!claim.isMove) begin
                        num_non_move_renames = num_non_move_renames + 1;
                    end 
                    // sanity check
                    doAssert(!valid[curEnqP][valid_get_port], "claiming entry must be invalid");
                    doAssert(claim.isMove || claim.phy == free_phy_regs[curFreeDeqP], "phy reg should match free list if not move");
                end
            end
            // move renamings_enqP and free_phy_deqP: find the first non-claim port
            function Bool notClaim(SupWaySel i) = !isValid(claimEn[i].wget);
            renamingIndexT nextEnqP;
            freeIndexT nextFreeDeqP;
            nextFreeDeqP = incrFreeIndex(free_phy_deqP, num_non_move_renames);
            if(find(notClaim, supIdxVec) matches tagged Valid .idx) begin
                nextEnqP = renamingsClaimIndex[idx];
                // sanity check: rename is consecutive
                for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
                    doAssert((fromInteger(i) < idx) == isValid(claimEn[i].wget), "claim is consecutive");
                end
            end
            else begin
                nextEnqP = incrRenamingIndex(renamings_enqP, fromInteger(valueof(SupSize)));
            end
            renamings_enqP <= nextEnqP;
            free_phy_deqP <= nextFreeDeqP;
        end
    endrule

`ifdef BSIM
    // sanity check in simulation
    // all valid entry are within [renamings_deqP, renamings_enqP), outsiders are invalid entries
    (* fire_when_enabled, no_implicit_conditions *)
    rule sanityCheck;
        Bool empty = all( \== (False), readVEhr(0, valid) );
        function Bool in_range(renamingIndexT i);
            // i is within [renamings_deqP, renamings_enqP)
            if(empty) begin
                return False;
            end
            else begin
                if(renamings_deqP < renamings_enqP) begin
                    return renamings_deqP <= i && i < renamings_enqP;
                end
                else begin
                    return renamings_deqP <= i || i < renamings_enqP;
                end
            end
        endfunction
        for(Integer i = 0; i < valueof(size); i = i+1) begin
            doAssert(in_range(fromInteger(i)) == valid[i][0],
                "entries inside [renamings_deqP, renamings_enqP) should be valid, otherwise invalid"
            );
        end
        doAssert(renamings_enqP <= fromInteger(valueof(size) - 1), "renamings_enqP < size");
        doAssert(renamings_deqP <= fromInteger(valueof(size) - 1), "renamings_deqP < size");
    endrule
`endif


    // function to search claimed phy regs just in this cycle to
    // get phy reg for an arch reg for get_renaming at port getPort
    function Maybe#(PhyRIndx) search_claimed_renamings(Integer getPort, ArchRIndx arch_reg);
        List#(RWire#(RenameClaim)) claims = List::take(getPort, toList(claimEn));
        function Maybe#(PhyRIndx) getHit(RWire#(RenameClaim) clm);
            if(clm.wget matches tagged Valid .e) begin
                return e.arch == (Valid (arch_reg)) ? Valid (e.phy) : Invalid;
            end
            else begin
                return Invalid;
            end
        endfunction
        List#(Maybe#(PhyRIndx)) hitList = List::map(getHit, claims);
        // find the most recently claimed phy reg (i.e. largest list index)
        Maybe#(Maybe#(PhyRIndx)) hit = List::find(isValid, List::reverse(hitList));
        return fromMaybe(Invalid, hit);
    endfunction

    // function to search new_renamings to get phy reg for an arch reg
    function Maybe#(PhyRIndx) search_new_src_renamings(ArchRIndx arch_reg);
        // first get all hitting in-flight renamings
        function Bool hit(Integer i);
            return valid[i][valid_get_port] && new_renamings_arch[i] == (Valid (arch_reg));
        endfunction
        Vector#(size, Bool) isHit = map(hit, genVector);
        // find the youngest
        if(findYoungest(isHit) matches tagged Valid .idx) begin
            return Valid (new_renamings_phy[idx]);
        end
        else begin
            return Invalid;
        end
    endfunction

    // function to get phy reg for an arch reg for get_renaming at port getPort
    // priority: newly claimed -> new_renamings -> renaming_table
    function PhyRIndx get_src_renaming(Integer getPort, ArchRIndx arch_reg);
        let claim_phy_reg = search_claimed_renamings(getPort, arch_reg);
        let new_phy_reg = search_new_src_renamings(arch_reg);
        let existing_phy_reg = renaming_table[getRTIndex(arch_reg)][rt_get_port];
        return fromMaybe(fromMaybe(existing_phy_reg, new_phy_reg), claim_phy_reg);
    endfunction

    // function to count number of non-move renames prior to index into the free list
    function Integer get_num_non_moves_prior(Integer idx);
        Integer out = 0;
        for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
            if(i < idx) begin
                if(claimEn[i].wget matches tagged Valid .claim) begin 
                    if(!claim.isMove) begin 
                        out = out + 1;
                    end
                end
            end
        end
        return out;
    endfunction

    // function to find a free phy reg to claim (at port claimPort) for a dst arch reg
    function PhyRIndx get_dst_renaming(Integer claimPort);
        return free_phy_regs[freeClaimIndex[get_num_non_moves_prior(claimPort)]];
    endfunction

    function Bool isFpuReg(ArchRIndx arch_reg);
        return arch_reg matches tagged Fpu .* ? True : False;
    endfunction

    Vector#(SupSize, RTRename) renameIfc;
    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
        // XXX we always claim a free phy reg, but only return it if arch dst reg is valid
        Bool guard = !valid[renamingsClaimIndex[i]][valid_get_port];
        PhyRIndx claim_phy_reg = get_dst_renaming(i);
        renameIfc[i] = (interface RTRename;
            method RenameResult getRename(ArchRegs r) if(guard);
                // get renamings
                PhyRegs phy_regs = PhyRegs {
                    src1: tagged Invalid,
                    src2: tagged Invalid,
                    src3: tagged Invalid,
                    dst: tagged Invalid
                };
                if (r.src1 matches tagged Valid .valid_src1) begin
                    phy_regs.src1 = Valid (get_src_renaming(i, valid_src1));
                end
                if (r.src2 matches tagged Valid .valid_src2) begin
                    phy_regs.src2 = Valid (get_src_renaming(i, valid_src2));
                end
                if (r.src3 matches tagged Valid .valid_src3) begin
                    phy_regs.src3 = tagged Valid (get_src_renaming(i, tagged Fpu valid_src3));
                end
                if (r.dst matches tagged Valid .valid_dst) begin
                    phy_regs.dst = Valid (PhyDst {
                        indx: claim_phy_reg,
                        isFpuReg: isFpuReg(valid_dst)
                    });
                end

                return RenameResult {
                    phy_regs: phy_regs
                };
            endmethod

            method Action claimRename(ArchRegs r, SpecBits sb) if(guard);
                // record the claim
                claimEn[i].wset(RenameClaim {
                    arch: r.dst,
                    phy: claim_phy_reg,
                    specBits: sb,
                    isMove: False
                });
                // conflict with wrong spec
                wrongSpec_rename_conflict[i].wset(?);
                // ordering with commit
                commit_SB_rename[i] <= False;
            endmethod
            
            method canRename = guard;
        endinterface);
    end

    Vector#(SupSize, RTMove) moveIfc;
    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
        Bool guard = !valid[renamingsClaimIndex[i]][valid_get_port];
        moveIfc[i] = (interface RTMove;
            method RenameResult getMoveResult(Move m, ArchRegs r) if(guard);
                // get renamings
                PhyRegs phy_regs = PhyRegs {
                    src1: tagged Invalid,
                    src2: tagged Invalid,
                    src3: tagged Invalid,
                    dst: tagged Invalid
                };
                if (r.src1 matches tagged Valid .valid_src1) begin
                    phy_regs.src1 = Valid (get_src_renaming(i, valid_src1));
                end
                if (r.src2 matches tagged Valid .valid_src2) begin
                    phy_regs.src2 = Valid (get_src_renaming(i, valid_src2));
                end
                if (r.src3 matches tagged Valid .valid_src3) begin
                    phy_regs.src3 = tagged Valid (get_src_renaming(i, tagged Fpu valid_src3));
                end
                if (r.dst matches tagged Valid .valid_dst) begin
                    phy_regs.dst = Valid (PhyDst {
                        indx: get_src_renaming(i, m.src),
                        isFpuReg: isFpuReg(valid_dst)
                    });
                end

                return RenameResult {
                    phy_regs: phy_regs
                };
            endmethod

            method Action claimMove(Move m, SpecBits sb) if(guard);
                // record the claim
                claimEn[i].wset(RenameClaim {
                    arch: tagged Valid m.dst,
                    phy: get_src_renaming(i, m.src),
                    specBits: sb,
                    isMove: True
                });
                // conflict with wrong spec
                wrongSpec_rename_conflict[i].wset(?);
                // ordering with commit
                commit_SB_rename[i] <= False;
            endmethod
            
            method canMove = guard;
        endinterface);
    end

    Vector#(SupSize, RTCommit) commitIfc;
    for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
        Bool guard = valid[renamingsCommitIndex[i]][valid_commit_port] &&
                     all(id, readVReg(commit_SB_rename)) && // ordering: commit < rename
                     commit_SB_wrongSpec; // ordering: commit < wrongSpec
        commitIfc[i] = (interface RTCommit;
            method Action commit if(guard);
                commitEn[i].send; // record commit action
            endmethod
            method canCommit = guard;
        endinterface);
    end

    interface rename = renameIfc;
    interface commit = commitIfc;
    interface move = moveIfc;

    interface SpeculationUpdate specUpdate;
        method Action incorrectSpeculation(Bool killAll, SpecTag specTag);
            // record wrongSpec
            wrongSpecEn.wset(RTWrongSpec {
                killAll: killAll,
                specTag: specTag
            });
            // conflict with rename
            for(Integer i = 0; i < valueof(SupSize); i = i+1) begin
                wrongSpec_rename_conflict[i].wset(?);
            end
            // order after commit
            commit_SB_wrongSpec <= False;
        endmethod
        method Action correctSpeculation(SpecBits mask);
            function Action correctSpec(Integer i);
            action
                spec_bits[i][sb_correctSpec_port] <= spec_bits[i][sb_correctSpec_port] & mask;
            endaction
            endfunction
            Vector#(size, Integer) idxVec = genVector;
            joinActions(map(correctSpec, idxVec));
        endmethod
    endinterface
endmodule
