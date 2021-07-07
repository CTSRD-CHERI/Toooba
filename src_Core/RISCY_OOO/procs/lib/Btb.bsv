
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

import Types::*;
import ProcTypes::*;
import ConfigReg::*;
import RegFile::*;
import Vector::*;

export NextAddrPred(..);
export mkBtb;

interface NextAddrPred;
    method Action put_pc(Addr pc);
    interface Vector#(SupSizeX2, Maybe#(Addr)) pred;
    method Action update(Addr pc, Addr brTarget, Bool taken);
    // security
    method Action flush;
    method Bool flush_done;
endinterface

// Local BTB Typedefs
typedef 1 PcLsbsIgnore;
typedef 256 BtbEntries; // 4KB BTB
typedef Bit#(TLog#(SupSizeX2)) BtbBank;
typedef TDiv#(BtbEntries,SupSizeX2) BtbIndices;
typedef Bit#(TLog#(BtbIndices)) BtbIndex;
typedef Bit#(TSub#(TSub#(AddrSz, TLog#(BtbEntries)), PcLsbsIgnore)) BtbTag;
typedef struct {
    BtbTag tag;
    BtbIndex index;
    BtbBank bank;
} BtbAddr deriving(Bits, Eq, FShow);

typedef struct {
    Addr pc;
    Addr nextPc;
    Bool taken;
} BtbUpdate deriving(Bits, Eq, FShow);

typedef struct {
    BtbTag tag;
    Addr nextPc;
} BtbRecord deriving(Bits, Eq, FShow);

(* synthesize *)
module mkBtb(NextAddrPred);
    // Read and Write ordering doesn't matter since this is a predictor
    // mkRegFileWCF is the RegFile version of mkConfigReg
    Reg#(BtbTag) tag_reg <- mkRegU;
    Reg#(BtbBank) firstBank_reg <- mkRegU;
    Vector#(SupSizeX2, Reg#(BtbIndex)) idxs_reg <- replicateM(mkRegU);
    Vector#(SupSizeX2, RegFile#(BtbIndex, BtbRecord)) records <- replicateM(mkRegFileWCF(0,~0));
    Vector#(SupSizeX2, Vector#(BtbIndices, Reg#(Bool))) valid <- replicateM(replicateM(mkConfigReg(False)));

    RWire#(BtbUpdate) updateEn <- mkRWire;

`ifdef SECURITY
    Reg#(Bool) flushDone <- mkReg(True);
`else
    Bool flushDone = True;
`endif

    function BtbAddr getBtbAddr(Addr pc) = unpack(truncateLSB(pc));
    function BtbBank getBank(Addr pc) = getBtbAddr(pc).bank;
    function BtbIndex getIndex(Addr pc) = getBtbAddr(pc).index;
    function BtbTag getTag(Addr pc) = getBtbAddr(pc).tag;

    // no flush, accept update
    (* fire_when_enabled, no_implicit_conditions *)
    rule canonUpdate(flushDone &&& updateEn.wget matches tagged Valid .upd);
        let pc = upd.pc;
        let nextPc = upd.nextPc;
        let taken = upd.taken;

        let index = getIndex(pc);
        let tag = getTag(pc);
        let bank = getBank(pc);
        $display("cap: %x, btbaddr: ", pc, fshow(getBtbAddr(pc)), " nextPc:%x", nextPc);
        if(taken) begin
            valid[bank][index] <= True;
            records[bank].upd(index, BtbRecord{tag: tag, nextPc: nextPc});
        end else if(records[bank].sub(index).tag == tag ) begin
            // current instruction has target in btb, so clear it
            valid[bank][index] <= False;
            records[bank].upd(index, BtbRecord{tag: {4'ha,0}, nextPc: nextPc}); // An invalid virtual address.
        end
    endrule

`ifdef SECURITY
    // flush, clear everything (and drop update)
    rule doFlush(!flushDone);
        for (Integer i = 0; i < valueOf(SupSizeX2); i = i + 1) writeVReg(valid[i], replicate(False));
        flushDone <= True;
    endrule
`endif

    method Action put_pc(Addr pc);
        BtbAddr addr = getBtbAddr(pc);
        tag_reg <= addr.tag;
        firstBank_reg <= addr.bank;
        for (Integer i = 0; i < valueOf(SupSizeX2); i = i + 1) begin
            BtbAddr a = unpack(pack(addr) + fromInteger(i));
            $display("put pc[%d]: ", i, fshow(a));
            idxs_reg[a.bank] <= a.index;
        end
    endmethod

    method Vector#(SupSizeX2, Maybe#(Addr)) pred;
        Vector#(SupSizeX2, Maybe#(BtbRecord)) recs = ?;
        for (Integer i = 0; i < valueOf(SupSizeX2); i = i + 1)
            recs[i] = (valid[i][idxs_reg[i]]) ? Valid(records[i].sub(idxs_reg[i])):Invalid;
        function Maybe#(Addr) tagHit(Maybe#(BtbRecord) br) =
            case (br) matches
                tagged Valid .b &&& (tag_reg == b.tag): return Valid(b.nextPc);
                tagged Invalid: return Invalid;
            endcase;
        Vector#(SupSizeX2, Maybe#(Addr)) ppcs = map(tagHit,recs);
        ppcs = rotateBy(ppcs,unpack(-firstBank_reg)); // Rotate firstBank down to zeroeth element.
        return ppcs;
    endmethod

    method Action update(Addr pc, Addr nextPc, Bool taken);
        updateEn.wset(BtbUpdate {pc: pc, nextPc: nextPc, taken: taken});
    endmethod

`ifdef SECURITY
    method Action flush if(flushDone);
        flushDone <= False;
    endmethod
    method flush_done = flushDone._read;
`else
    method flush = noAction;
    method flush_done = True;
`endif
endmodule
