
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
import Ehr::*;

interface RWBramCore#(type addrT, type dataT);
    method Action wrReq(addrT a, dataT d);
    method Action rdReq(addrT a);
    method dataT rdResp;
    method Bool rdRespValid;
    method Action deqRdResp;
endinterface

interface RWBramCoreDual#(type addrT, type dataT);
    method Action wrReq(addrT a, dataT d);
    method Action rdReqA(addrT a);
    method Action rdReqB(addrT a);
    method dataT rdRespA;
    method dataT rdRespB;
`ifdef CID
    method Action shootdown;
`endif
endinterface

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

module mkRWBramCoreDualUG(RWBramCoreDual#(addrT, dataT)) provisos(
    Bits#(addrT, addrSz), Bits#(dataT, dataSz),
    Eq#(addrT), Arith#(addrT), Literal#(dataT)
);

    BRAM_DUAL_PORT#(addrT, dataT) bramA <- mkBRAMCore2(valueOf(TExp#(addrSz)), False);
    BRAM_DUAL_PORT#(addrT, dataT) bramB <- mkBRAMCore2(valueOf(TExp#(addrSz)), False);
    BRAM_PORT#(addrT, dataT) wrPortA = bramA.a;
    BRAM_PORT#(addrT, dataT) rdPortA = bramA.b;
    BRAM_PORT#(addrT, dataT) wrPortB = bramB.a;
    BRAM_PORT#(addrT, dataT) rdPortB = bramB.b;

    RWire#(Tuple2#(addrT, dataT)) wwire <- mkRWire;
    // used as initialisation as well
    Ehr#(2, Bool) sd_prog <- mkEhr(True);
    Reg#(addrT) counter <- mkReg(0);

    (* fire_when_enabled, no_implicit_conditions *)
    rule canonWrite;
        if(sd_prog[0]) begin
            wrPortA.put(True, counter, 0);
            wrPortB.put(True, counter, 0);
            counter <= counter + 1;
            if (counter == 0) sd_prog[0] <= False;
        end
        else if(wwire.wget() matches tagged Valid .t) begin
            wrPortA.put(True, tpl_1(t), tpl_2(t));
            wrPortB.put(True, tpl_1(t), tpl_2(t));
        end
    endrule


    method Action wrReq(addrT a, dataT d);
        wwire.wset(tuple2(a, d));
    endmethod
    
    method Action rdReqA(addrT a);
        rdPortA.put(False, a, ?);
    endmethod

    method Action rdReqB(addrT a);
        rdPortB.put(False, a, ?);
    endmethod

    method dataT rdRespA;
        return rdPortA.read;
    endmethod

    method dataT rdRespB;
        return rdPortB.read;
    endmethod

`ifdef CID
    method Action shootdown();
        sd_prog[1] <= True;
    endmethod
`endif

endmodule