package ObjIdReverseMap;

import CacheUtils::*;
import CCTypes::*;
import RegFile::*;
import RWire::*;
import Types::*;
import Vector::*;

// Physical-line reverse presence map: 16 sets, four ways. A match causes
// the caller to flush the entire virtually addressed ObjID buffer.
interface ObjIdReverseMap;
    method Action insert(LineAddr line);
    method Bool contains(LineAddr line);
    method Action clear;
endinterface

module mkObjIdReverseMap(ObjIdReverseMap);
    Vector#(4, RegFile#(Bit#(4), LineAddr)) tags <- replicateM(mkRegFileFull);
    Vector#(16, Reg#(Bit#(4))) valid <- replicateM(mkReg(0));
    Reg#(Bool) saturated <- mkReg(False);

    // Separate the insertion event from the RAM write, allowing eviction
    // lookup to read old tags while the caller bypasses same-cycle fills.
    RWire#(LineAddr) insertRq <- mkRWire;
    PulseWire flushing <- mkPulseWire;
    rule commitInsert (insertRq.wget matches tagged Valid .line &&& !flushing);
        Bit#(4) index = truncate(pack(line));
        let present = valid[index];
        Bool found = False;
        Maybe#(Bit#(2)) freeWay = Invalid;
        for (Integer w=0; w<4; w=w+1) begin
            found = found || (present[w] == 1 && tags[w].sub(index) == line);
            if (present[w] == 0) freeWay = Valid(fromInteger(w));
        end
        if (!found) begin
            if (freeWay matches tagged Valid .way) begin
                tags[way].upd(index, line);
                valid[index] <= present | (1 << way);
            end
            else begin
                // Never silently replace tracking while the forward buffer
                // might retain the corresponding word. Until the next flush,
                // conservatively report presence for every physical line.
                saturated <= True;
            end
        end
    endrule

    method Action insert(LineAddr line);
        insertRq.wset(line);
    endmethod

    method Bool contains(LineAddr line);
        Bit#(4) index = truncate(pack(line));
        Bool found = saturated;
        for (Integer w=0; w<4; w=w+1)
            found = found || (valid[index][w] == 1 && tags[w].sub(index) == line);
        return found;
    endmethod

    method Action clear;
        flushing.send;
        for (Integer s=0; s<16; s=s+1) valid[s] <= 0;
        saturated <= False;
    endmethod
endmodule
endpackage
