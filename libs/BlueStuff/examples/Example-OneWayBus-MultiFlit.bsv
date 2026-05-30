/*-
 * Copyright (c) 2018-2020 Alexandre Joannou
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory (Department of Computer Science and
 * Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
 * DARPA SSITH research programme.
 *
 * @BERI_LICENSE_HEADER_START@
 *
 * Licensed to BERI Open Systems C.I.C. (BERI) under one or more contributor
 * license agreements.  See the NOTICE file distributed with this work for
 * additional information regarding copyright ownership.  BERI licenses this
 * file to you under the BERI Hardware-Software License, Version 1.0 (the
 * "License"); you may not use this file except in compliance with the
 * License.  You may obtain a copy of the License at:
 *
 *   http://www.beri-open-systems.org/legal/license-1-0.txt
 *
 * Unless required by applicable law or agreed to in writing, Work distributed
 * under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * @BERI_LICENSE_HEADER_END@
 */

import Routable   :: *;
import ListExtra  :: *;
import OneWayBus  :: *;
import SourceSink :: *;

import FIFOF :: *;
import Vector :: *;
import ConfigReg :: *;

typedef struct {
  Bit#(i) id;
  Vector#(o, Bool) dest;
  Bool last;
} Flit#(numeric type i, numeric type o) deriving (Bits);
instance FShow#(Flit#(a,b));
  function fshow(x) =
    $format("[id = %0d, dest = %b]", x.id, x.dest);
endinstance
instance Has_routingField #(Flit#(i,o), Vector#(o, Bool));
  function routingField(x) = x.dest;
endinstance
instance Has_isLast #(Flit#(i,o));
  function isLast(x) = x.last;
endinstance

function Vector#(n, Bool) route (Bit#(a) x);
  case (firstHotToOneHot(toList(unpack(x)))) matches
    tagged Valid .dest: return toVector(dest);
    tagged Invalid: return replicate(False);
  endcase
endfunction

typedef 4 NIns;
typedef 3 NOuts;
Integer nb_flits = 2;

module top (Empty);

  Integer nIns  = valueOf(NIns);
  Integer nOuts = valueOf(NOuts);


  Vector#(NIns,  FIFOF#(Flit#(NIns, NOuts)))  ins <- replicateM(mkFIFOF);
  Vector#(NOuts, FIFOF#(Flit#(NIns, NOuts))) outs <- replicateM(mkFIFOF);

  let cnt <- mkReg(0);
  rule count; cnt <= cnt + 1; endrule

  for (Integer i = 0; i < nIns; i = i + 1) begin
    Reg#(Vector#(NOuts, Bool)) next <- mkConfigReg(cons(True, replicate(False)));
    let localCnt <- mkReg (0);
    rule doEnq;
      if (localCnt >= fromInteger(nb_flits)) begin
        localCnt <= 0;
        next <= rotate(next);
      end else begin
        localCnt <= localCnt + 1;
        Flit#(NIns, NOuts) flit = Flit {
          id: fromInteger(i),
          dest: next,
          last: localCnt == fromInteger(nb_flits - 1)
        };
        ins[i].enq(flit);
        $display ("%0t - %m enq[%0d]: ", $time, i, fshow (flit));
      end
    endrule
  end
  for (Integer i = 0; i < nOuts; i = i + 1)
    rule doDeq (cnt % fromInteger(i+1) == fromInteger(i));
      outs[i].deq;
      $display("%0t -- dest %0d received from id %0d -- ", $time, i, outs[i].first.id, fshow(outs[i].first));
    endrule

  mkOneWayBus(id, ins, outs);

  rule terminate(cnt > 200); $finish(0); endrule

endmodule
