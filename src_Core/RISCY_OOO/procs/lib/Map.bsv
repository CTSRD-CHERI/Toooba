
// Copyright (c) 2021 Jonathan Woodruff
//
// All rights reserved.
//
// This software was developed by SRI International and the University of
// Cambridge Computer Laboratory (Department of Computer Science and
// Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
// DARPA SSITH research programme.
//
// This work was supported by NCSC programme grant 4212611/RFA 15971 ("SafeBet").
//
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

import DReg::*;
import RegFile::*;
import Vector::*;
import RWBramCore::*;
import Ehr::*;
import RWire::*;

typedef struct {
    ky key;
    ix index;
} MapKeyIndex#(type ky, type ix) deriving(Bits, Eq, FShow);
typedef struct {
    ky key;
    vl value;
} MapKeyValue#(type ky, type vl) deriving(Bits, Eq, FShow);
typedef struct {
    ky key;
    ix index;
    vl value;
} MapKeyIndexValue#(type ky, type ix, type vl) deriving(Bits, Eq, FShow);

// Type parameters are for index and key (which together are the "address"),
// the value stored in the map, and the associativity of the storage.
interface Map#(type ky, type ix, type vl, numeric type as);
    method Action update(MapKeyIndex#(ky,ix) key, vl value);
    method Action updateWithFunc(MapKeyIndex#(ky,ix) ki, vl value, function vl up(vl old_v, vl new_v), Bool insert);
    method Maybe#(vl) lookup(MapKeyIndex#(ky,ix) lookup_key);
    method Action clear;
    method Bool clearDone;
endinterface

module mkMapLossy#(vl default_value)(Map#(ky,ix,vl,as)) provisos (
Bits#(ky,ky_sz), Bits#(vl,vl_sz), Eq#(ky), Arith#(ky),
Bounded#(ix), Literal#(ix), Bits#(ix, ix_sz),
Bitwise#(ix), Eq#(ix), Arith#(ix));
    Vector#(as, RegFile#(ix, MapKeyValue#(ky,vl))) mem
        <- replicateM(mkRegFileWCF(0, maxBound));
    Reg#(Bit#(TLog#(as))) wayNext <- mkReg(0);
    Integer a = valueof(as);

    Reg#(Bool) clearReg <- mkReg(True);
    Reg#(ix) clearCount <- mkReg(0);
    PulseWire didUpdate <- mkPulseWire;
    rule doClear(clearReg && !didUpdate);
        for (Integer i = 0; i < a; i = i + 1) mem[i].upd(clearCount, MapKeyValue{key: ?, value: default_value});
        clearCount <= clearCount + 1;
        if (clearCount == ~0) clearReg <= False;
    endrule

    function Action doUpdate(MapKeyIndex#(ky,ix) ki, vl value, function vl up(vl old_v, vl new_v), Bool insert);
    action
        Bool found = False;
        Bit#(TLog#(as)) way = wayNext;
        vl old_value = default_value;
        if (a > 1) begin
            for (Integer i = 0; i < a; i = i + 1) begin
                MapKeyValue#(ky,vl) entry = mem[i].sub(ki.index);
                if (entry.key == ki.key) begin
                    found = True;
                    way = fromInteger(i);
                    old_value = entry.value;
                end
            end
        end
        if (found || insert) mem[way].upd(ki.index, MapKeyValue{key: ki.key, value: up(old_value, value)});
        wayNext <= (wayNext == fromInteger(a-1)) ? 0: wayNext + 1;
        didUpdate.send;
    endaction
    endfunction

    function vl returnNew(vl old_v, vl new_v) = new_v;
    method Action update(MapKeyIndex#(ky,ix) ki, vl value) = doUpdate(ki, value, returnNew, True);
    method Action updateWithFunc(MapKeyIndex#(ky,ix) ki, vl value, function vl up(vl old_v, vl new_v), Bool insert) =
        doUpdate(ki, value, up, insert);

    method Maybe#(vl) lookup(MapKeyIndex#(ky,ix) lu);
        Maybe#(vl) ret = Invalid;
        for (Integer i = 0; i < a; i = i + 1) begin
            let rd = mem[i].sub(lu.index);
            if (rd.key == lu.key) ret = Valid(rd.value);
        end
        return ret;
    endmethod
    method clear if (!clearReg) = clearReg._write(True);
    method clearDone = clearReg;
endmodule

interface MapSplit#(type ky, type ix, type vl, numeric type as);
    method Action updateMayInsert(MapKeyIndex#(ky,ix) key, vl value, Bool insert);
    method Action update(MapKeyIndex#(ky,ix) key, vl value);
    method Action lookupStart(MapKeyIndex#(ky,ix) lookup_key);
    method Maybe#(vl) lookupRead;
    method Action clear;
    method Bool clearDone;
endinterface

typedef struct {
    ix index;
    Bit#(TLog#(as)) way;
    Maybe#(ky) key;
} MapSplitCommit#(type ky, type ix, numeric type as) deriving(Bits, FShow);

module mkMapLossyBRAM(MapSplit#(ky,ix,vl,as)) provisos (
Bits#(ky,ky_sz), Bits#(vl,vl_sz), Eq#(ky), Arith#(ky),
Bounded#(ix), Literal#(ix), Bits#(ix, ix_sz),
Bitwise#(ix), Eq#(ix), Arith#(ix), PrimIndex#(ix, a__));
    Vector#(as, RWBramCore#(ix, Maybe#(MapKeyValue#(ky, vl)))) mem <-
        replicateM(mkRWBramCoreUG);
    // Keep a mirrored tag bank so updates can overlap lookups.
    Vector#(as, RWBramCore#(ix, Maybe#(ky))) updateKeys <- replicateM(mkRWBramCoreUG);
    Reg#(MapKeyIndex#(ky,ix)) lookupReg <- mkRegU;
    Reg#(MapKeyIndexValue#(ky,ix,vl)) updateReg <- mkRegU;
    Reg#(Bool) updateInsert <- mkRegU;
    Reg#(Bool) updateFresh <- mkDReg(False);
    Reg#(Bit#(TLog#(as))) wayNext <- mkReg(0);
    Integer a = valueof(as);

    Reg#(Bool) clearReg <- mkReg(True);
    Reg#(ix) clearCount <- mkReg(0);
    Reg#(Maybe#(MapSplitCommit#(ky, ix, as))) lastCommit <- mkDReg(Invalid);
    RWire#(MapSplitCommit#(ky, ix, as)) committing <- mkRWire;

    // The caller owns response flow control. lookupRead observes the most
    // recent request; lookupStart may replace it every cycle. A held result
    // becomes a miss after a same-set write, rather than exposing stale data.
    Reg#(Bool) lookupValid <- mkReg(False);
    Ehr#(2, Bool) lookupDirty <- mkEhr(False);
    Reg#(Bool) lookupCollision <- mkReg(False);

    // Separate rules avoid ordering initialization's clearReg write against
    // lookup/training requests, which must overlap committed updates.
    rule clearCanon(clearReg);
        for (Integer i = 0; i < a; i = i + 1) begin
            mem[i].wrReq(clearCount, Invalid);
            updateKeys[i].wrReq(clearCount, Invalid);
        end
        clearCount <= clearCount + 1;
        if (clearCount == ~0) clearReg <= False;
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule updateCanon(!clearReg && updateFresh);
        let u = updateReg;
        Maybe#(Bit#(TLog#(as))) hitWay = Invalid;
        for (Integer i = 0; i < a; i = i + 1) begin
            Maybe#(ky) tag = updateKeys[i].rdResp;
            // Consecutive updates can read a tag bank while the preceding
            // update writes it. Match against the committed tag in that way.
            if (lastCommit matches tagged Valid .previous &&&
                previous.index == u.index && previous.way == fromInteger(i))
                tag = previous.key;
            if (tag matches tagged Valid .key &&& key == u.key)
                hitWay = Valid(fromInteger(i));
        end
        if (updateInsert || isValid(hitWay)) begin
            let way = fromMaybe(wayNext, hitWay);
            Maybe#(MapKeyValue#(ky, vl)) entry =
                Valid(MapKeyValue {key: u.key, value: u.value});
            Maybe#(ky) tag = Valid(u.key);
            mem[way].wrReq(u.index, entry);
            updateKeys[way].wrReq(u.index, tag);
            let commitInfo = MapSplitCommit {index: u.index, way: way, key: tag};
            lastCommit <= Valid(commitInfo);
            committing.wset(commitInfo);
            if (lookupValid && lookupReg.index == u.index)
                lookupDirty[0] <= True;
            // Preserve MapSplit's replacement policy: conditional misses
            // neither allocate nor advance the victim way.
            wayNext <= (wayNext == fromInteger(a-1)) ? 0 : (wayNext + 1);
        end
    endrule

    function Action updateFn(MapKeyIndex#(ky,ix) ki, vl value, Bool insert) = action
        updateReg <= MapKeyIndexValue{key: ki.key, index: ki.index, value: value};
        updateFresh <= True;
        updateInsert <= insert;
        for (Integer i = 0; i < a; i = i + 1) updateKeys[i].rdReq(ki.index);
    endaction;

    // Training and lookup requests remain unguarded, as required by the
    // BTB's fire_when_enabled/no_implicit_conditions training rule. Training
    // during initialization/flush is discarded; lookups return misses.
    method Action updateMayInsert(MapKeyIndex#(ky,ix) ki, vl value, Bool insert);
        if (!clearReg) updateFn(ki, value, insert);
    endmethod
    method Action update(MapKeyIndex#(ky,ix) ki, vl value);
        if (!clearReg) updateFn(ki, value, True);
    endmethod

    method Action lookupStart(MapKeyIndex#(ky,ix) ki);
        lookupReg <= ki;
        lookupValid <= !clearReg;
        lookupDirty[1] <= False;
        Bool collision = False;
        if (committing.wget matches tagged Valid .commitInfo)
            collision = commitInfo.index == ki.index;
        lookupCollision <= collision;
        if (!clearReg)
            for (Integer i = 0; i < a; i = i + 1)
                mem[i].rdReq(ki.index);
    endmethod

    method Maybe#(vl) lookupRead;
        Maybe#(vl) readVal = Invalid;
        // Observe the snapshot before same-cycle update commits. A write
        // in the original read-request cycle is masked by lookupCollision.
        if (!clearReg && lookupValid && !lookupCollision && !lookupDirty[0])
            for (Integer i = 0; i < a; i = i + 1)
                if (mem[i].rdResp matches tagged Valid .entry &&& entry.key == lookupReg.key)
                    readVal = Valid(entry.value);
        return readVal;
    endmethod

    method Action clear if (!clearReg);
        clearReg <= True;
        lookupValid <= False;
    endmethod
    method Bool clearDone = !clearReg;
endmodule
