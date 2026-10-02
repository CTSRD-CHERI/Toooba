
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

import Connectable::*;
import Vector::*;
import BuildVector::*;
import GetPut::*;
import Types::*;
import ProcTypes::*;
import CacheUtils::*;
import CCTypes::*;
import L1CoCache::*;
import LLCache::*;
import CrossBar::*;
import Fifos::*;

// Access-width transport flits repeat metadata so the link remains
// independently routable and can later support interleaving.

module mkL1LLConnect#(
    ParentCacheToChild#(L1Way, LLChild) llc,
    Vector#(L1Num, ChildCacheToParent#(L1Way, void)) l1
)(Empty);
    // connect cRq
    function XBarDstInfo#(Bit#(0), CRqMsg#(L1Way, LLChild)) getCRqDst(LLChild child, CRqMsg#(L1Way, void) r);
        return XBarDstInfo {
            idx: 0,
            data: CRqMsg {
                addr: r.addr,
                fromState: r.fromState,
                toState: r.toState,
                canUpToE: r.canUpToE,
                id: r.id,
                child: child,
                isPrefetchRq: r.isPrefetchRq
            }
        };
    endfunction
    function Get#(CRqMsg#(L1Way, void)) cRqGet(ChildCacheToParent#(L1Way, void) ifc) = toGet(ifc.rqToP);
    mkXBar(getCRqDst, map(cRqGet, l1), vec(toPut(llc.rqFromC)));

    Fifo#(2, CRsAccessMsg#(LLChild)) cRsLinkQ <- mkCFFifo;
`ifdef SELF_INV_CACHE
    // Compatibility path: self-invalidating caches still return whole lines.
    Vector#(L1Num, Fifo#(1, CRsAccessMsg#(LLChild))) cRsAccessQ <- replicateM(mkBypassFifo);
    Vector#(L1Num, Reg#(CLineAccessSel)) cRsAccess <- replicateM(mkReg(0));
    for(Integer i = 0; i < valueof(L1Num); i = i+1) begin
        rule serializeCRs;
            let r = l1[i].rsToP.first;
            Bool hasData = isValid(r.data);
            Bool last = !hasData || cRsAccess[i] == fromInteger(valueOf(CLineNumAccesses) - 1);
            Maybe#(CLineAccess) accessData = Invalid;
            if (hasData)
                accessData = Valid(clineToAccessVector(validValue(r.data))[cRsAccess[i]]);
            cRsAccessQ[i].enq(CRsAccessMsg {
                addr: r.addr, toState: r.toState, data: accessData,
                access: cRsAccess[i], last: last, child: fromInteger(i)
            });
            if (last) begin
                l1[i].rsToP.deq;
                cRsAccess[i] <= 0;
            end
            else
                cRsAccess[i] <= cRsAccess[i] + 1;
        endrule
    end
    function XBarDstInfo#(Bit#(0), CRsAccessMsg#(LLChild)) getLegacyCRsAccessDst(LLChild child, CRsAccessMsg#(LLChild) r);
        return XBarDstInfo {idx: 0, data: r};
    endfunction
    function Get#(CRsAccessMsg#(LLChild)) legacyCRsAccessGet(Fifo#(1, CRsAccessMsg#(LLChild)) f) = toGet(f);
    mkXBar(getLegacyCRsAccessDst, map(legacyCRsAccessGet, cRsAccessQ), vec(toPut(cRsLinkQ)));
`else
    // Normal coherent caches source access-width flits directly from MSHRs.
    // Fairly acquire one child and retain ownership until its final flit because
    // the LLC start/put interface accepts exactly one logical response at a time.
    Reg#(Maybe#(LLChild)) cRsOwner <- mkReg(Invalid);
    Reg#(LLChild) cRsNext <- mkReg(0);
    rule arbitrateCRsAccess;
        Maybe#(LLChild) selected = cRsOwner;
        Bool found = isValid(selected);
        if (!found) begin
            for (Integer i = 0; i < valueof(L1Num); i = i+1) begin
                if (!found && cRsNext <= fromInteger(i)
                    && l1[i].rsAccessToP.notEmpty) begin
                    selected = Valid(fromInteger(i));
                    found = True;
                end
            end
            for (Integer i = 0; i < valueof(L1Num); i = i+1) begin
                if (!found && fromInteger(i) < cRsNext
                    && l1[i].rsAccessToP.notEmpty) begin
                    selected = Valid(fromInteger(i));
                    found = True;
                end
            end
        end
        if (selected matches tagged Valid .child) begin
            let r = l1[child].rsAccessToP.first;
            l1[child].rsAccessToP.deq;
            cRsLinkQ.enq(CRsAccessMsg {
                addr: r.addr, toState: r.toState, data: r.data,
                access: r.access, last: r.last, child: child
            });
            if (r.last) begin
                cRsOwner <= Invalid;
                cRsNext <= child == fromInteger(valueof(L1Num) - 1) ? 0 : child + 1;
            end
            else begin
                cRsOwner <= Valid(child);
            end
        end
    endrule
`endif

    rule forwardCRsAccess;
        llc.rsAccessFromC.enq(cRsLinkQ.first);
        cRsLinkQ.deq;
    endrule

`ifdef SELF_INV_CACHE
    // SELF_INV retains the legacy whole-line parent response path.
    for(Integer i = 0; i < valueof(L1Num); i = i+1) begin
        rule sendLegacyFromP(llc.toC.first matches tagged PRq .rq
                             &&& rq.child == fromInteger(i));
            llc.toC.deq;
            l1[i].fromP.enq(PRq (PRqMsg {
                addr: rq.addr, toState: rq.toState, child: ?
            }));
        endrule
        rule sendLegacyPRs(llc.toC.first matches tagged PRs .rs
                           &&& rs.child == fromInteger(i));
            llc.toC.deq;
            l1[i].fromP.enq(PRs (PRsMsg {
                addr: rs.addr, toState: rs.toState, child: ?,
                data: rs.data, id: rs.id
            }));
        endrule
    end
`else
    // Normal coherent responses are already access-width at the LLC.  Lock the
    // selected destination for the complete burst (the LLC currently emits one
    // stream at a time) and forward without transient Line assembly.
    Reg#(Maybe#(LLChild)) pRsOwner <- mkReg(Invalid);
    for(Integer i = 0; i < valueof(L1Num); i = i+1) begin
        rule sendPRq(llc.toC.first matches tagged PRq .rq
                     &&& rq.child == fromInteger(i)
                     &&& !isValid(pRsOwner)
                     &&& !llc.rsAccessToC.notEmpty);
            llc.toC.deq;
            l1[i].fromP.enq(PRq (PRqMsg {
                addr: rq.addr, toState: rq.toState, child: ?
            }));
        endrule

        rule forwardPRsAccess(llc.rsAccessToC.first.child == fromInteger(i)
                              &&& (!isValid(pRsOwner)
                                   || pRsOwner == Valid(fromInteger(i))));
            let r = llc.rsAccessToC.first;
            doAssert(isValid(pRsOwner) || r.access == 0,
                     "LL parent response burst did not start at access zero");
            llc.rsAccessToC.deq;
            l1[i].rsAccessFromP.enq(PRsAccessMsg {
                addr: r.addr, toState: r.toState, data: r.data,
                access: r.access, last: r.last, child: ?, id: r.id
            });
            pRsOwner <= r.last ? Invalid : Valid(fromInteger(i));
        endrule
    end
`endif
endmodule

/*
module mkL1LLConnect#(
    ParentCacheToChild#(L1Way, LLChild) llc,
    ChildCacheToParent#(L1Way, void) dCache,
    ChildCacheToParent#(L1Way, void) iCache
)(Empty);
    LLChild dChild = 0;

    // D$
    // send cRq to P: D$ has priority
    rule doRqFromDCToP;
        let r <- toGet(dCache.rqToP).get;
        llc.rqFromC.enq(CRqMsg {
            addr: r.addr,
            fromState: r.fromState,
            toState: r.toState,
            id: r.id,
            child: dChild
        });
    endrule

    // send cRs to P: D$ has priority
    rule doRsFromDCToP;
        let r <- toGet(dCache.rsToP).get;
        llc.rsFromC.enq(CRsMsg {
            addr: r.addr,
            toState: r.toState,
            data: r.data,
            child: dChild
        });
    endrule

    // send pRs to C
    rule doRsFromPToDC(llc.toC.first matches tagged PRs .rs &&& rs.child == dChild);
        llc.toC.deq;
        dCache.fromP.enq(PRs (PRsMsg {
            addr: rs.addr,
            toState: rs.toState,
            child: ?,
            data: rs.data,
            id: rs.id
        }));
    endrule

    // send pRq to C
    rule doRqFromPToDC(llc.toC.first matches tagged PRq .rq &&& rq.child == dChild);
        llc.toC.deq;
        dCache.fromP.enq(PRq (PRqMsg {
            addr: rq.addr,
            toState: rq.toState,
            child: ?
        }));
    endrule

    // I$
    LLChild iChild = 1;

    (* descending_urgency = "doRqFromDCToP, doRqFromICToP" *)
    rule doRqFromICToP;
        let r <- toGet(iCache.rqToP).get;
        llc.rqFromC.enq(CRqMsg {
            addr: r.addr,
            fromState: r.fromState,
            toState: r.toState,
            id: r.id,
            child: iChild
        });
    endrule

    (* descending_urgency = "doRsFromDCToP, doRsFromICToP" *)
    rule doRsFromICToP;
        let r <- toGet(iCache.rsToP).get;
        llc.rsFromC.enq(CRsMsg {
            addr: r.addr,
            toState: r.toState,
            data: r.data,
            child: iChild
        });
    endrule

    rule doRsFromPToIC(llc.toC.first matches tagged PRs .rs &&& rs.child == iChild);
        llc.toC.deq;
        iCache.fromP.enq(PRs (PRsMsg {
            addr: rs.addr,
            toState: rs.toState,
            child: ?,
            data: rs.data,
            id: rs.id
        }));
    endrule

    rule doRqFromPToIC(llc.toC.first matches tagged PRq .rq &&& rq.child == iChild);
        llc.toC.deq;
        iCache.fromP.enq(PRq (PRqMsg {
            addr: rq.addr,
            toState: rq.toState,
            child: ?
        }));
    endrule
endmodule
*/
