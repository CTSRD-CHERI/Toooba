
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
import RWire::*;

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
    //method Bool rdRespValid;
endinterface

typedef struct {
    addrT a;
    dataT d;
} AddrData#(type addrT, type dataT) deriving (Bits, Eq, FShow);

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


module mkRWBramCoreVector(RWBramCoreVector#(addrT, dataT, n)) provisos(
    NumAlias#(TExp#(TLog#(n)), num),
    NumAlias #(TSub#(addrSz,TLog#(n)), bramAddrSz),
    Bits#(addrT, addrSz), Bits#(dataT, dataSz),
    Arith#(addrT),
    Literal#(dataT),
    Add#(TDiv#(addrSz, n), a__, addrSz),
    Add#(b__, TLog#(n), addrSz),
    //Literal#(RWBramCore::AddrData#(Bit#(TSub#(addrSz, TLog#(n))), dataT)),
    FShow#(dataT)
);

    // port a is used for writing
    // port b is used for reading
    Vector#(n, BRAM_DUAL_PORT#(Bit#(bramAddrSz), dataT)) brams <- replicateM(mkBRAMCore2(valueOf(TExp#(bramAddrSz)), False));
    Reg#(Bit#(TLog#(n))) lastOff <- mkRegU;
    RWire#(Vector#(n, AddrData#(Bit#(bramAddrSz), dataT))) lastWrReq <- mkRWire;
    Reg#(Vector#(n, AddrData#(Bit#(bramAddrSz), dataT))) lastRqReq <- mkRegU;


    function Vector#(n, AddrData#(Bit#(bramAddrSz), dataT)) computeAddrs (addrT x, Vector#(n, Maybe#(dataT)) ds);
        Bit#(bramAddrSz) startAddr = truncateLSB(pack(x));
        Bit#(TLog#(n)) off = truncate(pack(x));
        Vector#(n, AddrData#(Bit#(bramAddrSz), dataT)) v = replicate(AddrData{a: 0, d: 0});
        for (Integer i = 0; i < valueOf(n); i = i + 1) begin
            if(ds[i] matches tagged Valid .data) v[fromInteger(i) + off] = AddrData{a: startAddr, d:data};
            else v[fromInteger(i) + off] = AddrData{a: 0, d: 0};
            if((fromInteger(i) + off) == fromInteger(valueOf(TSub#(n,1)))) startAddr = startAddr + 1;
        end
        return v;
    endfunction

    method Action wrReq(addrT a, Vector#(n, Maybe#(dataT)) ds);
      let aD = computeAddrs (a, ds);
      lastWrReq.wset(aD);
      for(Integer i = 0; i < valueOf(n); i = i + 1) begin
          brams[i].a.put(True, aD[i].a, aD[i].d);
      end
    endmethod

    method Action rdReq(addrT a);
      let aD = computeAddrs (a, ?);
      lastRqReq <= aD;
      $display("RWBRAMCoreVector read addresses:");
      $display(fshow(aD));

      Bit#(TLog#(n)) off = truncate(pack(a));
      lastOff <= off;
      for(Integer i = 0; i < valueOf(n); i = i + 1) begin
          brams[i].b.put(False, aD[i].a, ?);
      end
    endmethod

    method Vector#(n, dataT) rdResp;
      Vector#(n, dataT) v = replicate(0);
      let aD = lastRqReq;
      let lR = lastWrReq.wget();
      for(Integer i = 0; i < valueOf(n); i = i + 1) begin
          v[i] = brams[fromInteger(i) + lastOff].a.read;
          if(lR matches tagged Valid .req) begin
              for(Integer j = 0; j < valueOf(n); j = j + 1) begin
                  if(aD[i].a == req[j].a) v[i] = req[j].d;
              end
          end
      end
      return v;
    endmethod

endmodule
