
// Copyright (c) 2017 Massachusetts Institute of Technology
//
//-
// RVFI_DII + CHERI modifications:
//     Copyright (c) 2020 Jessica Clarke
//     Copyright (c) 2020 Jonathan Woodruff
//     Copyright (c) 2022 Franz Fuchs
//     All rights reserved.
//
//     This software was developed by SRI International and the University of
//     Cambridge Computer Laboratory (Department of Computer Science and
//     Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
//     DARPA SSITH research programme.
//
//     This work was supported by NCSC programme grant 4212611/RFA 15971 ("SafeBet").
//
//     This software was developed by the University of  Cambridge
//     Department of Computer Science and Technology under the
//     SIPP (Secure IoT Processor Platform with Remote Attestation)
//     project funded by EPSRC: EP/S030868/1
//-
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

import Types::*;
import ProcTypes::*;
import ConfigReg::*;
import Map::*;
import Vector::*;
import CHERICC_Fat::*;
import CHERICap::*;
import Btb_IFC::*;
import DReg::*;



module mkBtbTaggedCID(NextAddrPred#(hashSz))
    provisos (NumAlias#(tagSz, TSub#(TSub#(TSub#(AddrSz,SizeOf#(BtbBank)), SizeOf#(BtbIndex)), PcLsbsIgnore)),
        Add#(1, a__, TDiv#(tagSz, hashSz)),
    Add#(b__, tagSz, TMul#(TDiv#(tagSz, hashSz), hashSz)));
    // Read and Write ordering doesn't matter since this is a predictor
    Reg#(CapMem) addr_reg <- mkRegU;
    Vector#(SupSizeX2, MapSplit#(HashedTag#(hashSz), BtbIndex, VnDnC#(CapMem, CompIndex), 1))
        fullRecords <- replicateM(mkMapLossyBRAM);
    Vector#(SupSizeX2, MapSplit#(HashedTag#(hashSz), BtbIndex, VnDnC#(CompressedTarget, CompIndex), BtbAssociativity))
        compressedRecords <- replicateM(mkMapLossyBRAM);
    Reg#(Maybe#(BtbUpdate)) updateEn <- mkDReg(Invalid);
    Reg#(CompIndex) rg_cid <- mkReg(0);

    function BtbAddr getBtbAddr(CapMem pc) = unpack(truncateLSB(getAddr(pc)));
    function BtbBank getBank(CapMem pc) = getBtbAddr(pc).bank;
    function BtbIndex getIndex(CapMem pc) = getBtbAddr(pc).index;
    function BtbTag getTag(CapMem pc) = getBtbAddr(pc).tag;
    function MapKeyIndex#(HashedTag#(hashSz),BtbIndex) lookupKey(CapMem pc) =
        MapKeyIndex{key: hash(getTag(pc)), index: getIndex(pc)};

    // no flush, accept update
    (* fire_when_enabled, no_implicit_conditions *)
    rule canonUpdate(updateEn matches tagged Valid .upd);
        let pc = upd.pc;
        let nextPc = upd.nextPc;
        let taken = upd.taken;
        /*$display("MapUpdate in BTB - pc %x, bank: %x, taken: %x, next: %x, time: %t",
                  pc, getBank(pc), taken, nextPc, $time);*/
        CompressedTarget shortMask = -1;
        CapMem mask = ~zeroExtend(shortMask);
        if ((pc&mask) == (nextPc&mask))
            compressedRecords[getBank(pc)].update(lookupKey(pc), VnDnC{v:taken, d:truncate(nextPc), c:rg_cid});
        else
            fullRecords[getBank(pc)].update(lookupKey(pc), VnDnC{v:taken, d:nextPc, c:rg_cid});
    endrule

    method Action setCID(CompIndex cid);
        rg_cid <= cid;
    endmethod

    method Action put_pc(CapMem pc);
        addr_reg <= pc;
        // Start SupSizeX2 BTB lookups, but ensure to lookup in the appropriate
        // bank for the alignment of each potential branch.
        for (Integer i = 0; i < valueOf(SupSizeX2); i = i + 1) begin
            // Only add lower bits for timing.
            BtbAddr a = getBtbAddr(pc);
            a = unpack({a.tag, {a.index,a.bank} + fromInteger(i)});
            //BtbAddr a = unpack(pack(getBtbAddr(pc)) + fromInteger(i));
            fullRecords[a.bank].lookupStart(MapKeyIndex{key: hash(a.tag), index: a.index});
            compressedRecords[a.bank].lookupStart(MapKeyIndex{key: hash(a.tag), index: a.index});
        end
    endmethod

    method Vector#(SupSizeX2, Maybe#(CapMem)) pred;
        Vector#(SupSizeX2, Maybe#(CapMem)) ppcs = replicate(Invalid);
        for (Integer i = 0; i < valueOf(SupSizeX2); i = i + 1) begin
            if (fullRecords[i].lookupRead matches tagged Valid .r)
                ppcs[i] = (r.v && r.c == rg_cid) ? Valid(r.d):Invalid;
            if (compressedRecords[i].lookupRead matches tagged Valid .r)
                ppcs[i] = (r.v && r.c == rg_cid) ? Valid({truncateLSB(addr_reg),r.d}):Invalid;
        end
        ppcs = rotateBy(ppcs,unpack(-getBtbAddr(addr_reg).bank)); // Rotate firstBank down to zeroeth element.
        return ppcs;
    endmethod

    method Action update(CapMem pc, CapMem nextPc, Bool taken);
        updateEn <= Valid(BtbUpdate {pc: pc, nextPc: nextPc, taken: taken});
    endmethod

`ifdef SECURITY
    method Action flush method Action flush;
        for (Integer i = 0; i < valueOf(SupSizeX2); i = i + 1) begin
            fullRecords[i].clear;
            compressedRecords[i].clear;
        end
    endmethod
    method flush_done = fullRecords[0].clearDone;
`else
    method flush = noAction;
    method flush_done = True;
`endif
endmodule
