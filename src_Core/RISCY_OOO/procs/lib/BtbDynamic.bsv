/*-
 * Copyright (c) 2021 Franz Fuchs
 * Copyright (c) 2021 Jonathan Woodruff
 * All rights reserved.
 *
 * This software was developed by the University of  Cambridge
 * Department of Computer Science and Technology under the
 * SIPP (Secure IoT Processor Platform with Remote Attestation)
 * project funded by EPSRC: EP/S030868/1
 *
 * This work was supported by NCSC programme grant 4212611/RFA 15971 ("SafeBet").
 *
 * @BERI_LICENSE_HEADER_START@
 *
 * Licensed to BERI Open Systems C.I.C. (BERI) under one or more contributor
 * license agreements.  See the NOTICE file distributed with this work for
 * additional information regarding copyright ownership.  BERI licenses this
 * file to you under the BERI Hardware-Software License, Version 1.0 (the
 * "License"); you may not use this file except in compliance with the
 * License.  You may obtain a copy of the License at:
 *
 *   http://www.beri-open-systems.org/legal/license-1-0.txt
 *
 * Unless required by applicable law or agreed to in writing, Work distributed
 * under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * @BERI_LICENSE_HEADER_END@
 */



 // TODO: ADAPT TO NEW CHANGES FROM JON
 // THIS IS CURRENTLY NOT FUNCTIONAL

`ifdef CID
import Types::*;
import ProcTypes::*;
import ConfigReg::*;
import Map::*;
import Vector::*;
import CHERICC_Fat::*;
import CHERICap::*;
import Btb_IFC::*;
import BtbCore::*;


typedef 1024 TimeoutCycles;
typedef TSub#(TimeoutCycles, 1) MaxTimeout;
typedef 0 BtbInitAvailability;
typedef 128 AgeSize;
typedef TSub#(AgeSize, 1) MaxAge;

//typedef 4 TimeoutSize
typedef Bit#(TLog#(TimeoutCycles)) TimeoutCyclesIndex;
typedef Bit#(TLog#(BtbAssociativity)) BtbAsIndex;
typedef Bit#(TLog#(AgeSize)) Age;

typedef struct {
    CompIndex cid;
    Age age;
    Bool v;
} CompWay deriving (Bits, Eq, FShow);


module mkBtbDynamic(NextAddrPred#(hashSz))
    provisos (NumAlias#(tagSz, TSub#(TSub#(TSub#(AddrSz,SizeOf#(BtbBank)), SizeOf#(BtbIndex)), PcLsbsIgnore)),
        Add#(1, a__, TDiv#(tagSz, hashSz)),
    Add#(b__, tagSz, TMul#(TDiv#(tagSz, hashSz), hashSz)));

    Vector#(BtbAssociativity, Reg#(CompWay)) compWays;
    // initialise 0-th CompWay structure
    compWays[0] <- mkReg(CompWay{cid: 0, age: 1, v: True});
    for(Integer i = 1; i < valueOf(BtbAssociativity); i = i  + 1) compWays[i] <- mkRegU;
    NextAddrPred#(hashSz) btbCore <- mkBtbCore;
    Reg#(TimeoutCyclesIndex) timeout <- mkReg(0);
    Reg#(CompIndex) rg_cid <- mkReg(0);

    Reg#(BtbBank) firstBank_reg <- mkRegU;
    Vector#(SupSizeX2, MapSplitCore#(HashedTag#(hashSz), BtbIndex, VnD#(CapMem), BtbAssociativity, BtbInitAvailability))
        records <- replicateM(mkMapLossyBRAMCore);
    RWire#(BtbUpdate) updateEn <- mkRWire;
    RWire#(CompIndex) cidUpdate <- mkRWire;

    function MapKeyIndex#(HashedTag#(hashSz),BtbIndex) lookupKey(CapMem pc) =
        MapKeyIndex{key: hash(getTag(pc)), index: getIndex(pc)};

    function BtbAsIndex findNextWay();
        Age a = fromInteger(valueOf(TSub#(AgeSize, 1)));
        BtbAsIndex idx = 0;
        for(Integer i = 0; i < valueOf(BtbAssociativity); i = i + 1) begin
            if(compWays[i].age < a) begin
                a = compWays[i].age;
                idx = fromInteger(i);
            end
        end
        return idx;
    endfunction

    // no flush, accept update
    (* fire_when_enabled, no_implicit_conditions *)
    rule canonUpdate(updateEn.wget matches tagged Valid .upd);
        let pc = upd.pc;
        let nextPc = upd.nextPc;
        let taken = upd.taken;
        /*$display("MapUpdate in BTB - pc %x, bank: %x, taken: %x, next: %x, time: %t",
                  pc, getBank(pc), taken, nextPc, $time);*/
        records[getBank(pc)].update(lookupKey(pc), VnD{v:taken, d:nextPc});
    endrule

    rule doCycleInc(cidUpdate.wget matches tagged Invalid);
        timeout <= timeout + 1;
    endrule

    rule doPrinting(timeout == 256);
        $display("BTB-doPrinting");
        for(Integer i = 0; i < valueOf(BtbAssociativity); i = i + 1) begin
            $display(fshow(compWays[i]));
        end
    endrule

    rule doAging(timeout == fromInteger(valueOf(MaxTimeout)) &&& cidUpdate.wget matches tagged Invalid);
        $display("doAging");
        Bool allocated = False;
        Vector#(BtbAssociativity, Bool) v;
        for(Integer i = 0; i < valueOf(BtbAssociativity); i = i + 1) begin
            let s = compWays[i];
            if(s.v && s.cid != rg_cid && s.age != 0) begin
                s.age = s.age - 1;
            end
            if(s.age == 0) v[i] = True;
            else v[i] = False;
            if(s.age == 0 && !allocated) begin
                // free to take
                // and we have not given a new way to this compartment in this cycle
                allocated = True;
                s.age = fromInteger(valueOf(MaxAge));
                s.cid = rg_cid;
            end
            compWays[i] <= s;
        end
        for(Integer i = 0; i < valueOf(SupSizeX2); i = i + 1) begin
            records[i].clearWays(v);
        end
    endrule

    rule doCIDUpdate(cidUpdate.wget matches tagged Valid .upd);
        $display("BtbDynamic: doCIDUpdate");
        rg_cid <= upd;
        Vector#(BtbAssociativity, Bool) v;
        for(Integer i = 0; i < valueOf(BtbAssociativity); i = i + 1) begin
            let c = compWays[i];
            if(c.cid == upd) v[i] = True;
            else v[i] = False;
            if(c.cid == rg_cid) c.age = fromInteger(valueOf(MaxAge));
            compWays[i] <= c;
        end
        for(Integer i = 0; i < valueOf(SupSizeX2); i = i + 1) begin
            // after this cycle all writes and reads to the ways of the
            // new compartment
            records[i].changeWays(v);
        end
    endrule

    method Action put_pc(CapMem pc);
        BtbAddr addr = getBtbAddr(pc);
        firstBank_reg <= addr.bank;
        // Start SupSizeX2 BTB lookups, but ensure to lookup in the appropriate
        // bank for the alignment of each potential branch.
        for (Integer i = 0; i < valueOf(SupSizeX2); i = i + 1) begin
            BtbAddr a = unpack(pack(addr) + fromInteger(i));
            records[a.bank].lookupStart(MapKeyIndex{key: hash(a.tag), index: a.index});
        end
    endmethod

    method Vector#(SupSizeX2, Maybe#(CapMem)) pred;
        Vector#(SupSizeX2, Maybe#(CapMem)) ppcs = replicate(Invalid);
        for (Integer i = 0; i < valueOf(SupSizeX2); i = i + 1)
            if (records[i].lookupRead matches tagged Valid .record)
                ppcs[i] = record.v ? Valid(record.d):Invalid;
        ppcs = rotateBy(ppcs,unpack(-firstBank_reg)); // Rotate firstBank down to zeroeth element.
        return ppcs;
    endmethod

    method Action update(CapMem pc, CapMem nextPc, Bool taken);
        updateEn.wset(BtbUpdate {pc: pc, nextPc: nextPc, taken: taken});
    endmethod

    method Action shootdown(CompIndex cid);
        $display("BtbDynamic shootdown not implemented");
    endmethod

    method Action setCID(CompIndex cid);
        // only if this is a real update
        if(rg_cid != cid)  cidUpdate.wset(cid);
    endmethod

`ifdef SECURITY
    method Action flush method Action flush;
        for (Integer i = 0; i < valueOf(SupSizeX2); i = i + 1) records[i].clear;
    endmethod
    method flush_done = records[0].clearDone;
`else
    method flush = noAction;
    method flush_done = True;
`endif


endmodule

`endif
