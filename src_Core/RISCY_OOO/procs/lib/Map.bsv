
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
        for (Integer i = 0; i < a; i = i + 1) mem[i].upd(clearCount, unpack(0));
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
    method Action update(MapKeyIndex#(ky,ix) key, vl value);
    method Action lookupStart(MapKeyIndex#(ky,ix) lookup_key);
    method Maybe#(vl) lookupRead;
    method Action clear;
    method Bool clearDone;
endinterface

module mkMapLossyBRAM(MapSplit#(ky,ix,vl,as)) provisos (
Bits#(ky,ky_sz), Bits#(vl,vl_sz), Eq#(ky), Arith#(ky),
Bounded#(ix), Literal#(ix), Bits#(ix, ix_sz),
Bitwise#(ix), Eq#(ix), Arith#(ix), PrimIndex#(ix, a__));
    Vector#(as, RWBramCore#(ix, MapKeyValue#(ky,vl))) mem <- replicateM(mkRWBramCoreUG);
    Vector#(as, RWBramCore#(ix, ky)) updateKeys <- replicateM(mkRWBramCoreUG);
    Reg#(MapKeyIndex#(ky,ix)) lookupReg <- mkRegU;
    Reg#(MapKeyIndexValue#(ky,ix,vl)) updateReg <- mkRegU;
    Reg#(Bool) updateFresh <- mkDReg(False);
    Reg#(Bit#(TLog#(as))) wayNext <- mkReg(0);
    Integer a = valueof(as);

    Reg#(Bool) clearReg <- mkReg(True);
    Reg#(ix) clearCount <- mkReg(0);
    (* fire_when_enabled, no_implicit_conditions *)
    rule updateCanon;
        if (clearReg) begin
            for (Integer i = 0; i < a; i = i + 1) mem[i].wrReq(clearCount, unpack(0));
            clearCount <= clearCount + 1;
            if (clearCount == ~0) clearReg <= False;
        end else if (updateFresh) begin
            let u = updateReg;
            Bit#(TLog#(as)) way = wayNext;
            for (Integer i = 0; i < a; i = i + 1)
                if (updateKeys[i].rdResp == u.key) way = fromInteger(i);
            // Always write to both the main memory bank and the copy used for updates.
            /*$display("MapUpdate - index: %x, key: %x, value: %x, way: %x",
                     u.index, u.key, u.value, way);*/
            mem[way].wrReq(u.index, MapKeyValue{key: u.key, value: u.value});
            updateKeys[way].wrReq(u.index, u.key);
            wayNext <= (wayNext == fromInteger(a-1)) ? 0 : (wayNext + 1);
        end
    endrule

    method Action update(MapKeyIndex#(ky,ix) ki, vl value);
        updateReg <= MapKeyIndexValue{key: ki.key, index: ki.index, value: value};
        updateFresh <= True;
        for (Integer i = 0; i < a; i = i + 1) updateKeys[i].rdReq(ki.index);
    endmethod
    method Action lookupStart(MapKeyIndex#(ky,ix) ki);
        lookupReg <= ki;
        for (Integer i = 0; i < a; i = i + 1) mem[i].rdReq(ki.index);
    endmethod
    method Maybe#(vl) lookupRead;
        Maybe#(vl) readVal = Invalid;
        for (Integer i = 0; i < a; i = i + 1) begin
            let resp = mem[i].rdResp;
            if (lookupReg.key == resp.key) readVal = Valid(resp.value);
        end
        // If there has been a recent write, take that one.
        if (updateReg.index == lookupReg.index && updateReg.key == lookupReg.key)
            readVal = Valid(updateReg.value);
        return readVal;
    endmethod
    method clear if (!clearReg) = clearReg._write(True);
    method clearDone = clearReg;
endmodule

typedef union tagged {
  t0 T0;
  t1 T1;
  t2 T2;
} Union3#(type t0, type t1, type t2) deriving (Bits, Eq, FShow);

typedef union tagged {
  t0 T0;
  t1 T1;
} Union2#(type t0, type t1) deriving (Bits, Eq, FShow);

interface MapSplitThreeWidth#(type ky, type ix, type vl0, type vl1, type vl2);
    method Action update(MapKeyIndex#(ky,ix) key, Union3#(vl0, vl1, vl2) value);
    method Action lookupStart(MapKeyIndex#(ky,ix) lookup_key);
    method Maybe#(Union3#(vl0, vl1, vl2)) lookupRead;
    method Action clear;
    method Bool clearDone;
endinterface

module mkMapThreeWidthLossyBRAM(MapSplitThreeWidth#(ky,ix,vl0,vl1,vl2)) provisos (
Bits#(ky,ky_sz), Eq#(ky), Arith#(ky),
Bounded#(ix), Literal#(ix), Bits#(ix, ix_sz),
Bitwise#(ix), Eq#(ix), Arith#(ix), PrimIndex#(ix, a__),
Bits#(MapKeyIndexValue#(ky, ix, Union3#(vl0, vl1, vl2)), miv_sz),
FShow#(vl0), FShow#(vl1), FShow#(vl2));
    RWBramCore#(ix, MapKeyValue#(ky,Union3#(vl0, vl1, vl2))) mem0 <- mkRWBramCoreUG;
    RWBramCore#(ix, MapKeyValue#(ky,Union2#(vl0, vl1)))      mem1 <- mkRWBramCoreUG;
    RWBramCore#(ix, MapKeyValue#(ky,vl0))                    mem2 <- mkRWBramCoreUG;
    Vector#(3, RWBramCore#(ix, ky)) updateKeys <- replicateM(mkRWBramCoreUG);
    Reg#(MapKeyIndex#(ky,ix)) lookupReg <- mkRegU;
    Reg#(MapKeyIndexValue#(ky,ix,Union3#(vl0, vl1, vl2))) updateReg <- mkRegU;
    Reg#(Bool) updateFresh <- mkDReg(False);
    Reg#(Bit#(TLog#(3))) wayNext <- mkReg(0);
    Integer a = valueof(3);

    Reg#(Bool) clearReg <- mkReg(True);
    Reg#(ix) clearCount <- mkReg(0);
    (* fire_when_enabled, no_implicit_conditions *)
    rule updateCanon;
        if (clearReg) begin
            mem0.wrReq(clearCount, unpack(0));
            mem1.wrReq(clearCount, unpack(0));
            mem2.wrReq(clearCount, unpack(0));
            clearCount <= clearCount + 1;
            if (clearCount == ~0) clearReg <= False;
        end else if (updateFresh) begin
            let u = updateReg;
            // randomish next way
            Bit#(TLog#(3)) way = wayNext;
            // correct for if there is a potential existing match
            for (Integer i = 0; i < a; i = i + 1)
                if (updateKeys[i].rdResp == u.key) way = fromInteger(i);
            // correct for size and prepare values to be written
            Union3#(vl0, vl1, vl2) up0 = ?;
            Union2#(vl0, vl1) up1 = ?;
            vl0 up2 = ?;
            case (u.value) matches
                tagged T0 .t0: begin
                    case (way)
                        0: up0 = tagged T0 t0;
                        1: up1 = tagged T0 t0;
                        2: up2 = t0;
                    endcase
                end
                tagged T1 .t1: begin
                    if (way>1) way = 1;
                    case (way)
                        0: up0 = tagged T1 t1;
                        1: up1 = tagged T1 t1;
                    endcase
                end
                tagged T2 .t2: begin
                    way = 0;
                    up0 = tagged T2 t2;
                end
            endcase
            // Always write to both the main memory bank and the copy used for updates.
            case (way)
                0: mem0.wrReq(u.index, MapKeyValue{key: u.key, value: up0});
                1: mem1.wrReq(u.index, MapKeyValue{key: u.key, value: up1});
                2: mem2.wrReq(u.index, MapKeyValue{key: u.key, value: up2});
            endcase
            updateKeys[way].wrReq(u.index, u.key);
            wayNext <= (wayNext == fromInteger(a-1)) ? 0 : (wayNext + 1);
        end
    endrule

    method Action update(MapKeyIndex#(ky,ix) ki, Union3#(vl0, vl1, vl2) value);
        updateReg <= MapKeyIndexValue{key: ki.key, index: ki.index, value: value};
        updateFresh <= True;
        for (Integer i = 0; i < a; i = i + 1) updateKeys[i].rdReq(ki.index);
    endmethod
    method Action lookupStart(MapKeyIndex#(ky,ix) ki);
        lookupReg <= ki;
        mem0.rdReq(ki.index);
        mem1.rdReq(ki.index);
        mem2.rdReq(ki.index);
    endmethod
    method Maybe#(Union3#(vl0, vl1, vl2)) lookupRead;
        Maybe#(Union3#(vl0, vl1, vl2)) readVal = Invalid;
        if (lookupReg.key == mem0.rdResp.key) readVal = Valid(mem0.rdResp.value);
        if (lookupReg.key == mem1.rdResp.key)
            case (mem1.rdResp.value) matches
                tagged T0 .t0: readVal = Valid(tagged T0 t0);
                tagged T1 .t1: readVal = Valid(tagged T1 t1);
            endcase
        if (lookupReg.key == mem2.rdResp.key) readVal = Valid(tagged T0 mem2.rdResp.value);
        // If there has been a recent write, take that one.
        if (updateReg.index == lookupReg.index && updateReg.key == lookupReg.key)
            readVal = Valid(updateReg.value);
        return readVal;
    endmethod
    method clear if (!clearReg) = clearReg._write(True);
    method clearDone = clearReg;
endmodule
