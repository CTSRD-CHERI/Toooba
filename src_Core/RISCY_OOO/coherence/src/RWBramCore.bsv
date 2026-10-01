
// Copyright (c) 2017 Massachusetts Institute of Technology
//
//-
// RVFI_DII + CHERI modifications:
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

import BRAMCore::*;
import Fifos::*;
import Vector::*;
import Types::*;
import CacheUtils::*;
import Memory_Config::*;

interface RWBramCore#(type addrT, type dataT);
    method Action wrReq(addrT a, dataT d);
    method Action rdReq(addrT a);
    method dataT rdResp;
    method Bool rdRespValid;
    method Action deqRdResp;
endinterface

// A cache-line RAM with an explicit, access-granular port.  Each way contains
// one deep AccessWidth-wide data RAM and one deep capability-tag RAM.  The
// physical RAM address is the concatenation of the line index and access
// selector.
interface RWBramCoreLineAccess#(type addrT);
    method Action wrAccess(addrT line, CLineAccessSel access, CLineAccess data);
    method Action rdAccessReq(addrT line, CLineAccessSel access);
    method CLineAccess rdAccessResp;
    method Bool rdAccessRespValid;
    method Action deqRdAccessResp;
endinterface

// Compatibility interface.  Whole-line requests are serialized over the
// access-granular RAM; wrAccess is the preferred interface for streamed fills.
interface RWBramCoreLineDirectWrite#(type addrT);
    method Action wrReq(addrT a, CLine line);
    method Action wrAccess(addrT a, CLineAccessSel access, CLineAccess data);
    method Action rdAccessReq(addrT a, CLineAccessSel access);
    method CLineAccess rdAccessResp(CLineAccessSel access);
    method Action deqRdAccessResp(CLineAccessSel access);
    method Action rdReq(addrT a);
    method CLine rdResp;
    method Bool rdRespValid;
    method Action deqRdResp;
endinterface

interface RBramCore#(type addrT, type dataT);
    method Action rd1Req(addrT a);
    method Action rd2Req(addrT a);
    method dataT rd1Resp;
    method dataT rd2Resp;
    method Bool rd1RespValid;
    method Bool rd2RespValid;
    method Action deqRd1Resp;
    method Action deqRd2Resp;
endinterface

module mkDummyBramCore(RWBramCore#(addrT, dataT)) provisos(
    Bits#(addrT, addrSz), Bits#(dataT, dataSz)
);
    method Action wrReq(addrT a, dataT d);
    endmethod

    method Action rdReq(addrT a);
    endmethod

    method dataT rdResp = ?;

    method rdRespValid = True;

    method Action deqRdResp;
    endmethod
endmodule

module mkRWBramCore(RWBramCore#(addrT, dataT)) provisos(
    Bits#(addrT, addrSz), Bits#(dataT, dataSz)
);
    BRAM_DUAL_PORT#(addrT, dataT) bram <- mkBRAMCore2(valueOf(TExp#(addrSz)), False);
    BRAM_PORT#(addrT, dataT) wrPort = bram.a;
    BRAM_PORT#(addrT, dataT) rdPort = bram.b;
    // 1 elem pipeline fifo to add guard for read req/resp
    // must be 1 elem to make sure rdResp is not corrupted
    // BRAMCore should not change output if no req is made
    Fifo#(1, void) rdReqQ <- mkPipelineFifo;

    method Action wrReq(addrT a, dataT d);
        wrPort.put(True, a, d);
    endmethod

    method Action rdReq(addrT a);
        rdReqQ.enq(?);
        rdPort.put(False, a, ?);
    endmethod

    method dataT rdResp if(rdReqQ.notEmpty);
        return rdPort.read;
    endmethod

    method rdRespValid = rdReqQ.notEmpty;

    method Action deqRdResp;
        rdReqQ.deq;
    endmethod
endmodule

module mkRWBramCoreForwarded(RWBramCore#(addrT, dataT)) provisos(
    Bits#(addrT, addrSz), Bits#(dataT, dataSz), Eq#(addrT)
);
    BRAM_DUAL_PORT#(addrT, dataT) bram <- mkBRAMCore2(valueOf(TExp#(addrSz)), False);
    BRAM_PORT#(addrT, dataT) wrPort = bram.a;
    BRAM_PORT#(addrT, dataT) rdPort = bram.b;
    // 1 elem pipeline fifo to add guard for read req/resp
    // must be 1 elem to make sure rdResp is not corrupted
    // BRAMCore should not change output if no req is made
    Fifo#(1, void) rdReqQ <- mkPipelineFifo;
    Reg#(addrT) readAddr[2] <- mkCReg(2,?);
    Reg#(Bool) currentWriteValid <- mkReg(False);
    Reg#(addrT) currentWriteAddr <- mkRegU;
    Reg#(dataT) currentWriteData <- mkRegU;

    rule doRead;
        rdPort.put(False, readAddr[1], ?);
    endrule

    method Action wrReq(addrT a, dataT d);
        wrPort.put(True, a, d);
        currentWriteValid <= True;
        currentWriteAddr <= a; // Forward data if a read happens on the same cycle.
        currentWriteData <= d;
    endmethod

    method Action rdReq(addrT a);
        readAddr[0] <= a;
        rdReqQ.enq(?);
    endmethod

    method dataT rdResp if(rdReqQ.notEmpty);
        return (currentWriteValid && readAddr[0] == currentWriteAddr) ? currentWriteData : rdPort.read;
    endmethod

    method rdRespValid = rdReqQ.notEmpty;

    method Action deqRdResp;
        rdReqQ.deq;
    endmethod
endmodule

typedef Bit#(TAdd#(addrSz, TMax#(TLog#(CLineNumAccesses), 1))) CLineRamAddr#(numeric type addrSz);

function CLineRamAddr#(addrSz) getCLineRamAddr(addrT line, CLineAccessSel access)
    provisos(Bits#(addrT, addrSz));
    return {pack(line), pack(access)};
endfunction

module mkRWBramCoreLineAccess(RWBramCoreLineAccess#(addrT)) provisos(
    Bits#(addrT, addrSz)
);
    RWBramCore#(CLineRamAddr#(addrSz), Bit#(AccessWidth)) dataRam <- mkRWBramCore;
    RWBramCore#(CLineRamAddr#(addrSz), Vector#(CLineMemDataPerAccess, MemTag)) tagRam <- mkRWBramCore;

    method Action wrAccess(addrT line, CLineAccessSel access, CLineAccess data);
        let ramAddr = getCLineRamAddr(line, access);
        dataRam.wrReq(ramAddr, data.data);
        tagRam.wrReq(ramAddr, data.tag);
    endmethod

    method Action rdAccessReq(addrT line, CLineAccessSel access);
        let ramAddr = getCLineRamAddr(line, access);
        dataRam.rdReq(ramAddr);
        tagRam.rdReq(ramAddr);
    endmethod

    method CLineAccess rdAccessResp;
        return CLineAccess {data: dataRam.rdResp, tag: tagRam.rdResp};
    endmethod

    method Bool rdAccessRespValid = dataRam.rdRespValid && tagRam.rdRespValid;

    method Action deqRdAccessResp;
        dataRam.deqRdResp;
        tagRam.deqRdResp;
    endmethod
endmodule

module mkRWBramCoreLineAccessForwarded(RWBramCoreLineAccess#(addrT)) provisos(
    Bits#(addrT, addrSz), Eq#(addrT)
);
    RWBramCore#(CLineRamAddr#(addrSz), Bit#(AccessWidth)) dataRam <- mkRWBramCoreForwarded;
    RWBramCore#(CLineRamAddr#(addrSz), Vector#(CLineMemDataPerAccess, MemTag)) tagRam <- mkRWBramCoreForwarded;

    method Action wrAccess(addrT line, CLineAccessSel access, CLineAccess data);
        let ramAddr = getCLineRamAddr(line, access);
        dataRam.wrReq(ramAddr, data.data);
        tagRam.wrReq(ramAddr, data.tag);
    endmethod

    method Action rdAccessReq(addrT line, CLineAccessSel access);
        let ramAddr = getCLineRamAddr(line, access);
        dataRam.rdReq(ramAddr);
        tagRam.rdReq(ramAddr);
    endmethod

    method CLineAccess rdAccessResp;
        return CLineAccess {data: dataRam.rdResp, tag: tagRam.rdResp};
    endmethod

    method Bool rdAccessRespValid = dataRam.rdRespValid && tagRam.rdRespValid;

    method Action deqRdAccessResp;
        dataRam.deqRdResp;
        tagRam.deqRdResp;
    endmethod
endmodule


module mkRWBramCoreLine(RWBramCore#(addrT, CLine)) provisos(
    Bits#(addrT, addrSz), Eq#(addrT)
);
    Vector#(CLineNumAccesses, RWBramCore#(addrT, Bit#(AccessWidth))) dataRam <- replicateM(mkRWBramCore);
    Vector#(CLineNumAccesses, RWBramCore#(addrT, Vector#(CLineMemDataPerAccess, MemTag))) tagRam <- replicateM(mkRWBramCore);

    method Action wrReq(addrT a, CLine line);
        let accesses = clineToAccessVector(line);
        for (Integer i = 0; i < valueOf(CLineNumAccesses); i = i + 1) begin
            dataRam[i].wrReq(a, accesses[i].data);
            tagRam[i].wrReq(a, accesses[i].tag);
        end
    endmethod

    method Action rdReq(addrT a);
        for (Integer i = 0; i < valueOf(CLineNumAccesses); i = i + 1) begin
            dataRam[i].rdReq(a);
            tagRam[i].rdReq(a);
        end
    endmethod

    method CLine rdResp;
        Vector#(CLineNumAccesses, CLineAccess) accesses = newVector;
        for (Integer i = 0; i < valueOf(CLineNumAccesses); i = i + 1)
            accesses[i] = CLineAccess {data: dataRam[i].rdResp, tag: tagRam[i].rdResp};
        return accessVectorToCline(accesses);
    endmethod

    method Bool rdRespValid;
        Bool valid = True;
        for (Integer i = 0; i < valueOf(CLineNumAccesses); i = i + 1)
            valid = valid && dataRam[i].rdRespValid && tagRam[i].rdRespValid;
        return valid;
    endmethod

    method Action deqRdResp;
        for (Integer i = 0; i < valueOf(CLineNumAccesses); i = i + 1) begin
            dataRam[i].deqRdResp;
            tagRam[i].deqRdResp;
        end
    endmethod
endmodule

module mkRWBramCoreLineDirectWrite(RWBramCoreLineDirectWrite#(addrT)) provisos(
    Bits#(addrT, addrSz), Eq#(addrT)
);
    Vector#(CLineNumAccesses, RWBramCore#(addrT, Bit#(AccessWidth))) dataRam <- replicateM(mkRWBramCore);
    Vector#(CLineNumAccesses, RWBramCore#(addrT, Vector#(CLineMemDataPerAccess, MemTag))) tagRam <- replicateM(mkRWBramCore);

    method Action wrReq(addrT a, CLine line);
        let accesses = clineToAccessVector(line);
        for (Integer i = 0; i < valueOf(CLineNumAccesses); i = i + 1) begin
            dataRam[i].wrReq(a, accesses[i].data);
            tagRam[i].wrReq(a, accesses[i].tag);
        end
    endmethod

    method Action wrAccess(addrT a, CLineAccessSel access, CLineAccess data);
        dataRam[access].wrReq(a, data.data);
        tagRam[access].wrReq(a, data.tag);
    endmethod

    method Action rdAccessReq(addrT a, CLineAccessSel access);
        dataRam[access].rdReq(a);
        tagRam[access].rdReq(a);
    endmethod

    method CLineAccess rdAccessResp(CLineAccessSel access);
        return CLineAccess {data: dataRam[access].rdResp, tag: tagRam[access].rdResp};
    endmethod

    method Action deqRdAccessResp(CLineAccessSel access);
        dataRam[access].deqRdResp;
        tagRam[access].deqRdResp;
    endmethod

    method Action rdReq(addrT a);
        for (Integer i = 0; i < valueOf(CLineNumAccesses); i = i + 1) begin
            dataRam[i].rdReq(a);
            tagRam[i].rdReq(a);
        end
    endmethod

    method CLine rdResp;
        Vector#(CLineNumAccesses, CLineAccess) accesses = newVector;
        for (Integer i = 0; i < valueOf(CLineNumAccesses); i = i + 1)
            accesses[i] = CLineAccess {data: dataRam[i].rdResp, tag: tagRam[i].rdResp};
        return accessVectorToCline(accesses);
    endmethod

    method Bool rdRespValid;
        Bool valid = True;
        for (Integer i = 0; i < valueOf(CLineNumAccesses); i = i + 1)
            valid = valid && dataRam[i].rdRespValid && tagRam[i].rdRespValid;
        return valid;
    endmethod

    method Action deqRdResp;
        for (Integer i = 0; i < valueOf(CLineNumAccesses); i = i + 1) begin
            dataRam[i].deqRdResp;
            tagRam[i].deqRdResp;
        end
    endmethod
endmodule

module mkRWBramCoreLineDirectWriteForwarded(RWBramCoreLineDirectWrite#(addrT)) provisos(
    Bits#(addrT, addrSz), Eq#(addrT)
);
    Vector#(CLineNumAccesses, RWBramCore#(addrT, Bit#(AccessWidth))) dataRam <- replicateM(mkRWBramCoreForwarded);
    Vector#(CLineNumAccesses, RWBramCore#(addrT, Vector#(CLineMemDataPerAccess, MemTag))) tagRam <- replicateM(mkRWBramCoreForwarded);

    method Action wrReq(addrT a, CLine line);
        let accesses = clineToAccessVector(line);
        for (Integer i = 0; i < valueOf(CLineNumAccesses); i = i + 1) begin
            dataRam[i].wrReq(a, accesses[i].data);
            tagRam[i].wrReq(a, accesses[i].tag);
        end
    endmethod

    method Action wrAccess(addrT a, CLineAccessSel access, CLineAccess data);
        dataRam[access].wrReq(a, data.data);
        tagRam[access].wrReq(a, data.tag);
    endmethod

    method Action rdAccessReq(addrT a, CLineAccessSel access);
        dataRam[access].rdReq(a);
        tagRam[access].rdReq(a);
    endmethod

    method CLineAccess rdAccessResp(CLineAccessSel access);
        return CLineAccess {data: dataRam[access].rdResp, tag: tagRam[access].rdResp};
    endmethod

    method Action deqRdAccessResp(CLineAccessSel access);
        dataRam[access].deqRdResp;
        tagRam[access].deqRdResp;
    endmethod

    method Action rdReq(addrT a);
        for (Integer i = 0; i < valueOf(CLineNumAccesses); i = i + 1) begin
            dataRam[i].rdReq(a);
            tagRam[i].rdReq(a);
        end
    endmethod

    method CLine rdResp;
        Vector#(CLineNumAccesses, CLineAccess) accesses = newVector;
        for (Integer i = 0; i < valueOf(CLineNumAccesses); i = i + 1)
            accesses[i] = CLineAccess {data: dataRam[i].rdResp, tag: tagRam[i].rdResp};
        return accessVectorToCline(accesses);
    endmethod

    method Bool rdRespValid;
        Bool valid = True;
        for (Integer i = 0; i < valueOf(CLineNumAccesses); i = i + 1)
            valid = valid && dataRam[i].rdRespValid && tagRam[i].rdRespValid;
        return valid;
    endmethod

    method Action deqRdResp;
        for (Integer i = 0; i < valueOf(CLineNumAccesses); i = i + 1) begin
            dataRam[i].deqRdResp;
            tagRam[i].deqRdResp;
        end
    endmethod
endmodule

module mkRWBramCoreLineForwarded(RWBramCore#(addrT, CLine)) provisos(
    Bits#(addrT, addrSz), Eq#(addrT)
);
    Vector#(CLineNumAccesses, RWBramCore#(addrT, Bit#(AccessWidth))) dataRam <- replicateM(mkRWBramCoreForwarded);
    Vector#(CLineNumAccesses, RWBramCore#(addrT, Vector#(CLineMemDataPerAccess, MemTag))) tagRam <- replicateM(mkRWBramCoreForwarded);

    method Action wrReq(addrT a, CLine line);
        let accesses = clineToAccessVector(line);
        for (Integer i = 0; i < valueOf(CLineNumAccesses); i = i + 1) begin
            dataRam[i].wrReq(a, accesses[i].data);
            tagRam[i].wrReq(a, accesses[i].tag);
        end
    endmethod

    method Action rdReq(addrT a);
        for (Integer i = 0; i < valueOf(CLineNumAccesses); i = i + 1) begin
            dataRam[i].rdReq(a);
            tagRam[i].rdReq(a);
        end
    endmethod

    method CLine rdResp;
        Vector#(CLineNumAccesses, CLineAccess) accesses = newVector;
        for (Integer i = 0; i < valueOf(CLineNumAccesses); i = i + 1)
            accesses[i] = CLineAccess {data: dataRam[i].rdResp, tag: tagRam[i].rdResp};
        return accessVectorToCline(accesses);
    endmethod

    method Bool rdRespValid;
        Bool valid = True;
        for (Integer i = 0; i < valueOf(CLineNumAccesses); i = i + 1)
            valid = valid && dataRam[i].rdRespValid && tagRam[i].rdRespValid;
        return valid;
    endmethod

    method Action deqRdResp;
        for (Integer i = 0; i < valueOf(CLineNumAccesses); i = i + 1) begin
            dataRam[i].deqRdResp;
            tagRam[i].deqRdResp;
        end
    endmethod
endmodule

module mkRWBramCoreUG(RWBramCore#(addrT, dataT)) provisos(
    Bits#(addrT, addrSz), Bits#(dataT, dataSz)
);
    BRAM_DUAL_PORT#(addrT, dataT) bram <- mkBRAMCore2(valueOf(TExp#(addrSz)), False);
    BRAM_PORT#(addrT, dataT) wrPort = bram.a;
    BRAM_PORT#(addrT, dataT) rdPort = bram.b;

    method Action wrReq(addrT a, dataT d);
        wrPort.put(True, a, d);
    endmethod

    method Action rdReq(addrT a);
        rdPort.put(False, a, ?);
    endmethod

    method dataT rdResp;
        return rdPort.read;
    endmethod

    method rdRespValid = True;

    method Action deqRdResp;
        noAction;
    endmethod
endmodule
