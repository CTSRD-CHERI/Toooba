
// Copyright (c) 2017 Massachusetts Institute of Technology
//
//-
// RVFI_DII + CHERI modifications:
//     Copyright (c) 2020 Alexandre Joannou
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

`include "ProcConfig.bsv"
import Types::*;
import ProcTypes::*;
import Vector::*;
import FIFOF::*;
import FShow::*;
import Assert::*;
import Ehr::*;
import CacheUtils::*;

// store buffer data block byte size == cache line
typedef TMul#(8, CLineDataNumBytes) SBBlockSz;
typedef Bit#(SBBlockSz) SBBlock;
typedef Vector#(CLineDataNumBytes, Bool) SBByteEn;

// aligned addr
typedef TSub#(AddrSz, LogCLineDataNumBytes) SBBlockAddrSz;
typedef Bit#(SBBlockAddrSz) SBBlockAddr;
function SBBlockAddr getSBBlockAddr(Addr a);
    return truncateLSB(a);
endfunction

// SB block vs. normal data
typedef TDiv#(SBBlockSz, MemDataSz) SBBlockNumMemData;
typedef Bit#(TLog#(SBBlockNumMemData)) SBBlockMemDataSel;
function SBBlockMemDataSel getSBBlockMemDataSel(Addr a);
    return truncate(a >> valueOf(TLog#(MemDataBytes)));
endfunction

// store buffer entry
typedef struct {
    // Each capability-sized payload word has one cancellation condition.
    // This also keeps its tag owned by the same condition as all its bytes.
    Vector#(SBBlockNumMemData, InlineId) inlineIds;
    SBBlockAddr addr;
    SBByteEn byteEn;
    CLine line;
    Bit#(16) pcHash;
} SBEntry deriving(Bits, Eq, FShow);

// result of searching (e.g. load byass)
typedef struct {
    Maybe#(SBIndex) matchIdx;
    InlineId sourceId;
    Maybe#(MemTaggedData) forwardData; // XXX data is not shifted to match load addr offset
} SBSearchRes deriving(Bits, Eq, FShow);

interface StoreBuffer;
    method Bool isEmpty;
    method Maybe#(SBIndex) getEnqIndex(Addr paddr, MemDataByteEn be, InlineId inlineId);
    method Action enq(SBIndex idx, Addr paddr, MemDataByteEn be, MemTaggedData data, Bit#(16) pcHash, InlineId inlineId);
    method ActionValue#(SBEntry) deq(SBIndex idx);
    method ActionValue#(Tuple2#(SBIndex, SBEntry)) issue;
    method SBSearchRes search(Addr paddr, ByteOrTagEn be, InlineId inlineId);
    method SBSearchRes searchMetadata(Addr paddr, ByteOrTagEn be, InlineId inlineId);
    method SBSearchRes searchMetadataSt(Addr paddr, ByteOrTagEn be, InlineId inlineId);
    method SBSearchRes searchInlineId(Addr paddr, InlineId inlineId); // load bypass/stall or atomic inst stall
    method Bool noMatchInlineLdQ(Addr paddr, InlineId inlineId);
    method Bool noMatchInlineStQ(Addr paddr, InlineId inlineId);
    // check no matching entry for AMO/Lr/Sc issue
    // XXX assume BE has been shifted approriately for paddr offset
    // (for load we need to do that before calling the methods)
    method Bool noMatchLdQ(Addr paddr, ByteOrTagEn be);
    method Bool noMatchStQ(Addr paddr, ByteOrTagEn be);
endinterface

/////////////////
// EHR version //
/////////////////
// method ordering: (empty CF issue CF search) < deq < enq
// This is mostly derived from SplitLSQ ordering of issueLd, deqSt,
// wakupLdStalledBySB. LSQ issueLd is called with SB search, LSQ deqSt is
// called with SB enq, and wakupLdStalledBy is called with SB deq. Since
// issueLd < (deqSt CF wakeupStalledBySB), we have search < (deq, enq). SB
// issue to memory is unrelated to other rules, so just put it at the
// beginning. Ordering between deq and enq are not important. We put deq < enq
// to cut of bypassing path. empty is used in ROB commit, so EHR port = 0
(* synthesize *)
module mkStoreBufferEhr(StoreBuffer);
    Integer emptyPort = 0;
    Integer issuePort = 0;
    Integer searchPort = 0;
    Integer deqPort = 0; // write
    Integer enqPort = 1; // write

    // entries with valid bit
    Vector#(SBSize, Ehr#(2, SBEntry)) entry <- replicateM(mkEhr(?));
    Vector#(SBSize, Ehr#(2, Bool)) valid <- replicateM(mkEhr(False));

    // FIFO of entries to be issued to memory
    FIFOF#(SBIndex) issueQ <- mkUGSizedFIFOF(valueOf(SBSize));
    // FIFO of empty entries
    FIFOF#(SBIndex) freeQ <- mkUGSizedFIFOF(valueOf(SBSize));
    // XXX I use UG FIFOs here, because some methods only call enq/deq in a branch
    // compiler may do somthing wrong with guard if the FIFOs are guarded
    // freeQ never overflow or underflow, so no explicit check is needed
    // issueQ never overflow, so notEmpty check is needed

    // freeQ needs initialization
    Reg#(Bool) inited <- mkReg(False);
    Reg#(SBIndex) initIdx <- mkReg(0);
    // Do not attach new waiters to a slot in its completion cycle. This
    // makes the index a stable producer identity until all waiters resolve.
    Wire#(Maybe#(SBIndex)) completing <- mkDWire(Invalid);

    rule initFreeQ(!inited);
        freeQ.enq(initIdx);
        initIdx <= initIdx + 1;
        if(initIdx == fromInteger(valueOf(SBSize) - 1)) begin
            inited <= True;
        end
    endrule

    function Maybe#(Bit#(TLog#(n))) searchIndex(function Bool pred(t x), Vector#(n, t) vec);
        case(findIndex(pred, vec)) matches
            tagged Valid .idx: return Valid (pack(idx));
            default: return Invalid;
        endcase
    endfunction

    function Bool noMatch(Addr paddr, ByteOrTagEn be);
        // input BE has been shifted, just pack it
        Bit#(MemDataBytes) ldBE = pack(be.DataMemAccess);

        // data offset within block
        SBBlockMemDataSel sel = getSBBlockMemDataSel(paddr);

        // helper to extract byteEn from entry
        function Bit#(MemDataBytes) getEntryBE(SBIndex idx);
            Vector#(SBBlockNumMemData, MemDataByteEn) byteEn = unpack(pack(entry[idx][searchPort].byteEn));
            return pack(byteEn[sel]);
        endfunction

        // func to determine whether the load matches a store entry
        function Bool matchEntry(Integer i);
            // entry must be valid, addr should match, byte enable should overlap
            Bool sameAddr = getSBBlockAddr(paddr) == entry[i][searchPort].addr;
            Bool beOverlap = be == TagMemAccess || (ldBE & getEntryBE(fromInteger(i))) != 0;
            return valid[i][searchPort] && sameAddr && beOverlap;
        endfunction

        // find match entry and determine return value
        Vector#(SBSize, Integer) idxVec = genVector;
        return !any(matchEntry, idxVec);
    endfunction

    function SBSearchRes searchEntry(Addr paddr, ByteOrTagEn be, InlineId inlineId);
        // input BE has been shifted, just pack it
        Bit#(MemDataBytes) ldBE = pack(be.DataMemAccess);

        // data offset within block
        SBBlockMemDataSel sel = getSBBlockMemDataSel(paddr);

        // helper to extract byteEn from entry
        function Bit#(MemDataBytes) getEntryBE(SBIndex idx);
            Vector#(SBBlockNumMemData, MemDataByteEn) byteEn = unpack(pack(entry[idx][searchPort].byteEn));
            return pack(byteEn[sel]);
        endfunction

        // func to determine whether the load matches a store entry
        function Bool matchEntry(Integer i);
            // entry must be valid, addr should match, byte enable should overlap
            Bool sameAddr = getSBBlockAddr(paddr) == entry[i][searchPort].addr;
            Bool beOverlap = be == TagMemAccess || (ldBE & getEntryBE(fromInteger(i))) != 0;
            return valid[i][searchPort] && sameAddr && beOverlap;
        endfunction

        // find match entry and determine return value
        Vector#(SBSize, Integer) idxVec = genVector;
        if(searchIndex(matchEntry, idxVec) matches tagged Valid .idx) begin
            // check whether bytes reading are all covered by the entry
            let sourceId = entry[idx][searchPort].inlineIds[sel];
            Bool shareId = sourceId.inLine && sourceId.expected != 0 &&
                !entry[idx][searchPort].byteEn[sourceId.offset] &&
                (inlineId.expected == 0 ||
                 (inlineId.inLine && inlineId.expected == sourceId.expected &&
                  inlineId.offset == sourceId.offset));
            // Checked values may forward, but the load cannot retire until
            // the producer's L1 callback resolves its dependency. Mode 0
            // explicitly opts out of that temporal forwarding guarantee.
            if(be != TagMemAccess && (getEntryBE(idx) & ldBE) == ldBE &&
               (inlineId.forwardUnchecked || sourceId.expected == 0 || shareId)) begin
                // fully covered, forward data
                CLine block = entry[idx][searchPort].line;
                return SBSearchRes {
                    matchIdx: Valid (idx),
                    sourceId: sourceId,
                    forwardData: Valid (MemTaggedData { tag:  block.tag[sel]
                                                      , data: block.data[sel]})
                };
            end
            else begin
                // interact byte, not fully covered, stall the load
                return SBSearchRes {
                    matchIdx: Valid (idx),
                    sourceId: unpack(0),
                    forwardData: Invalid
                };
            end
        end
        else begin
            // load should go to memory
            return SBSearchRes {
                matchIdx: Invalid,
                sourceId: unpack(0),
                forwardData: Invalid
            };
        end
    endfunction

    function SBSearchRes searchInlineEntry(Addr paddr, InlineId inlineId);
        MemDataByteEn idBE = replicate(False);
        idBE[inlineId.offset[3:0]] = True;
        Addr idAddr = (paddr & ~64'h7f) | zeroExtend(inlineId.offset);
        return inlineId.inLine
            ? searchEntry(idAddr, DataMemAccess(idBE), inlineId)
            : SBSearchRes { matchIdx: Invalid, sourceId: unpack(0), forwardData: Invalid };
    endfunction

    method Bool isEmpty;
        function Bool entryEmpty(Integer i);
            return !valid[i][emptyPort];
        endfunction
        Vector#(SBSize, Integer) idxVec = genVector;
        return all(entryEmpty, idxVec);
    endmethod

    method Maybe#(SBIndex) getEnqIndex(Addr paddr, MemDataByteEn be, InlineId inlineId);
        Vector#(SBSize, Integer) idxVec = genVector;
        // first find existing matching entry
        function Bool matchEntry(Integer i);
            return valid[i][enqPort] && entry[i][enqPort].addr == getSBBlockAddr(paddr);
        endfunction
        Maybe#(SBIndex) matchIdx = searchIndex(matchEntry, idxVec);
        if(isValid(matchIdx)) begin
            let old = entry[fromMaybe(?, matchIdx)][enqPort];
            SBBlockMemDataSel sel = getSBBlockMemDataSel(paddr);
            Vector#(SBBlockNumMemData, MemDataByteEn) oldBE = unpack(pack(old.byteEn));
            Vector#(SBBlockNumMemData, MemDataByteEn) newBE = replicate(replicate(False));
            newBE[sel] = be;
            SBByteEn newBytes = unpack(pack(newBE));
            let wordId = old.inlineIds[sel];
            // Differently conditioned writes cannot share a word: canceling
            // the younger write must not lose the older bytes or tag.
            Bool compatible = pack(oldBE[sel]) == 0 ||
                (wordId.expected == inlineId.expected &&
                 wordId.inLine == inlineId.inLine &&
                 (wordId.expected == 0 || wordId.offset == inlineId.offset));
            // All predicates use the pre-write coherent line. Drain whenever
            // one store changes another's predicate, in either age direction.
            // A store writing its own ID must also remain alone.
            if(inlineId.inLine && inlineId.expected != 0) begin
                compatible = compatible && !old.byteEn[inlineId.offset] &&
                             !newBytes[inlineId.offset];
            end
            for(Integer w = 0; w < valueOf(SBBlockNumMemData); w = w + 1) begin
                let oldId = old.inlineIds[w];
                if(pack(oldBE[w]) != 0 && oldId.inLine && oldId.expected != 0)
                    compatible = compatible && !newBytes[oldId.offset] &&
                                 !old.byteEn[oldId.offset];
            end
            return compatible && completing != matchIdx ? matchIdx : Invalid;
        end
        else begin
            // if no existing entry match, then find an empty entry
            return freeQ.notEmpty && completing != Valid(freeQ.first)
                ? Valid (freeQ.first) : Invalid;
        end
    endmethod

    method Action enq(SBIndex idx, Addr paddr, MemDataByteEn be, MemTaggedData d, Bit#(16) pcHash, InlineId inlineId) if(inited);
        // get data offset
        SBBlockMemDataSel sel = getSBBlockMemDataSel(paddr);
        // check whether the entry already exists
        if(valid[idx][enqPort]) begin
            // existing entry: merge
            doAssert(getSBBlockAddr(paddr) == entry[idx][enqPort].addr, "SB enq to existing entry addr should match");
            // update data
            CLine block = entry[idx][enqPort].line;
            block.data[sel] = mergeDataBE(block.data[sel], d.data, be);
            // update tag
            if (pack(be) == ~0) block.tag[sel] = d.tag;
            else if (pack(be) != 0) block.tag[sel] = False;
            // update byte enable
            Vector#(SBBlockNumMemData, MemDataByteEn) byteEn = unpack(pack(entry[idx][enqPort].byteEn));
            byteEn[sel] = unpack(pack(byteEn[sel]) | pack(be));
            let inlineIds = entry[idx][enqPort].inlineIds;
            inlineIds[sel] = inlineId;
            // update entry
            entry[idx][enqPort] <= SBEntry {
                inlineIds: inlineIds,
                addr: getSBBlockAddr(paddr),
                byteEn: unpack(pack(byteEn)),
                line: block,
                pcHash: pcHash
            };
            // this entry must have been sent to issueQ
        end
        else begin
            // new entry: set valid
            valid[idx][enqPort] <= True;
            // setup entry
            CLine block = ?;
            block.data[sel] = d.data;
            if (pack(be) == ~0) block.tag[sel] = d.tag;
            else if (pack(be) != 0) block.tag[sel] = False;
            Vector#(SBBlockNumMemData, MemDataByteEn) byteEn = replicate(replicate(False));
            byteEn[sel] = be;
            Vector#(SBBlockNumMemData, InlineId) inlineIds = replicate(unpack(0));
            inlineIds[sel] = inlineId;
            entry[idx][enqPort] <= SBEntry {
                inlineIds: inlineIds,
                addr: getSBBlockAddr(paddr),
                byteEn: unpack(pack(byteEn)),
                line: block,
                pcHash: pcHash
            };
            // send this entry to issueQ
            doAssert(issueQ.notFull, "SB issueQ should not be full");
            issueQ.enq(idx);
            // remove from freeQ
            doAssert(freeQ.notEmpty, "SB freeQ should not be empty");
            freeQ.deq;
        end
    endmethod

    method ActionValue#(SBEntry) deq(SBIndex idx) if(inited);
        completing <= Valid(idx);
        doAssert(valid[idx][deqPort], "SB deq entry must be valid");
        valid[idx][deqPort] <= False; // set entry to invalid
        freeQ.enq(idx); // recycle entry
        return entry[idx][deqPort];
    endmethod

    method ActionValue#(Tuple2#(SBIndex, SBEntry)) issue if(issueQ.notEmpty);
        issueQ.deq;
        SBIndex idx = issueQ.first;
        return tuple2(idx, entry[idx][issuePort]);
    endmethod

    method SBSearchRes search(Addr paddr, ByteOrTagEn be, InlineId inlineId);
        return searchEntry(paddr, be, inlineId);
    endmethod

    method SBSearchRes searchMetadata(Addr paddr, ByteOrTagEn be, InlineId inlineId);
        // Legacy metadata consumers do not subscribe to producer validation.
        // Only unconditional stores can supply their bytes speculatively.
        let res = searchEntry(paddr, be, inlineId);
        if(res.sourceId.expected != 0) res.forwardData = Invalid;
        return res;
    endmethod

    // Independent read port: load and store metadata request guards both
    // need their SB dependencies without arbitrating a value-method port.
    method SBSearchRes searchMetadataSt(Addr paddr, ByteOrTagEn be, InlineId inlineId);
        let res = searchEntry(paddr, be, inlineId);
        if(res.sourceId.expected != 0) res.forwardData = Invalid;
        return res;
    endmethod

    method SBSearchRes searchInlineId(Addr paddr, InlineId inlineId);
        return searchInlineEntry(paddr, inlineId);
    endmethod

    method Bool noMatchInlineLdQ(Addr paddr, InlineId inlineId);
        return !isValid(searchInlineEntry(paddr, inlineId).matchIdx);
    endmethod

    method Bool noMatchInlineStQ(Addr paddr, InlineId inlineId);
        return !isValid(searchInlineEntry(paddr, inlineId).matchIdx);
    endmethod

    method noMatchLdQ = noMatch;
    method noMatchStQ = noMatch;
endmodule

(* synthesize *)
module mkDummyStoreBuffer(StoreBuffer);
    method Bool isEmpty = True;
    method Maybe#(SBIndex) getEnqIndex(Addr paddr, MemDataByteEn be, InlineId inlineId) = Invalid;
    method Action enq(SBIndex idx, Addr paddr, MemDataByteEn be, MemTaggedData data, Bit#(16) pcHash, InlineId inlineId);
        doAssert(False, "enq should never be called)");
    endmethod
    method ActionValue#(SBEntry) deq(SBIndex idx);
        doAssert(False, "deq should never be called)");
        return ?;
    endmethod
    method ActionValue#(Tuple2#(SBIndex, SBEntry)) issue;
        doAssert(False, "issue should never be called)");
        return ?;
    endmethod
    method SBSearchRes search(Addr paddr, ByteOrTagEn be, InlineId inlineId);
        return SBSearchRes {matchIdx: Invalid, sourceId: unpack(0), forwardData: Invalid};
    endmethod
    method SBSearchRes searchMetadata(Addr paddr, ByteOrTagEn be, InlineId inlineId);
        return SBSearchRes {matchIdx: Invalid, sourceId: unpack(0), forwardData: Invalid};
    endmethod
    method SBSearchRes searchMetadataSt(Addr paddr, ByteOrTagEn be, InlineId inlineId);
        return SBSearchRes {matchIdx: Invalid, sourceId: unpack(0), forwardData: Invalid};
    endmethod
    method SBSearchRes searchInlineId(Addr paddr, InlineId inlineId);
        return SBSearchRes {matchIdx: Invalid, sourceId: unpack(0), forwardData: Invalid};
    endmethod
    method Bool noMatchInlineLdQ(Addr paddr, InlineId inlineId) = True;
    method Bool noMatchInlineStQ(Addr paddr, InlineId inlineId) = True;
    method Bool noMatchLdQ(Addr paddr, ByteOrTagEn be) = True;
    method Bool noMatchStQ(Addr paddr, ByteOrTagEn be) = True;
endmodule
