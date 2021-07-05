////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
// With modifications by Colin Rothwell, University of Cambridge
//
// SPDX-License-Identifier: BSD-3-Clause
//
////////////////////////////////////////////////////////////////////////////////
//  Filename      : NonPipelinedMath.bsv
//  Description   : Non-pipelined versions of modules in the Math library,
//                  which can also be used with the FloatingPoint library.
////////////////////////////////////////////////////////////////////////////////

package NonPipelinedMath;

import ClientServer ::*;
import FIFO ::*;
import FIFOF ::*;
import GetPut ::*;
import StmtFSM ::*;
import Vector ::*;
import Randomizable ::*;
import Divide ::*;

export mkNonPipelinedDivider;
export mkNonPipelinedSignedDivider;
export mkNonPipelinedSquareRooter;

typedef struct {
   Int#(TAdd#(1,n)) d;
   Int#(TAdd#(2,TAdd#(n,n))) r;
   Int#(TAdd#(1,n)) q;
} DivState#(numeric type n) deriving(Bits, Eq, FShow);

// non-restoring divider
// n+3 cycle latency
module mkNonPipelinedDivider#(Integer s)(Server#(Tuple2#(UInt#(TAdd#(n,n)),UInt#(n)),Tuple2#(UInt#(n),UInt#(n))))
   provisos(Alias#(UInt#(TAdd#(TLog#(n),1)), countT));

   Reg#(DivState#(n)) fReg <- mkRegU;
   Reg#(Bool) rg_busy <- mkReg(False);
   Reg#(countT) rg_count <- mkReg(0);

   function zeroExtendLSB(d) = unpack({pack(d),0});

   function Bool done(countT cmp) = (cmp > fromInteger(valueOf(n)));

   rule work (rg_busy && !done(rg_count));
      DivState#(n) f = fReg;
      Int#(TAdd#(2,TAdd#(n,n))) bigd = zeroExtendLSB(f.d);
      countT count = rg_count;
      for (Integer j = 0; j < s; j = j + 1) begin
        if (!done(count)) begin
           //$display("q:%x, r:%x d:%x bigd:%x Pre NonPipe", f.q, f.r, f.d, bigd);
           if (f.r >= 0) begin
               f.q = (f.q << 1) | 1;
               f.r = (f.r << 1) - bigd;
            end
            else begin
               f.q = (f.q << 1);
               f.r = (f.r << 1) + bigd;
            end
            //$display("q:%x, r:%x NonPipe", f.q, f.r);
            count = count + 1;
         end
      end
      fReg <= f;
      rg_count <= count;
   endrule

   interface Put request;
      method Action put(Tuple2#(UInt#(TAdd#(n,n)),UInt#(n)) x) if (!rg_busy);
         match {.num, .den} = x;
         fReg <= DivState{d: unpack({1'b0,pack(den)}),
                          q: 0,
                          r: unpack({2'b0,pack(num)})
                         };
         rg_busy <= True;
      endmethod
   endinterface
   interface Get response;
      method ActionValue#(Tuple2#(UInt#(n),UInt#(n))) get if (rg_busy && done(rg_count));
         DivState#(n) f = fReg;
         f.q = f.q + (-(~f.q));
         if (f.r < 0) begin
             f.q = f.q - 1;
             f.r = f.r + zeroExtendLSB(f.d);
         end
         UInt#(TAdd#(1,n)) qq = unpack(pack(f.q));
         UInt#(TAdd#(1,n)) rr = unpack(truncateLSB(pack(f.r)));
         rg_busy <= False;
         rg_count <= 0;
         return(tuple2(truncate(qq),truncate(rr)));
      endmethod
   endinterface
endmodule

module mkNonPipelinedSignedDivider#(Integer s)(Server#(Tuple2#(Int#(TAdd#(n,n)),Int#(n)),Tuple2#(Int#(n),Int#(n))));

   Server#(Tuple2#(UInt#(TAdd#(n,n)),UInt#(n)),Tuple2#(UInt#(n),UInt#(n))) div <- mkNonPipelinedDivider(s);
   FIFO#(Tuple2#(Bool,Bool)) fSign <- mkFIFO;

   interface Put request;
      method Action put(Tuple2#(Int#(TAdd#(n,n)),Int#(n)) x);
         match {.a, .b} = x;
         UInt#(TAdd#(n,n)) au = unpack(pack(abs(a)));
         UInt#(n) bu = unpack(pack(abs(b)));
         div.request.put(tuple2(au,bu));

         Bool asign = msb(a) != msb(b);
         Bool bsign = msb(a) == 1;
         fSign.enq(tuple2(asign,bsign));
      endmethod
   endinterface

   interface Get response;
      method ActionValue#(Tuple2#(Int#(n),Int#(n))) get;
         match {.au, .bu} <- div.response.get;
         match {.asign, .bsign} <- toGet(fSign).get;

         Int#(n) a = unpack(pack(au));
         Int#(n) b = unpack(pack(bu));

         a = asign ? -a : a;
         b = bsign ? -b : b;

         return(tuple2(a,b));
      endmethod
   endinterface
endmodule

module mkNonPipelinedSquareRooter#(Integer n)(Server#(UInt#(m),Tuple2#(UInt#(m),Bool)))
   provisos(
      // per request of bsc
      Add#(a__, 2, m),
      Log#(TAdd#(1, m), TLog#(TAdd#(m, 1)))
      );

   FIFO#(UInt#(m)) fRequest <- mkLFIFO;
   FIFO#(Tuple2#(UInt#(m),Bool)) fResponse <- mkLFIFO;

   FIFO#(Tuple4#(Maybe#(Bit#(m)),Bit#(m),Bit#(m),Bit#(m))) fFirst <- mkLFIFO;

   Reg#(Bool) busy <- mkReg(False);
   // This is an overestimate of size: can't divide by n
   Reg#(UInt#(TLog#(TAdd#(TDiv#(m, 2), 1)))) count <- mkReg(?);
   Reg#(Tuple4#(Maybe#(Bit#(m)),Bit#(m),Bit#(m),Bit#(m))) workspace <- mkReg(?);

   rule start (!busy);
      let op <- toGet(fRequest).get;
      let s = pack(op);
      Bit#(m) r = 0;
      Bit#(m) b = reverseBits(extend(2'b10));

      let s0 = countZerosMSB(s);
      let b0 = countZerosMSB(b);
      if (s0 > 0) begin
         let shift = (s0 - b0);
         if ((shift & 1) == 1)
            shift = shift + 1;
         b = b >> shift;
      end

      workspace <= tuple4(tagged Invalid,s,r,b);
      busy <= True;
      count <= 0;
   endrule

   let running = (count < fromInteger((valueOf(m) / 2) / n + 1));

   rule work (busy && running);
     count <= count + 1;
     Maybe#(Bit#(m)) res = tpl_1(workspace);
     Bit#(m) s = tpl_2(workspace);
     Bit#(m) r = tpl_3(workspace);
     Bit#(m) b = tpl_4(workspace);

     for (Integer j = 0; j < n; j = j + 1) begin
        if ((count + fromInteger(j)) <= (fromInteger(valueOf(m)/2))) begin
           if (res matches tagged Invalid) begin
              if (b == 0) begin
                 res = tagged Valid r;
              end
              else begin
                 let sum = r + b;

                 if (s >= sum) begin
                    s = s - sum;
                    r = (r >> 1) + b;
                 end
                 else begin
                    r = r >> 1;
                 end

                 b = b >> 2;
              end
           end
        end
     end

     workspace <= tuple4(res,s,r,b);
  endrule

   rule finish (busy && !running);
      match {.res, .s, .r, .b} = workspace;

      fResponse.enq(tuple2(unpack(fromMaybe(0,res)),(s != 0)));
      busy <= False;
   endrule

   interface request = toPut(fRequest);
   interface response = toGet(fResponse);

endmodule

typedef 4 NBits;

(*synthesize*)
module mkTb(Empty);
   Server#(Tuple2#(UInt#(TAdd#(NBits,NBits)),UInt#(NBits)),Tuple2#(UInt#(NBits),UInt#(NBits))) div_dut <- mkNonPipelinedDivider(3);
   Server#(Tuple2#(UInt#(TAdd#(NBits,NBits)),UInt#(NBits)),Tuple2#(UInt#(NBits),UInt#(NBits))) div_mod <- mkDivider(1);
   FIFO#(Tuple2#(UInt#(TAdd#(NBits,NBits)),UInt#(NBits))) divs <- mkSizedFIFO(16);

   Server#(Tuple2#(Int#(TAdd#(NBits,NBits)),Int#(NBits)),Tuple2#(Int#(NBits),Int#(NBits))) sdiv_dut <- mkNonPipelinedSignedDivider(3);
   Server#(Tuple2#(Int#(TAdd#(NBits,NBits)),Int#(NBits)),Tuple2#(Int#(NBits),Int#(NBits))) sdiv_mod <- mkSignedDivider(1);
   FIFO#(Tuple2#(Int#(TAdd#(NBits,NBits)),Int#(NBits))) sdivs <- mkSizedFIFO(16);

   function Action testDividePipe(UInt#(TAdd#(NBits,NBits)) ni, UInt#(NBits) di);
      action
         div_dut.request.put(tuple2(ni,di));
         div_mod.request.put(tuple2(ni,di));
         divs.enq(tuple2(ni,di));
      endaction
   endfunction

   function Action testSignedDividePipe(Int#(TAdd#(NBits,NBits)) ni, Int#(NBits) di);
      action
         sdiv_dut.request.put(tuple2(ni,di));
         sdiv_mod.request.put(tuple2(ni,di));
         sdivs.enq(tuple2(ni,di));
      endaction
   endfunction

   Vector#(4,Randomize#(Bit#(64))) rando <- replicateM(mkGenericRandomizer());

   Reg#(Bit#(32)) count <- mkReg(0);

   rule initialize(count == 0);
      for (Integer i = 0; i < 4; i = i + 1)
         rando[i].cntrl.init();
      count <= count + 1;
   endrule

   rule issueDivs(count > 0);
      Vector#(4, Bit#(TAdd#(NBits,NBits))) r = ?;
      for (Integer i = 0; i < 4; i = i + 1) begin
         Bit#(64) _ <- rando[i].next();
         r[i] = truncate(_);
      end
      testDividePipe(unpack(r[0]), truncate(unpack(r[1])));
      //testSignedDividePipe(unpack(r[2]), truncate(unpack(r[3])));
      count <= count + 1;
      if (count > 2) begin
         $display("Finished %d examples", count);
         $finish();
      end
   endrule

   rule check;
      match {.n, .d} <- toGet(divs).get;
      match {.qq, .pp} <- div_dut.response.get;
      match {.q, .p}   <- div_mod.response.get;

      if (q != qq) begin
         $display("quot(%x,%x) = %x (expected %x)", n, d, qq, q);
      end

      if (p != pp) begin
         $display("rem(%x,%x) = %x (expected %x)", n, d, pp, p);
      end

   endrule

   rule check_sdiv;
      match {.n, .d} <- toGet(sdivs).get;
      match {.qq, .pp} <- sdiv_dut.response.get;
      match {.q, .p}   <- sdiv_mod.response.get;

      if (q != qq) begin
         $display("squot(%x,%x) = %x (expected %x)", n, d, qq, q);
      end

      if (p != pp) begin
         $display("srem(%x,%x) = %x (expected %x)", n, d, pp, p);
      end

   endrule

endmodule

endpackage
