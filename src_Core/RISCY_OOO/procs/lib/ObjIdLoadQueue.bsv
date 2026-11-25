package ObjIdLoadQueue;

`include "ProcConfig.bsv"

import Assert::*;
import CacheUtils::*;
import CCTypes::*;
import ConfigReg::*;
import Ehr::*;
import GetPut::*;
import HasSpecBits::*;
import ProcTypes::*;
import RegFile::*;
import RWire::*;
import Types::*;
import Vector::*;

typedef struct {
    LdStQTag parent;
    InstTag instTag;
} ObjIdOwner deriving(Bits, Eq, FShow);

typedef struct {
    Addr paddr;
    Bit#(7) offset;
    Bit#(8) mte;
} ObjIdCheck deriving(Bits, Eq, FShow);

typedef struct {
    ObjIdQTag tag;
    LdStQTag parent;
    Addr paddr;
} LSQObjIdIssueInfo deriving(Bits, Eq, FShow);

typedef struct {
    ObjIdOwner owner;
    Bool ok;
} ObjIdResult deriving(Bits, Eq, FShow);

interface ObjIdLoadQueue;
    method Maybe#(ObjIdQTag) enqTag;
    method Action reserve(ObjIdOwner owner, SpecBits specBits, Bool unused);
    method Action setVAddr(ObjIdQTag tag, Addr addr);
    method Action prepare(ObjIdQTag tag, Bool enabled, Bool ready, Bool translated, ObjIdCheck check, Bool lookupPending);
    method ActionValue#(Tuple2#(Bool, Bool)) resolveLookup(ObjIdQTag tag, Bool hit);
    method Action translate(ObjIdQTag tag, Addr paddr, Bool fault);
    method Action start(ObjIdQTag tag);
    method Action cancel(ObjIdQTag tag);
    method LSQObjIdIssueInfo firstReady;
    method Action issue;
    method Action retry;
    method Bool skipFill(ObjIdQTag tag);
    method Action invalidateFills;
    method Addr paddr(ObjIdQTag tag);
    method Addr vaddr(ObjIdQTag tag);
    method ActionValue#(Maybe#(ObjIdResult)) complete(ObjIdQTag tag, MemTaggedData data);
    method Bool empty;
    method Bool requestsDrained;
    method Bool noWrongPath;
    interface Vector#(SupSize, Put#(Tuple2#(ObjIdQTag, InstTag))) setAtCommit;
    interface SpeculationUpdate specUpdate;
endinterface

(* synthesize *)
module mkObjIdLoadQueue(ObjIdLoadQueue);
    // Wide, non-searchable fields have a single write port and indexed reads.
    // Only the small control/speculation state is inspected in parallel.
    // Poison old responses across invalidations without generation wraparound.
    Vector#(ObjIdQSize, Ehr#(2, Bool)) staleFill <- replicateM(mkEhr(False));
    RegFile#(ObjIdQTag, ObjIdOwner) owners <- mkRegFileFull;
    RegFile#(ObjIdQTag, InstTag) commitTags <- mkRegFileFull;
    RegFile#(ObjIdQTag, ObjIdCheck) checks <- mkRegFileFull;
    RegFile#(ObjIdQTag, Addr) virtualAddrs <- mkRegFileFull;
    Vector#(ObjIdQSize, Ehr#(2, Bool)) used <- replicateM(mkEhr(False));
    Vector#(ObjIdQSize, Ehr#(3, Bool)) enabled <- replicateM(mkEhr(False));
    Vector#(ObjIdQSize, Ehr#(3, Bool)) translated <- replicateM(mkEhr(True));
    Vector#(ObjIdQSize, Ehr#(3, Bool)) lookupPending <- replicateM(mkEhr(False));
    Vector#(ObjIdQSize, Ehr#(3, Bool)) ready <- replicateM(mkEhr(False));
    Vector#(ObjIdQSize, Ehr#(3, Bool)) issued <- replicateM(mkEhr(False));
    Vector#(ObjIdQSize, Ehr#(3, Bool)) done <- replicateM(mkEhr(False));
    Vector#(ObjIdQSize, Ehr#(3, Bool)) canceled <- replicateM(mkEhr(False));
    Vector#(ObjIdQSize, Ehr#(3, SpecBits)) masks <- replicateM(mkEhr(0));
    Vector#(ObjIdQSize, Ehr#(TAdd#(1, SupSize), Bool)) atCommit <- replicateM(mkEhr(False));
    Reg#(ObjIdQTag) head <- mkReg(0);
    Reg#(ObjIdQTag) tail <- mkReg(0);
    Reg#(ObjIdQTag) cursor <- mkReg(0);
    PulseWire wrongSpec <- mkPulseWire;

    function ObjIdQTag next(ObjIdQTag tag) =
        tag == fromInteger(valueOf(ObjIdQSize)-1) ? 0 : tag+1;
    function Bit#(ObjIdQSize) pending;
        Bit#(ObjIdQSize) bits = 0;
        for (Integer i=0; i<valueOf(ObjIdQSize); i=i+1)
            bits[i] = pack(used[i][1] && enabled[i][0] && ready[i][0] &&
                           translated[i][0] && !lookupPending[i][0] && !issued[i][0] && !done[i][0] && !canceled[i][0]);
        return bits;
    endfunction
    function ObjIdQTag selected;
        Bit#(ObjIdQSize) upper = pending & ('1 << cursor);
        Bit#(ObjIdQSize) candidates = upper != 0 ? upper : pending;
        Bit#(ObjIdQSize) oneHot = candidates & (~candidates+1);
        ObjIdQTag tag = 0;
        for (Integer i=0; i<valueOf(ObjIdQSize); i=i+1)
            tag = tag | (oneHot[i] == 1 ? fromInteger(i) : 0);
        return tag;
    endfunction

    // Reclaim resolved reservations on this queue's own head pointer.
    // Payload queues and ROB retirement do not participate in reclamation.
    rule retire (used[head][0] && done[head][0] && !lookupPending[head][0] && !issued[head][0] && !wrongSpec);
        used[head][0] <= False;
        head <= next(head);
    endrule

    Vector#(SupSize, Put#(Tuple2#(ObjIdQTag, InstTag))) commitIfc;
    for (Integer port=0; port<valueOf(SupSize); port=port+1) begin
        commitIfc[port] = interface Put;
            method Action put(Tuple2#(ObjIdQTag, InstTag) reference);
                let {tag, instTag} = reference;
                if (used[tag][0] && commitTags.sub(tag) == instTag)
                    atCommit[tag][port] <= True;
            endmethod
        endinterface;
    end

    method Maybe#(ObjIdQTag) enqTag = !used[tail][1] ? Valid(tail) : Invalid;
    method Action reserve(ObjIdOwner owner, SpecBits specBits, Bool unused) if (!used[tail][1] && !wrongSpec);
        staleFill[tail][1] <= False;
        owners.upd(tail, owner);
        commitTags.upd(tail, owner.instTag);
        used[tail][1] <= True;
        enabled[tail][2] <= False;
        ready[tail][2] <= False;
        lookupPending[tail][2] <= False;
        translated[tail][2] <= True;
        issued[tail][2] <= False;
        done[tail][2] <= unused;
        canceled[tail][2] <= False;
        // Correct speculation must also clear bits on a reservation allocated
        // in this cycle, before the branch tag can be reused.
        masks[tail][0] <= specBits;
        atCommit[tail][valueOf(SupSize)] <= False;
        tail <= next(tail);
    endmethod
    method Action setVAddr(ObjIdQTag tag, Addr addr) if (!wrongSpec);
        virtualAddrs.upd(tag, addr);
    endmethod
    method Action prepare(ObjIdQTag tag, Bool active, Bool canIssue, Bool addressReady, ObjIdCheck check, Bool waitLookup) if (!wrongSpec);
        doAssert(used[tag][1] && !issued[tag][0] && !canceled[tag][0], "prepare needs live reservation");
        checks.upd(tag, check);
        lookupPending[tag][0] <= active && waitLookup;
        translated[tag][0] <= addressReady;
        enabled[tag][0] <= active;
        ready[tag][0] <= canIssue;
        done[tag][0] <= !active;
    endmethod
    method ActionValue#(Tuple2#(Bool, Bool)) resolveLookup(ObjIdQTag tag, Bool hit) if (!wrongSpec);
        doAssert(used[tag][1] && lookupPending[tag][1] && !issued[tag][0], "lookup decision needs held reservation");
        Bool needed = enabled[tag][1] && !done[tag][1] && !canceled[tag][1];
        hit = hit && !staleFill[tag][0];
        lookupPending[tag][1] <= False;
        if (hit || !needed) begin
            // No metadata translation has been sent yet. A cached/forwarded
            // verdict cancels that optional work without waiting for a reply.
            translated[tag][1] <= True;
            enabled[tag][1] <= False;
            done[tag][1] <= True;
        end
        return tuple2(needed, hit);
    endmethod
    method Action start(ObjIdQTag tag) if (!wrongSpec);
        // Port 1 observes prepare in the same execute rule. The selector
        // reads port 0, so descriptor writes never bypass into a request.
        ready[tag][1] <= True;
    endmethod
    method Action cancel(ObjIdQTag tag) if (!wrongSpec);
        doAssert(!issued[tag][0], "cannot discard an issued lookup");
        enabled[tag][1] <= False;
        done[tag][1] <= translated[tag][1];
    endmethod
    method Action translate(ObjIdQTag tag, Addr paddr, Bool fault) if (!wrongSpec);
        doAssert(used[tag][1] && !translated[tag][0], "translation needs pending reservation");
        let check = checks.sub(tag);
        check.paddr = paddr;
        checks.upd(tag, check);
        translated[tag][0] <= True;
        if (fault || canceled[tag][0] || !enabled[tag][0]) done[tag][0] <= True;
    endmethod
    method LSQObjIdIssueInfo firstReady if (pending != 0 && !wrongSpec);
        let tag = selected;
        let check = checks.sub(tag);
        return LSQObjIdIssueInfo {tag:tag, parent:owners.sub(tag).parent, paddr:check.paddr};
    endmethod
    method Action issue if (pending != 0 && !wrongSpec);
        issued[selected][1] <= True;
        cursor <= next(selected);
    endmethod
    method Action retry if (pending != 0 && !wrongSpec);
        cursor <= next(selected);
    endmethod
    method Bool skipFill(ObjIdQTag tag) = staleFill[tag][0] || !used[tag][0] || canceled[tag][0];
    method Action invalidateFills;
        for (Integer i=0; i<valueOf(ObjIdQSize); i=i+1) staleFill[i][0] <= True;
    endmethod
    method Addr paddr(ObjIdQTag tag) = checks.sub(tag).paddr;
    method Addr vaddr(ObjIdQTag tag) = virtualAddrs.sub(tag);
    method ActionValue#(Maybe#(ObjIdResult)) complete(ObjIdQTag tag, MemTaggedData data) if (!wrongSpec);
        doAssert(used[tag][1] && issued[tag][0], "response must own an issued queue entry");
        issued[tag][0] <= False;
        done[tag][0] <= True;
        let check = checks.sub(tag);
        Vector#(MemDataBytes, Bit#(8)) bytes = unpack(pack(data.data));
        Bit#(4) index = truncate(check.offset);
        Bool mismatch = check.mte != bytes[index];
        return canceled[tag][0] ? Invalid : Valid(ObjIdResult {
            owner:owners.sub(tag), ok:!mismatch
        });
    endmethod
    // Reservations may belong to younger instructions, so fences wait only
    // for issued requests (including queued responses and refresh completion).
    method Bool requestsDrained;
        function Bool requestIssued(Integer i) = issued[i][0];
        Vector#(ObjIdQSize, Integer) indices = genVector;
        return !any(requestIssued, indices);
    endmethod
    method Bool empty = !used[head][0];
    method Bool noWrongPath;
        Bool clear = True;
        for (Integer i=0; i<valueOf(ObjIdQSize); i=i+1)
            clear = clear && !(used[i][0] && canceled[i][0] && issued[i][0]);
        return clear;
    endmethod
    interface setAtCommit = commitIfc;
    interface SpeculationUpdate specUpdate;
        method Action correctSpeculation(SpecBits mask);
            for (Integer i=0; i<valueOf(ObjIdQSize); i=i+1)
                masks[i][1] <= masks[i][1] & mask;
        endmethod
        method Action incorrectSpeculation(Bool killAll, SpecTag tag);
            for (Integer i=0; i<valueOf(ObjIdQSize); i=i+1) begin
                if (used[i][0] && (killAll ? !atCommit[i][0] : masks[i][0][tag] == 1)) begin
                    canceled[i][0] <= True;
                    lookupPending[i][0] <= False;
                    done[i][0] <= !issued[i][0];
                end
            end
            wrongSpec.send;
        endmethod
    endinterface
endmodule
endpackage
