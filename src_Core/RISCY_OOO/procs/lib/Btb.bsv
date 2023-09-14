
// Copyright (c) 2017 Massachusetts Institute of Technology
//
//-
// RVFI_DII + CHERI modifications:
//     Copyright (c) 2020 Jessica Clarke
//     Copyright (c) 2020 Jonathan Woodruff
//     All rights reserved.
//
//     This software was developed by SRI International and the University of
//     Cambridge Computer Laboratory (Department of Computer Science and
//     Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
//     DARPA SSITH research programme.
//
//     This work was supported by NCSC programme grant 4212611/RFA 15971 ("SafeBet").
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
import DReg::*;
import Map::*;
import Vector::*;
import CHERICC_Fat::*;
import CHERICap::*;

export NextAddrPred(..);
export mkBtb;

interface NextAddrPred#(numeric type hashSz);
    method Action put_pc(CapMem pc);
    interface Vector#(SupSizeX2, Maybe#(CapMem)) pred;
    method Action update(CapMem pc, CapMem brTarget, Bool taken);
    // security
    method Action flush;
    method Bool flush_done;
endinterface

typedef struct {
    Bool v;
    data d;
} VnD#(type data) deriving(Bits, Eq, FShow);

// Local BTB Typedefs
typedef 1 PcLsbsIgnore;
Bit#(PcLsbsIgnore) targetLsb = 0;
typedef 1024 BtbEntries; // Actually 1536... For reasons...
`ifdef NO_COMPRESSED_BTB
typedef SizeOf#(CapMem) ShortTargetSize;
typedef SizeOf#(CapMem) MidTargetSize;
typedef SizeOf#(CapMem) CompTargetSize;
typedef CapMem CompTarget;
`else
typedef 14 ShortTargetSize;  // emulates 13 bits (LSB is zero), and equal to 12 bits in BTB-X data
typedef 26 MidTargetSize;  // emulates 25 bits (LSB is zero), and equal to 24 bits in BTB-X data
typedef Bit#(8) RegionHash;
// If differentRegion it True, regionHash is meaningful
typedef 28 CompTargetSize;
typedef struct {
    Bool differentRegion;
    RegionHash regionHash;
    Bit#(CompTargetSize) target;
} CompTarget deriving(Bits, Eq, FShow);
typedef CapMem FullTarget;
typedef Bit#(TSub#(SizeOf#(FullTarget),CompTargetSize)) Region;
`endif
typedef Bit#(ShortTargetSize) ShortTarget;
typedef Bit#(MidTargetSize) MidTarget;

typedef Bit#(TLog#(SupSizeX2)) BtbBank;
// Total entries/lanes of superscalar lookup/associativity
typedef TDiv#(TDiv#(BtbEntries,SupSizeX2),2) BtbIndices;
typedef Bit#(TLog#(BtbIndices)) BtbIndex;
typedef Bit#(TSub#(TSub#(TSub#(AddrSz, SizeOf#(BtbBank)), SizeOf#(BtbIndex)), PcLsbsIgnore)) BtbTag;
//typedef Bit#(TSub#(TSub#(AddrSz,SizeOf#(BtbBank)),SizeOf#(BtbIndex))) BtbTag;
typedef Bit#(hashSz) HashedTag#(numeric type hashSz);
typedef Bit#(2) RegionBtbIndex;

typedef struct {
    BtbTag tag;
    BtbIndex index;
    BtbBank bank;
} BtbAddr deriving(Bits, Eq, FShow);

typedef struct {
    CapMem pc;
    CapMem nextPc;
    Bool taken;
} BtbUpdate deriving(Bits, Eq, FShow);

(* synthesize *)
module mkBtb(NextAddrPred#(16));
    NextAddrPred#(16) btb <- mkBtbCore;
    return btb;
endmodule

module mkBtbCore(NextAddrPred#(hashSz))
    provisos (NumAlias#(tagSz, TSub#(TSub#(TSub#(AddrSz,SizeOf#(BtbBank)), SizeOf#(BtbIndex)), PcLsbsIgnore)),
        Add#(1, a__, TDiv#(tagSz, hashSz)),
    Add#(b__, tagSz, TMul#(TDiv#(tagSz, hashSz), hashSz)));
    // Read and Write ordering doesn't matter since this is a predictor
    Reg#(CapMem) addr_reg <- mkRegU;
`ifdef NO_COMPRESSED_BTB
    Bool optimizeScheduling = False;
    Vector#(SupSizeX2, MapSplitThreeWidth#(HashedTag#(hashSz),
                                           BtbIndex,
                                           VnD#(CapMem), VnD#(CapMem), VnD#(CapMem)))
`else
    Bool optimizeScheduling = True;
    Map#(Bit#(TSub#(SizeOf#(RegionHash),SizeOf#(RegionBtbIndex))), RegionBtbIndex, Region, 2) regionRecords <- mkMapLossy(unpack(0));
    Vector#(SupSizeX2, MapSplitThreeWidth#(HashedTag#(hashSz),
                                           BtbIndex,
                                           VnD#(ShortTarget), VnD#(MidTarget), VnD#(CompTarget)))
`endif
        compressedRecords <- replicateM(mkMapThreeWidthLossyBRAM(optimizeScheduling));
    Reg#(Maybe#(BtbUpdate)) updateEn <- mkDReg(Invalid);

    function BtbAddr getBtbAddr(CapMem pc) = unpack(truncateLSB(getAddr(pc)));
    function BtbBank getBank(CapMem pc) = getBtbAddr(pc).bank;
    function BtbTag getTag(CapMem pc) = getBtbAddr(pc).tag;
    function BtbIndex getIndex(CapMem pc) = getBtbAddr(pc).index;
    function MapKeyIndex#(HashedTag#(hashSz),BtbIndex) lookupKey(CapMem pc) =
        MapKeyIndex{key: hash(getTag(pc)), index: getIndex(pc)};
`ifndef NO_COMPRESSED_BTB
    function FullTarget getFullTarget(CompTarget mt, CapMem pc);
        Region region = mt.differentRegion ? fromMaybe(?,regionRecords.lookup(unpack(mt.regionHash))):truncateLSB(pc);
        return unpack({region,mt.target});
    endfunction
    function CompTarget getCompTarget(FullTarget ft, Bool differentRegion);
        Region region = truncateLSB(ft);
        return CompTarget{differentRegion: differentRegion,
                         regionHash: hash(region),
                         target: truncate(ft)
                        };
    endfunction
`endif

    // no flush, accept update
    (* fire_when_enabled, no_implicit_conditions *)
    rule canonUpdate(updateEn matches tagged Valid .upd);
        let pc = upd.pc;
        let nextPc = upd.nextPc;
        let taken = upd.taken;
        /*$display("MapUpdate in BTB - pc %x, bank: %x, taken: %x, next: %x, time: %t",
                  pc, getBank(pc), taken, nextPc, $time);*/
        ShortTarget sz = unpack(~0);
        MidTarget mz = unpack(~0);
        Bit#(CompTargetSize) cz = unpack(~0);
        Bool fitShort = ((pc^nextPc)&(~zeroExtend(sz))) == 0;
        Bool fitMid   = ((pc^nextPc)&(~zeroExtend(mz))) == 0;
        Bool fitComp  = ((pc^nextPc)&(~zeroExtend(cz))) == 0;
        if (fitShort)
            compressedRecords[getBank(pc)].update(lookupKey(pc), tagged T0 VnD{v:taken, d: truncate(nextPc)});
`ifndef NO_COMPRESSED_BTB
        else if (fitMid)
            compressedRecords[getBank(pc)].update(lookupKey(pc), tagged T1 VnD{v:taken, d: truncate(nextPc)});
        else begin
            Bool differentRegion = !fitComp;
            CompTarget md = getCompTarget(nextPc, differentRegion);
            compressedRecords[getBank(pc)].update(lookupKey(pc), tagged T2 VnD{v:taken, d: md});
            if (differentRegion) regionRecords.update(unpack(md.regionHash), truncateLSB(nextPc));
        end
`endif
    endrule

    method Action put_pc(CapMem pc);
        addr_reg <= pc;
        // Start SupSizeX2 BTB lookups, but ensure to lookup in the appropriate
        // bank for the alignment of each potential branch.
        BtbBank firstBank = getBtbAddr(pc).bank;
        for (Integer i = 0; i < valueOf(SupSizeX2); i = i + 1) begin
            // Only add lower bits for timing.
            Bit#(15) offset = truncate(pack(getBtbAddr(pc))) + fromInteger(i);
            CapMem lookup_pc = {truncateLSB(pc), offset, targetLsb};
            compressedRecords[firstBank+fromInteger(i)].lookupStart(lookupKey(lookup_pc));
        end
    endmethod

    method Vector#(SupSizeX2, Maybe#(CapMem)) pred;
        Vector#(SupSizeX2, Maybe#(CapMem)) ppcs = replicate(Invalid);
        for (Integer i = 0; i < valueOf(SupSizeX2); i = i + 1) begin
            if (compressedRecords[i].lookupRead matches tagged Valid .u3)
                case (u3) matches
                    tagged T0 .r: ppcs[i] = r.v ? Valid({truncateLSB(addr_reg),r.d}):Invalid;
`ifndef NO_COMPRESSED_BTB
                    tagged T1 .r: ppcs[i] = r.v ? Valid({truncateLSB(addr_reg),r.d}):Invalid;
                    tagged T2 .r: ppcs[i] = r.v ? Valid(getFullTarget(r.d, addr_reg)):Invalid;
`endif
                endcase
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
`ifndef NO_COMPRESSED_BTB
            regionRecords[i].clear;
`endif
            compressedRecords[i].clear;
        end
    endmethod
    method flush_done = compressedRecords[0].clearDone;
`else
    method flush = noAction;
    method flush_done = True;
`endif
endmodule
