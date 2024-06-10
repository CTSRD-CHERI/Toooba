// Copyright (c) 2023 Karlis Susters 
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

import ISA_Decls   :: *;
import CrossBar::*;
import GetPut::*;
import RWBramCore::*;
import FIFO::*;
import ConfigReg::*;
import Fifos::*;
import FIFOF::*;
import SpecialFIFOs :: *;
import Ehr::*;
import CacheUtils::*;
import CCTypes::*;
import Types::*;
import Vector::*;
import BuildVector::*;
import ProcTypes::*;
import CHERICap::*;
import CHERICC_Fat::*;

import Prefetcher_intf::*;
import InstructionPrefetchers::*;
import StridePrefetchers::*;
import MarkovPrefetchers::*;
import CheriPrefetchers::*;
import SignaturePathPrefetcher::*;

`define VERBOSE True

module mkDoNothingPrefetcher(Prefetcher);
    method Action reportAccess(Addr addr, HitOrMiss hitMiss);
    endmethod
    method ActionValue#(Addr) getNextPrefetchAddr if (False);
        return 64'h0;
    endmethod
`ifdef PERFORMANCE_MONITORING
    method EventsPrefetcher events;
        return unpack(0);
    endmethod
`endif
endmodule

module mkAlwaysRequestPrefetcher(Prefetcher);
    method Action reportAccess(Addr addr, HitOrMiss hitMiss);
    endmethod
    method ActionValue#(Addr) getNextPrefetchAddr;
        return 64'h8000ff00;
    endmethod
`ifdef PERFORMANCE_MONITORING
    method EventsPrefetcher events;
        return unpack(0);
    endmethod
`endif
endmodule

module mkAlwaysRequestTlbPrefetcher#(DTlbToPrefetcher toTlb)(Prefetcher);
    rule reqTlb;
        $display ("%t Prefetcher req to TLB", $time);
        CapPipe start = almightyCap;
        let cp = setAddr(start, 64'hc000dead);
        toTlb.prefetcherReq(cp.value);
    endrule
    rule asd;
        $display ("%t Prefetcher tlb deqprefetcherresp", $time);
        toTlb.deqPrefetcherResp;
    endrule
    method Action reportAccess(Addr addr, HitOrMiss hitMiss);
        $display ("%t Prefetcher reportAccess %h", $time, addr, fshow(hitMiss));
    endmethod
    method ActionValue#(Addr) getNextPrefetchAddr if (False);
        $display ("%t Prefetcher getNextPrefetchAddr", $time);
        toTlb.deqPrefetcherResp;
        return toTlb.prefetcherResp.paddr;
    endmethod
`ifdef PERFORMANCE_MONITORING
    method EventsPrefetcher events;
        return unpack(0);
    endmethod
`endif
endmodule

module mkPrintPrefetcher(Prefetcher);
    method Action reportAccess(Addr addr, HitOrMiss hitMiss);
        if (hitMiss == HIT) begin
            if (`VERBOSE) $display("%t PrintPrefetcher report HIT %h", $time, addr);
        end
        else begin
            if (`VERBOSE) $display("%t PrintPrefetcher report MISS %h", $time, addr);
        end
    endmethod
    method ActionValue#(Addr) getNextPrefetchAddr if (False);
        return 64'h0;
    endmethod
`ifdef PERFORMANCE_MONITORING
    method EventsPrefetcher events;
        return unpack(0);
    endmethod
`endif
endmodule


module mkPCPrefetcherAdapter#(module#(Prefetcher) mkPrefetcher)(PCPrefetcher);
    let p <- mkPrefetcher;
    method Action reportAccess(Addr addr, Bit#(16) pcHash, HitOrMiss hitMiss);
        p.reportAccess(addr, hitMiss);
    endmethod
    method ActionValue#(Addr) getNextPrefetchAddr;
        let x <- p.getNextPrefetchAddr;
        return x;
    endmethod
`ifdef PERFORMANCE_MONITORING
    method EventsPrefetcher events;
        return p.events;
    endmethod
`endif
endmodule

module mkCheriPCPrefetcherAdapter#(module#(PCPrefetcher) mkPrefetcher)(CheriPCPrefetcher);
    let p <- mkPrefetcher;
    method Action reportAccess(Addr addr, PCHash pcHash, HitOrMiss hitMiss, 
        Addr boundsOffset, Addr boundsLength, Addr boundsVirtBase, Bit#(31) capPerms);
        p.reportAccess(addr, hash(pcHash), hitMiss);
    endmethod
    method Action reportCacheDataArrival(CLine lineWithTags, Addr accessAddr, PCHash pcHash, Bool wasMiss, Bool wasPrefetch, 
        Addr boundsOffset, Addr boundsLength, Addr boundsVirtBase, Bit#(31) capPerms);
    endmethod
    method ActionValue#(Tuple2#(Addr, CapPipe)) getNextPrefetchAddr;
        let addr <- p.getNextPrefetchAddr;
        return tuple2(addr, almightyCap);
    endmethod
`ifdef PERFORMANCE_MONITORING
    method EventsPrefetcher events;
        return p.events;
    endmethod
`endif
endmodule

module mkDoNothingPCPrefetcher(PCPrefetcher);
    method Action reportAccess(Addr addr, Bit#(16) pcHash, HitOrMiss hitMiss);
    endmethod
    method ActionValue#(Addr) getNextPrefetchAddr if (False);
        return 64'h0000000080000080;
    endmethod
`ifdef PERFORMANCE_MONITORING
    method EventsPrefetcher events;
        return unpack(0);
    endmethod
`endif
endmodule

module mkPrintPCPrefetcher(PCPrefetcher);
    method Action reportAccess(Addr addr, Bit#(16) pcHash, HitOrMiss hitMiss);
        if (hitMiss == HIT)
            if (`VERBOSE) $display("%t PCPrefetcher report HIT %h", $time, addr);
        else
            if (`VERBOSE) $display("%t PCPrefetcher report MISS %h", $time, addr);
    endmethod
    method ActionValue#(Addr) getNextPrefetchAddr if (False);
        return 64'h0000000080000080;
    endmethod
`ifdef PERFORMANCE_MONITORING
    method EventsPrefetcher events;
        return unpack(0);
    endmethod
`endif
endmodule

interface PrefetcherVector#(numeric type size);
    method ActionValue#(Tuple2#(Addr, Bit#(TLog#(size)))) getNextPrefetchAddr;
    method Action reportAccess(Bit#(TLog#(size)) idx, Addr addr, HitOrMiss hitMiss);
`ifdef PERFORMANCE_MONITORING //Currently configured to return events from the 0th prefetcher
    method EventsPrefetcher events();
`endif
endinterface

module mkPrefetcherVector#(module#(Prefetcher) mkPrefetcher)
(
    PrefetcherVector#(size)
) provisos (
    Alias#(idxT, Bit#(TLog#(size)))
);
    Vector#(size, Prefetcher) prefetchers <- replicateM(mkPrefetcher);
    Fifo#(1, Tuple2#(Addr, idxT)) prefetchRq <- mkBypassFifo;

    function XBarDstInfo#(Bit#(0),Tuple2#(Addr, idxT)) convertPrefetchRq(idxT item, Addr a);
        return XBarDstInfo { 
            idx: 0,
            data: tuple2(a, item)
        };
    endfunction
    function Get#(Addr) reqGet(Prefetcher p) = toGet(p.getNextPrefetchAddr);
    mkXBar(convertPrefetchRq, map(reqGet, prefetchers), vec(toPut(prefetchRq)));

    method ActionValue#(Tuple2#(Addr, idxT)) getNextPrefetchAddr;
        prefetchRq.deq;
        return prefetchRq.first;
    endmethod

    method Action reportAccess(idxT idx, Addr addr, HitOrMiss hitMiss);
        prefetchers[idx].reportAccess(addr, hitMiss);
    endmethod

`ifdef PERFORMANCE_MONITORING
    method EventsPrefetcher events;
    //IMPORTANT design to get events only from Core 0
        return prefetchers[0].events;
    endmethod
`endif
endmodule

module mkPrefetcherDoubler#(module#(CheriPCPrefetcher) mkPrefetcher1, module#(CheriPCPrefetcher) mkPrefetcher2)
    (CheriPCPrefetcher) 
provisos ();
    CheriPCPrefetcher p1 <- mkPrefetcher1;
    CheriPCPrefetcher p2 <- mkPrefetcher2;
    Fifo#(1, Tuple2#(Addr, CapPipe)) prefetchRq <- mkBypassFifo;
    Reg#(Addr) lastPrefetch <- mkConfigReg(0);
    Reg#(Addr) lastPrefetch2 <- mkConfigReg(0);

    rule getFromP1;
        let x <- p1.getNextPrefetchAddr;
        if (lastPrefetch != tpl_1(x) && lastPrefetch2 != tpl_1(x)) begin
            prefetchRq.enq(x);
        end
    endrule
    rule getFromP2;
        let x <- p2.getNextPrefetchAddr;
        if (lastPrefetch != tpl_1(x) && lastPrefetch2 != tpl_1(x)) begin
            prefetchRq.enq(x);
        end
    endrule

    method ActionValue#(Tuple2#(Addr, CapPipe)) getNextPrefetchAddr;
        prefetchRq.deq;
        lastPrefetch2 <= lastPrefetch;
        lastPrefetch <= tpl_1(prefetchRq.first);
        return prefetchRq.first;
    endmethod

    method Action reportAccess(Addr addr, PCHash pcHash, HitOrMiss hitMiss, 
        Addr boundsOffset, Addr boundsLength, Addr boundsVirtBase, Bit#(31) capPerms);

        p1.reportAccess(addr, pcHash, hitMiss, boundsOffset, boundsLength, boundsVirtBase, capPerms);
        p2.reportAccess(addr, pcHash, hitMiss, boundsOffset, boundsLength, boundsVirtBase, capPerms);
    endmethod

    method Action reportCacheDataArrival(CLine lineWithTags, Addr addr, PCHash pcHash, 
        Bool wasMiss, Bool wasPrefetch, Addr boundsOffset, Addr boundsLength, Addr boundsVirtBase, Bit#(31) capPerms);

        p1.reportCacheDataArrival(lineWithTags, addr, pcHash, wasMiss, wasPrefetch, boundsOffset, boundsLength, boundsVirtBase, capPerms);
        p2.reportCacheDataArrival(lineWithTags, addr, pcHash, wasMiss, wasPrefetch, boundsOffset, boundsLength, boundsVirtBase, capPerms);
    endmethod

`ifdef PERFORMANCE_MONITORING
    method EventsPrefetcher events;
        return p1.events;
    endmethod
`endif
endmodule

module mkL1IPrefetcher(Prefetcher);
`ifdef INSTR_PREFETCHER_IN_L1
    `ifdef INSTR_PREFETCHER_NEXT_LINE_ON_ALL
        Parameter#(1) lines <- mkParameter;
        let m <- mkNextLineOnAllPrefetcher(lines);
    `elsif INSTR_PREFETCHER_NEXT_LINE_ON_MISS
        Parameter#(1) lines <- mkParameter;
        let m <-  mkNextLineOnMissPrefetcher(lines);
    `elsif INSTR_PREFETCHER_SINGLE_WINDOW
        Parameter#(3) lines <- mkParameter;
        let m <-  mkSingleWindowPrefetcher(lines);
    `elsif INSTR_PREFETCHER_SINGLE_WINDOW_TARGET
        Parameter#(16) numLastRequests <- mkParameter;
        Parameter#(1) cacheLinesInRange <- mkParameter;
        let m <-  mkSingleWindowTargetPrefetcher(numLastRequests, cacheLinesInRange);
    `elsif INSTR_PREFETCHER_MULTI_WINDOW
        Parameter#(4) numWindows <- mkParameter;
        Parameter#(2) lines <- mkParameter;
        let m <-  mkMultiWindowPrefetcher(numWindows, lines);
    `elsif INSTR_PREFETCHER_MULTI_WINDOW_TARGET
        Parameter#(4) numWindows <- mkParameter;
        Parameter#(16) numLastRequests <- mkParameter;
        Parameter#(16) cacheLinesInRange <- mkParameter;
        let m <-  mkMultiWindowTargetPrefetcher(numWindows, numLastRequests, cacheLinesInRange);
    `endif
`else
    let m <- mkDoNothingPrefetcher;
`endif
    return m;
endmodule

module mkLLIPrefetcherInL1I(Prefetcher);
`ifdef INSTR_PREFETCHER_IN_L1LL
    `ifdef INSTR_PREFETCHER_NEXT_LINE_ON_ALL
        Parameter#(1) lines <- mkParameter;
        let m <-  mkNextLineOnAllPrefetcher(lines);
    `elsif INSTR_PREFETCHER_NEXT_LINE_ON_MISS
        Parameter#(1) lines <- mkParameter;
        let m <-  mkNextLineOnMissPrefetcher(lines);
    `elsif INSTR_PREFETCHER_SINGLE_WINDOW
        Parameter#(3) lines <- mkParameter;
        let m <-  mkSingleWindowL1LLPrefetcher(lines);
    `elsif INSTR_PREFETCHER_SINGLE_WINDOW_TARGET
        Parameter#(16) numLastRequests <- mkParameter;
        Parameter#(1) cacheLinesInRange <- mkParameter;
        let m <-  mkSingleWindowTargetPrefetcher(numLastRequests, cacheLinesInRange);
    `elsif INSTR_PREFETCHER_MULTI_WINDOW
        Parameter#(4) numWindows <- mkParameter;
        Parameter#(2) lines <- mkParameter;
        let m <-  mkMultiWindowPrefetcher(numWindows, lines);
    `elsif INSTR_PREFETCHER_MULTI_WINDOW_TARGET
        Parameter#(4) numWindows <- mkParameter;
        Parameter#(16) numLastRequests <- mkParameter;
        Parameter#(3) cacheLinesInRange <- mkParameter;
        let m <-  mkMultiWindowTargetPrefetcher(numWindows, numLastRequests, cacheLinesInRange);
    `endif
`else
    let m <- mkDoNothingPrefetcher;
`endif
    return m;
endmodule

module mkLLIPrefetcher(Prefetcher);
`ifdef INSTR_PREFETCHER_IN_LL
    `ifdef INSTR_PREFETCHER_NEXT_LINE_ON_ALL
        Parameter#(1) lines <- mkParameter;
        let m <-  mkNextLineOnAllPrefetcher(lines);
    `elsif INSTR_PREFETCHER_NEXT_LINE_ON_MISS
        Parameter#(1) lines <- mkParameter;
        let m <-  mkNextLineOnMissPrefetcher(lines);
    `elsif INSTR_PREFETCHER_SINGLE_WINDOW
        Parameter#(3) lines <- mkParameter;
        let m <-  mkSingleWindowPrefetcher(lines);
    `elsif INSTR_PREFETCHER_SINGLE_WINDOW_TARGET
        Parameter#(16) numLastRequests <- mkParameter;
        Parameter#(1) cacheLinesInRange <- mkParameter;
        let m <-  mkSingleWindowTargetPrefetcher(numLastRequests, cacheLinesInRange);
    `elsif INSTR_PREFETCHER_MULTI_WINDOW
        Parameter#(4) numWindows <- mkParameter;
        Parameter#(2) lines <- mkParameter;
        let m <-  mkMultiWindowPrefetcher(numWindows, lines);
    `elsif INSTR_PREFETCHER_MULTI_WINDOW_TARGET
        Parameter#(4) numWindows <- mkParameter;
        Parameter#(16) numLastRequests <- mkParameter;
        Parameter#(3) cacheLinesInRange <- mkParameter;
        let m <-  mkMultiWindowTargetPrefetcher(numWindows, numLastRequests, cacheLinesInRange);
    `endif
`else
    let m <- mkDoNothingPrefetcher;
`endif
    return m;
endmodule

module mkL1DPrefetcher#(DTlbToPrefetcher toTlb)(CheriPCPrefetcher);
`ifdef DATA_PREFETCHER_IN_L1
    `ifdef DATA_PREFETCHER_BLOCK
        Parameter#(1) numLinesEachWay <- mkParameter;
        let m <- mkCheriPCPrefetcherAdapter(mkPCPrefetcherAdapter(mkBlockPrefetcher(numLinesEachWay)));
    `elsif DATA_PREFETCHER_STRIDE
        //let m <- mkStridePCPrefetcher;
        Parameter#(512) strideTableSize <- mkParameter;
        Parameter#(1) cLinesAheadToPrefetch <- mkParameter;
        let m <- mkCheriPCPrefetcherAdapter(mkStride2PCPrefetcher(strideTableSize, cLinesAheadToPrefetch));
    `elsif DATA_PREFETCHER_STRIDE_ADAPTIVE
        Parameter#(512) strideTableSize <- mkParameter;
        Parameter#(1) cLinesPrefetchMin <- mkParameter;
        Parameter#(2) cLinesSmallStridePrefetchMax <- mkParameter;
        Parameter#(4) cLinesBigStridePrefetchMax <- mkParameter;
        let m <- mkCheriPCPrefetcherAdapter(mkStrideAdaptivePCPrefetcher(
            strideTableSize, 
            cLinesPrefetchMin, 
            cLinesSmallStridePrefetchMax, 
            cLinesBigStridePrefetchMax));
    `elsif DATA_PREFETCHER_MARKOV
        Parameter#(2) maxChainLength <- mkParameter;
        Parameter#(2048) narrowEntries <- mkParameter;
        Parameter#(128) wideEntries <- mkParameter;
        let m <- mkCheriPCPrefetcherAdapter(mkPCPrefetcherAdapter(mkMarkovPrefetcher(maxChainLength, narrowEntries, wideEntries)));
    `elsif DATA_PREFETCHER_MARKOV_ON_HIT
        Parameter#(1) maxChainLength <- mkParameter;
        Parameter#(32) numLastRequestsTracked <- mkParameter;
        let m <- mkCheriPCPrefetcherAdapter(mkPCPrefetcherAdapter(mkMarkovOnHitPrefetcher(maxChainLength, numLastRequestsTracked)));
    `elsif DATA_PREFETCHER_MARKOV_ON_HIT_2
        Parameter#(1) maxChainLength <- mkParameter;
        Parameter#(32) numLastRequestsTracked <- mkParameter;
        let m <- mkCheriPCPrefetcherAdapter(mkPCPrefetcherAdapter(mkMarkovOnHit2Prefetcher(maxChainLength, numLastRequestsTracked)));
    `elsif DATA_PREFETCHER_ALL_IN_CAP
        Parameter#(256) maxCapSizeToPrefetch <- mkParameter;
        let m <- mkAllInCapPrefetcher(maxCapSizeToPrefetch);
    `elsif DATA_PREFETCHER_CHERI_STRIDE
        Parameter#(512) strideTableSize <- mkParameter;
        Parameter#(3) cLinesAheadToPrefetch <- mkParameter;
        Parameter#(1) pcInHash <- mkParameter;
        Parameter#(0) boundsInHash <- mkParameter;
        let m <- mkCheriStridePrefetcher(toTlb, strideTableSize, cLinesAheadToPrefetch, pcInHash, boundsInHash);
        //let m <- mkCheriPCPrefetcherAdapter(mkPCPrefetcherAdapter(mkDoNothingPrefetcher));
        //let m <- mkCheriPCPrefetcherAdapter(mkPCPrefetcherAdapter(mkAlwaysRequestTlbPrefetcher(toTlb)));
    `elsif DATA_PREFETCHER_CHERI_STRIDE_MIX
        Parameter#(512) strideTableSize <- mkParameter;
        Parameter#(4) cLinesAheadToPrefetch <- mkParameter;
        Parameter#(1) pcInHash <- mkParameter;
        Parameter#(0) pcNotInHash <- mkParameter;
        Parameter#(1) boundsInHash <- mkParameter;
        Parameter#(0) boundsNotInHash <- mkParameter;
        let m1 = mkCheriStridePrefetcher(toTlb, strideTableSize, cLinesAheadToPrefetch, pcInHash, boundsNotInHash);
        let m2 = mkCheriStridePrefetcher(toTlb, strideTableSize, cLinesAheadToPrefetch, pcNotInHash, boundsInHash);
        let m <- mkPrefetcherDoubler(m1, m2);
        //let m <- mkCheriPCPrefetcherAdapter(mkPCPrefetcherAdapter(mkDoNothingPrefetcher));
        //let m <- mkCheriPCPrefetcherAdapter(mkPCPrefetcherAdapter(mkAlwaysRequestTlbPrefetcher(toTlb)));
    `elsif DATA_PREFETCHER_CAP_SPATIAL
        Parameter#(32768) maxCapSizeToTrack <- mkParameter;
        Parameter#(256) bitmapTableSize <- mkParameter;
        Parameter#(32) filterTableSize <- mkParameter;
        Parameter#(16) inverseDecayChance <- mkParameter;
        let m <- mkCapBitmapPrefetcher(maxCapSizeToTrack, bitmapTableSize, filterTableSize, inverseDecayChance);
    `elsif DATA_PREFETCHER_CAP_PTR
        Parameter#(4096) ptrTableSize <- mkParameter; 
        Parameter#(64) trainingTableSize <- mkParameter;
        Parameter#(4) inverseDecayChance <- mkParameter;
        let m <- mkCapPtrPrefetcher(toTlb, ptrTableSize, trainingTableSize, inverseDecayChance);
    `elsif DATA_PREFETCHER_SPP
        Parameter#(64) stSets <- mkParameter;
        Parameter#(4) stWays <- mkParameter;
        Parameter#(512) ptEntries <- mkParameter;
        Prob prefetchThreshold = 7'b1100000;
        Bool useFilter = True;
        let m <- mkCheriPCPrefetcherAdapter(mkPCPrefetcherAdapter(mkSignaturePathPrefetcher(
            "./div_table.memhex",
            stSets, stWays, ptEntries, prefetchThreshold, useFilter)));
        //let m <- mkCheriPCPrefetcherAdapter(mkPCPrefetcherAdapter(mkPrintPrefetcher));
    `elsif DATA_PREFETCHER_MEASURER
        let m <- mkPCCapMeasurer;
    `endif
`else 
    let m <- mkCheriPCPrefetcherAdapter(mkPCPrefetcherAdapter(mkDoNothingPrefetcher));
    // Parameter#(512) strideTableSize <- mkParameter;
    // Parameter#(2) cLinesAheadToPrefetch <- mkParameter;
    // let m <- mkCheriPCPrefetcherAdapter(mkStride2PCPrefetcher(strideTableSize, cLinesAheadToPrefetch));
`endif
    return m;
endmodule

module mkLLDPrefetcherInL1D#(DTlbToPrefetcher toTlb)(CheriPCPrefetcher);
`ifdef DATA_PREFETCHER_IN_L1LL
    `ifdef DATA_PREFETCHER_BLOCK
        Parameter#(1) numLinesEachWay <- mkParameter;
        let m <- mkCheriPCPrefetcherAdapter(mkPCPrefetcherAdapter(mkBlockPrefetcher(numLinesEachWay)));
    `elsif DATA_PREFETCHER_STRIDE
        Parameter#(512) strideTableSize <- mkParameter;
        Parameter#(2) cLinesAheadToPrefetch <- mkParameter;
        let m <- mkCheriPCPrefetcherAdapter(mkStride2PCPrefetcher(strideTableSize, cLinesAheadToPrefetch));
    `elsif DATA_PREFETCHER_STRIDE_ADAPTIVE
        Parameter#(512) strideTableSize <- mkParameter;
        Parameter#(1) cLinesPrefetchMin <- mkParameter;
        Parameter#(2) cLinesSmallStridePrefetchMax <- mkParameter;
        Parameter#(4) cLinesBigStridePrefetchMax <- mkParameter;
        let m <- mkCheriPCPrefetcherAdapter(mkStrideAdaptivePCPrefetcher(
            strideTableSize, 
            cLinesPrefetchMin, 
            cLinesSmallStridePrefetchMax, 
            cLinesBigStridePrefetchMax));
    `elsif DATA_PREFETCHER_MARKOV
        Parameter#(2) maxChainLength <- mkParameter;
        Parameter#(2048) narrowEntries <- mkParameter;
        Parameter#(128) wideEntries <- mkParameter;
        let m <- mkCheriPCPrefetcherAdapter(mkPCPrefetcherAdapter(mkMarkovPrefetcher(maxChainLength, narrowEntries, wideEntries)));
    `elsif DATA_PREFETCHER_MARKOV_ON_HIT
        Parameter#(1) maxChainLength <- mkParameter;
        Parameter#(32) numLastRequestsTracked <- mkParameter;
        let m <- mkCheriPCPrefetcherAdapter(mkPCPrefetcherAdapter(mkMarkovOnHitPrefetcher(maxChainLength, numLastRequestsTracked)));
    `elsif DATA_PREFETCHER_MARKOV_ON_HIT_2
        Parameter#(1) maxChainLength <- mkParameter;
        Parameter#(32) numLastRequestsTracked <- mkParameter;
        let m <- mkCheriPCPrefetcherAdapter(mkPCPrefetcherAdapter(mkMarkovOnHit2Prefetcher(maxChainLength, numLastRequestsTracked)));
    `elsif DATA_PREFETCHER_ALL_IN_CAP
        Parameter#(256) maxCapSizeToPrefetch <- mkParameter;
        let m <- mkAllInCapPrefetcher(maxCapSizeToPrefetch);
    `elsif DATA_PREFETCHER_CHERI_STRIDE
        Parameter#(512) strideTableSize <- mkParameter;
        Parameter#(1) cLinesAheadToPrefetch <- mkParameter;
        Parameter#(1) pcInHash <- mkParameter;
        Parameter#(0) boundsInHash <- mkParameter;
        let m <- mkCheriStridePrefetcher(toTlb, strideTableSize, cLinesAheadToPrefetch, pcInHash, boundsInHash);
        //let m <- mkCheriPCPrefetcherAdapter(mkPCPrefetcherAdapter(mkDoNothingPrefetcher));
    `elsif DATA_PREFETCHER_CAP_SPATIAL
        Parameter#(4096) maxCapSizeToTrack <- mkParameter;
        Parameter#(2048) bitmapTableSize <- mkParameter;
        Parameter#(128) filterTableSize <- mkParameter;
        Parameter#(128) inverseDecayChance <- mkParameter;
        let m <- mkCapBitmapPrefetcher(maxCapSizeToTrack, bitmapTableSize, filterTableSize, inverseDecayChance);
    `elsif DATA_PREFETCHER_CAP_PTR
        Parameter#(4096) ptrTableSize <- mkParameter; 
        Parameter#(64) trainingTableSize <- mkParameter;
        Parameter#(4) inverseDecayChance <- mkParameter;
        let m <- mkCapPtrPrefetcher(toTlb, ptrTableSize, trainingTableSize, inverseDecayChance);
    `elsif DATA_PREFETCHER_CAP_SPATIAL_PTR
        Parameter#(4096) ptrTableSize <- mkParameter; 
        Parameter#(64) trainingTableSize <- mkParameter;
        Parameter#(4) inverseDecayChancePtr <- mkParameter;
        let m1 = mkCapPtrPrefetcher(toTlb, ptrTableSize, trainingTableSize, inverseDecayChancePtr);

        Parameter#(1048576) maxCapSizeToTrack <- mkParameter;
        Parameter#(2048) bitmapTableSize <- mkParameter;
        Parameter#(128) filterTableSize <- mkParameter;
        Parameter#(128) inverseDecayChanceSpatial <- mkParameter;
        let m2 = mkCapBitmapPrefetcher(maxCapSizeToTrack, bitmapTableSize, filterTableSize, inverseDecayChanceSpatial);

        let m <- mkPrefetcherDoubler(m1, m2);
    `elsif DATA_PREFETCHER_SPP
        Parameter#(64) stSets <- mkParameter;
        Parameter#(4) stWays <- mkParameter;
        Parameter#(512) ptEntries <- mkParameter;
        Prob prefetchThreshold = 7'b1100000;
        Bool useFilter = True;
        let m <- mkCheriPCPrefetcherAdapter(mkPCPrefetcherAdapter(mkSignaturePathPrefetcher(
            "./div_table.memhex",
            stSets, stWays, ptEntries, prefetchThreshold, useFilter)));
    `endif
`else 
    let m <- mkCheriPCPrefetcherAdapter(mkPCPrefetcherAdapter(mkDoNothingPrefetcher));
`endif
    return m;
endmodule

module mkLLDPrefetcher(Prefetcher);
`ifdef DATA_PREFETCHER_IN_LL
    `ifdef DATA_PREFETCHER_BLOCK
        Parameter#(1) numLinesEachWay <- mkParameter;
        let m <- mkBlockPrefetcher(numLinesEachWay);
    `elsif DATA_PREFETCHER_STRIDE
        doAssert(False, "Illegal data prefetcher type for LL cache!");
    `elsif DATA_PREFETCHER_STRIDE_ADAPTIVE
        doAssert(False, "Illegal data prefetcher type for LL cache!");
    `elsif DATA_PREFETCHER_MARKOV
        Parameter#(2) maxChainLength <- mkParameter;
        Parameter#(2048) narrowEntries <- mkParameter;
        Parameter#(128) wideEntries <- mkParameter;
        let m <- mkMarkovPrefetcher(maxChainLength, narrowEntries, wideEntries);
    `elsif DATA_PREFETCHER_MARKOV_ON_HIT
        Parameter#(1) maxChainLength <- mkParameter;
        Parameter#(32) numLastRequestsTracked <- mkParameter;
        let m <- mkMarkovOnHitPrefetcher(maxChainLength, numLastRequestsTracked);
    `elsif DATA_PREFETCHER_MARKOV_ON_HIT_2
        Parameter#(1) maxChainLength <- mkParameter;
        Parameter#(32) numLastRequestsTracked <- mkParameter;
        let m <- mkMarkovOnHit2Prefetcher(maxChainLength, numLastRequestsTracked);
    `elsif DATA_PREFETCHER_ALL_IN_CAP
        doAssert(False, "Illegal data prefetcher type for LL cache!");
    `elsif DATA_PREFETCHER_SPP
        Parameter#(64) stSets <- mkParameter;
        Parameter#(4) stWays <- mkParameter;
        Parameter#(512) ptEntries <- mkParameter;
        Prob prefetchThreshold = 7'b0100000;
        Bool useFilter = True;
        let m <- mkSignaturePathPrefetcher(
            "./div_table.memhex",
            stSets, stWays, ptEntries, prefetchThreshold, useFilter);
    `endif
`else 
    let m <- mkDoNothingPrefetcher;
`endif
    return m;
endmodule