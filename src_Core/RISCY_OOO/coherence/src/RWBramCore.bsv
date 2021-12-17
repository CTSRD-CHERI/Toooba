
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
//
// Vector extensions:
//     Copyright (c) 2021 Franz Fuchs
//     All rights reserved.
//
//     This software was developed by the University of  Cambridge
//     Department of Computer Science and Technology under the
//     SIPP (Secure IoT Processor Platform with Remote Attestation)
//     project funded by EPSRC: EP/S030868/1
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

interface RWBramCore#(type addrT, type dataT);
    method Action wrReq(addrT a, dataT d);
    method Action rdReq(addrT a);
    method dataT rdResp;
    method Bool rdRespValid;
    method Action deqRdResp;
endinterface

interface RWBramCoreVector#(type addrT, type dataT, numeric type n);
    method Action wrReq(addrT a, Vector#(n, Maybe#(dataT)) d);
    method Action rdReq(addrT a);
    method Vector#(n, dataT) rdResp;
endinterface

typedef struct {
    addrT a;
    Bit#(TLog#(n)) idx;
} AddrData#(type addrT, numeric type n) deriving (Bits, Eq, FShow);

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

module mkRWBramCoreForwarding(RWBramCore#(addrT, dataT)) provisos(
    Bits#(addrT, addrSz), Bits#(dataT, dataSz),
    Eq#(addrT),
    Literal#(addrT),
    Literal#(dataT)
);
    BRAM_DUAL_PORT#(addrT, dataT) bram <- mkBRAMCore2(valueOf(TExp#(addrSz)), False);
    BRAM_PORT#(addrT, dataT) wrPort = bram.a;
    BRAM_PORT#(addrT, dataT) rdPort = bram.b;

    Reg#(addrT) lastWrAddr <- mkReg(0);
    Reg#(addrT) lastRdAddr <- mkReg(0);
    Reg#(dataT) lastWrData <- mkReg(0);

    method Action wrReq(addrT a, dataT d);
        lastWrAddr <= a;
        lastWrData <= d;
        wrPort.put(True, a, d);
    endmethod

    method Action rdReq(addrT a);
        lastRdAddr <= a;
        rdPort.put(False, a, ?);
    endmethod

    method dataT rdResp;
        if(lastWrAddr == lastRdAddr) return lastWrData;
        else return rdPort.read;
    endmethod

    method rdRespValid = True;

    method Action deqRdResp;
        noAction;
    endmethod
endmodule


module mkRWBramCoreVector(RWBramCoreVector#(addrT, dataT, n)) provisos(
    //NumAlias#(TExp#(TLog#(n)), num),
    NumAlias #(TSub#(addrSz,TLog#(n)), bramAddrSz),
    Bits#(addrT, addrSz), Bits#(dataT, dataSz),
    Arith#(addrT),
    Literal#(dataT),
    Add#(TDiv#(addrSz, n), a__, addrSz),
    Add#(b__, TLog#(n), addrSz),
    FShow#(dataT)
);

    // port a is used for writing
    // port b is used for reading
    Vector#(n, RWBramCore#(Bit#(bramAddrSz), dataT)) brams <- replicateM(mkRWBramCoreForwarding);
    Reg#(AddrData#(Bit#(bramAddrSz), n)) lastAddr <- mkRegU;


    function Vector#(n, Bit#(bramAddrSz)) computeAddrs (addrT x);
        /*Bit#(bramAddrSz) startAddr = truncateLSB(pack(x));
        Bit#(TLog#(n)) off = truncate(pack(x));
        Bit#(TLog#(n)) index = 0;
        Vector#(n, AddrData#(Bit#(bramAddrSz), n)) v = replicate(AddrData{a: 0, idx: 0});
        for (Integer i = 0; i < valueOf(n); i = i + 1) begin
            v[fromInteger(i) + off] = AddrData{a: startAddr, idx: index};
            if((fromInteger(i) + off) == fromInteger(valueOf(TSub#(n,1)))) startAddr = startAddr + 1;
            index = index + 1;
        end
        return v;*/
        Vector#(n, Bit#(bramAddrSz)) v = ?;
        for (Integer i = 0; i < valueOf(n); i = i + 1) begin
            AddrData#(Bit#(bramAddrSz), n) tmp = unpack(pack(x) + fromInteger(i));
            v[tmp.idx] = tmp.a;
        end
        return v;
    endfunction

    method Action wrReq(addrT a, Vector#(n, Maybe#(dataT)) ds);
      let aD = computeAddrs (a);
//      Bit#(TLog#(n)) off = truncate(pack(x));
      //$display("RWBRAMCoreVector write addresses:");
      //$display(fshow(aD));
      
      for(Integer i = 0; i < valueOf(n); i = i + 1) begin
          Bit#(TLog#(n)) off = truncate(pack(a)) + fromInteger(i);
          if(ds[i] matches tagged Valid .data) begin
              brams[off].wrReq(aD[off], data);
              //$display("write: bram[", fshow(off), "], addr = ", fshow(aD[off]), ", data = ", fshow(data));
          end
      end
    endmethod

    method Action rdReq(addrT a);
      let aD = computeAddrs (a);
      //$display("RWBRAMCoreVector read addresses:");
      //$display(fshow(aD));

      //Bit#(TLog#(n)) off = truncate(pack(a));
      lastAddr <= unpack(pack(a));
      for(Integer i = 0; i < valueOf(n); i = i + 1) begin
          brams[i].rdReq(aD[i]);
      end
    endmethod

    method Vector#(n, dataT) rdResp;
      Vector#(n, dataT) v = replicate(0);
      //let aD = lastAddr;
      for(Integer i = 0; i < valueOf(n); i = i + 1) begin
          Bit#(TLog#(n)) off = lastAddr.idx + fromInteger(i);
          let data = brams[off].rdResp;
          v[i] = data;
          //$display("rdResp: data = ", fshow(data), "from bram[", fshow(off), "]");
      end
      return v;
    endmethod

endmodule
