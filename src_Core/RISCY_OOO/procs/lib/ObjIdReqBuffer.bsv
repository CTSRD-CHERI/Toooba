package ObjIdReqBuffer;

import Assert::*;
import Ehr::*;
import ProcTypes::*;
import Types::*;
import Vector::*;

// One reserved request slot per LSQ entry. An entry cannot issue another
// check until its previous response (including a wrong-path response) drains.
// Enqueue therefore needs no shared capacity guard. A stalled request yields
// to the next occupied slot, so a younger check cannot block an older load
// needed to resolve one of its store dependencies. Port 0 -> 1 retains the
// original same-cycle enqueue/issue bypass when the check is ready.
interface ObjIdReqBuffer#(numeric type size);
    method Action enq(Tuple3#(Bit#(TLog#(size)), Addr, Bit#(7)) req);
    method Tuple3#(Bit#(TLog#(size)), Addr, Bit#(7)) first;
    method Action deq;
    method Action retry;
endinterface

module mkObjIdReqBuffer(ObjIdReqBuffer#(size));
    Vector#(size, Ehr#(2, Maybe#(Tuple2#(Addr, Bit#(7))))) pending <-
        replicateM(mkEhr(Invalid));
    Reg#(Bit#(TLog#(size))) cursor <- mkReg(0);

    function Bit#(size) occupied;
        Bit#(size) mask = 0;
        for(Integer i = 0; i < valueOf(size); i = i + 1)
            mask[i] = pack(isValid(pending[i][1]));
        return mask;
    endfunction

    function Bit#(TLog#(size)) selected;
        // Select the first occupied slot at/after cursor, wrapping if needed.
        // A one-hot priority mask avoids nested Maybe-valued selection trees.
        Bit#(size) high = occupied & ('1 << cursor);
        Bit#(size) candidates = high != 0 ? high : occupied;
        Bit#(size) oneHot = candidates & (~candidates + 1);
        Bit#(TLog#(size)) tag = 0;
        for(Integer i = 0; i < valueOf(size); i = i + 1)
            tag = tag | (oneHot[i] == 1 ? fromInteger(i) : 0);
        return tag;
    endfunction

    function Bit#(TLog#(size)) nextSlot(Bit#(TLog#(size)) idx);
        return idx == fromInteger(valueOf(size) - 1) ? 0 : idx + 1;
    endfunction

    method Action enq(Tuple3#(Bit#(TLog#(size)), Addr, Bit#(7)) req);
        let {tag, addr, offset} = req;
        doAssert(!isValid(pending[tag][0]), "duplicate pending ObjID request");
        pending[tag][0] <= Valid(tuple2(addr, offset));
    endmethod

    method Tuple3#(Bit#(TLog#(size)), Addr, Bit#(7)) first if(occupied != 0);
        let tag = selected;
        let {addr, offset} = fromMaybe(?, pending[tag][1]);
        return tuple3(tag, addr, offset);
    endmethod

    method Action deq if(occupied != 0);
        let tag = selected;
        pending[tag][1] <= Invalid;
        cursor <= nextSlot(tag);
    endmethod

    method Action retry if(occupied != 0);
        cursor <= nextSlot(selected);
    endmethod
endmodule

// Keep the request selection network inside its own scheduling boundary.
// Otherwise inlining it into every core rule duplicates its elaboration and
// obscures the enqueue-before-consume relationship at the pipeline boundary.
(* synthesize *)
module mkLdObjIdReqBuffer(ObjIdReqBuffer#(LdQSize));
    let m <- mkObjIdReqBuffer;
    return m;
endmodule

(* synthesize *)
module mkStObjIdReqBuffer(ObjIdReqBuffer#(StQSize));
    let m <- mkObjIdReqBuffer;
    return m;
endmodule

endpackage
