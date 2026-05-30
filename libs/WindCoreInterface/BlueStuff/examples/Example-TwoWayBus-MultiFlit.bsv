/*-
 * Copyright (c) 2018-2021 Alexandre Joannou
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

import Routable     :: *;
import ListExtra    :: *;
import SourceSink   :: *;
import MasterSlave  :: *;
import Interconnect :: *;

import FIFOF     :: *;
import Vector    :: *;
import ConfigReg :: *;

typedef 1 NMasters;
typedef 1 NSlaves;
Integer nb_flit = 16;
Integer nb_rsp = 4;

function Bit#(n) firstHot(Bit#(n) x);
  Bit#(n) res = 0;
  Bool found = False;
  for (Integer i = valueOf(n) - 1; i >= 0; i = i - 1) begin
    if (x[i] == 1) found = True;
    res[i] = (found) ? 0 : x[i];
  end
  return res;
endfunction

typedef struct {
  Bit #(TLog #(NSlaves)) to;
  Bit#(32) payload;
  Bool last;
} Req deriving (Bits);
instance FShow#(Req);
  function fshow(x) = $format( "Req { to:%b, payload: %0d, last: "
                             , x.to, x.payload, fshow (x.last), " }");
endinstance
instance Has_routingField #(Req, Bit #(TLog #(NSlaves)));
  function routingField (x) = x.to;
endinstance
instance Has_isLast #(Req); function isLast (x) = x.last; endinstance

typedef enum {OK, KO} RStatus deriving (Bits, Eq, FShow);
typedef struct {
  RStatus status;
} Rsp deriving (Bits, FShow);
instance Has_isLast #(Rsp); function isLast = constFn (True); endinstance

typedef WithRouteInfo #(Req, Bit #(TLog #(NMasters))) ReqFat;
typedef WithRouteInfo #(Rsp, Bit #(TLog #(NMasters))) RspFat;
instance ExpandableReqRsp #(Req, ReqFat, RspFat, Rsp, NMasters);
  function expand (x, r) = ReqFat { routeInfo: x, payload: r};
  function shrink (r) = tuple2 (r.routeInfo, r.payload);
endinstance
instance FallibleRoute #(ReqFat, RspFat);
  module mkNoRouteSlave (Slave #( ReqFat, RspFat));
    let ff <- mkFIFOF1;
    interface req = interface Sink;
      method  canPut = ff.notFull;
      method put (x) = ff.enq (x.routeInfo);
    endinterface;
    interface rsp = interface Source;
      method canPeek = ff.notEmpty;
      method peek if (ff.notEmpty) = RspFat { routeInfo: ff.first
                                            , payload:  Rsp { status: KO } };
      method drop if (ff.notEmpty) = ff.deq;
    endinterface;
  endmodule
endinstance

module mkMaster (Master#(Req, Rsp));
  Reg#(Bit #(TLog #(NSlaves))) dest <- mkConfigReg(0);
  let ff <- mkFIFOF;
  Reg#(Bool) reqSent <- mkReg (False);
  Reg#(Bit#(32)) rspCnt <- mkReg (0);
  Reg#(Bit#(32)) cnt <- mkReg (0);
  rule enq (!reqSent);
    dest <= dest + 1;
    let req = Req { to: dest
                  , payload: cnt
                  , last: cnt == fromInteger (nb_flit - 1) };
    ff.enq(req);
    if (cnt == fromInteger (nb_flit - 1)) begin
      cnt <= 0;
      reqSent <= True;
    end else cnt <= cnt + 1;
    $display("%0t -- Master sending ", $time, fshow(req));
  endrule
  interface req = toSource(ff);
  interface rsp = interface Sink;
    method put(x) if (reqSent) = action
      $display("%0t -- Master received ", $time, fshow(x));
      reqSent <= False;
      if (rspCnt == fromInteger (nb_rsp - 1)) $finish(0);
      else rspCnt <= rspCnt + 1;
    endaction;
    method canPut = True;
  endinterface;
endmodule

module mkSlave (Slave#(ReqFat, RspFat));
  let ff <- mkFIFOF;
  interface req = interface Sink;
    method put(x) = action
      $display("%0t -- -- -- Slave received ", $time, fshow(x));
      if (isLast (x)) begin
        $display("%0t -- -- -- Slave sending rsp", $time);
        ff.enq(RspFat { routeInfo: x.routeInfo
                      , payload: Rsp { status: OK } });
      end
    endaction;
    method canPut = ff.notFull;
  endinterface;
  interface rsp = toSource(ff);
endmodule

module top (Empty);

  Vector#(NMasters, Master #(Req,    Rsp))    masters <- replicateM(mkMaster);
  Vector#(NSlaves,  Slave  #(ReqFat, RspFat)) slaves  <- replicateM(mkSlave);

  let cnt <- mkReg(0);
  rule count; cnt <= cnt + 1; endrule

  mkRelaxedTwoWayBus(indexToOneHot, masters, slaves);

  rule terminate(cnt > 3000); $finish(0); endrule

endmodule
