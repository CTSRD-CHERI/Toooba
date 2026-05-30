/*-
 * Copyright (c) 2021 Ivan Ribeiro
 * Copyright (c) 2021-2022 Alexandre Joannou
 * All rights reserved.
 *
 * This hardware design was developed by the University of Cambridge Computer
 * Laboratory (Department of Computer Science and Technology) under EPSRC award
 * EP/S030867/1 ("SIPP"); and by SRI International and the University of
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

package AXI4Stream_Utils;

import FIFOF :: *;
import SpecialFIFOs :: *;

// BlueBasics import
import SourceSink :: *;

// AXI4 import
import AXI4Stream_Types :: *;

module mkAXI4StreamShim
  #(function module #(source_sink_t #(AXI4Stream_Flit #(a, b, c, d))) mkSS ())
  (AXI4Stream_Shim#(a, b, c, d))
  provisos (ToSourceSinkShim #( source_sink_t #(AXI4Stream_Flit #(a, b, c, d))
                              , AXI4Stream_Flit #(a, b, c, d) ));
  let ss <- mkSS;
  interface master = toSource(ss);
  interface slave  = toSink(ss);
endmodule

`define defAXI4StreamShimFIFOF (name, mkSS)\
module mkAXI4StreamShim``name (AXI4Stream_Shim#(a, b, c, d));\
  let shim <- mkAXI4StreamShim (mkSS);\
  return shim;\
endmodule

`defAXI4StreamShimFIFOF(BypassFIFOF, mkBypassFIFOF)
`defAXI4StreamShimFIFOF(BypassFF1, mkSizedBypassFIFOF(1))
`defAXI4StreamShimFIFOF(FF1, mkFIFOF1)
`defAXI4StreamShimFIFOF(FF, mkFIFOF)
`defAXI4StreamShimFIFOF(SizedFIFOF4, mkSizedFIFOF(4))
`defAXI4StreamShimFIFOF(SizedFIFOF32, mkSizedFIFOF(32))
`defAXI4StreamShimFIFOF(UGSizedFIFOF32, mkUGSizedFIFOF(32))
`defAXI4StreamShimFIFOF(UGSizedFIFOF4, mkUGSizedFIFOF(4))
`defAXI4StreamShimFIFOF(UGFF, mkUGFIFOF)

typeclass ToAXI4Stream_Flit #( type t
                             , numeric type id_
                             , numeric type data_
                             , numeric type dest_
                             , numeric type user_);
  function AXI4Stream_Flit #(id_, data_, dest_, user_) toAXI4Stream_Flit (t x);
endtypeclass

instance ToAXI4Stream_Flit #( AXI4Stream_Flit #(id_, data_, dest_, user_)
                            , id_, data_, dest_, user_);
  function toAXI4Stream_Flit = id;
endinstance

typeclass FromAXI4Stream_Flit #( type t
                               , numeric type id_
                               , numeric type data_
                               , numeric type dest_
                               , numeric type user_);
  function t
    fromAXI4Stream_Flit (AXI4Stream_Flit #(id_, data_, dest_, user_) x);
endtypeclass

instance FromAXI4Stream_Flit #( AXI4Stream_Flit #(id_, data_, dest_, user_)
                              , id_, data_, dest_, user_);
  function fromAXI4Stream_Flit = id;
endinstance


module toAXI4Stream_Master_Sig #(src_t #(t) s)
  (AXI4Stream_Master_Sig #(id_, data_, dest_, user_))
  provisos ( ToSource #(src_t #(t), t)
           , ToAXI4Stream_Flit #(t, id_, data_, dest_, user_)
           , Bits #(t, t_sz));
  let src <- toUnguardedSource (s, ?);
  AXI4Stream_Flit #(id_, data_, dest_, user_)
    flit = toAXI4Stream_Flit (src.peek);
  method tdata  = flit.tdata;
  method tstrb  = flit.tstrb;
  method tkeep  = flit.tkeep;
  method tlast  = flit.tlast;
  method tid    = flit.tid;
  method tdest  = flit.tdest;
  method tuser  = flit.tuser;
  method tvalid = src.canPeek;
  method tready (rdy) = action if (src.canPeek && rdy) src.drop; endaction;
endmodule


module toAXI4Stream_Slave_Sig #(snk_t s)
  (AXI4Stream_Slave_Sig #(id_, data_, dest_, user_))
  provisos ( ToSink #(snk_t, t)
           , FromAXI4Stream_Flit #(t, id_, data_, dest_, user_)
           , Bits #(t, t_sz));
  let snk <- toUnguardedSink (s);

  method tflit (tvalid, tdata, tstrb, tkeep, tlast, tid, tdest, tuser) =
    action
      if (tvalid && snk.canPut)
        snk.put (fromAXI4Stream_Flit (AXI4Stream_Flit { tdata: tdata
                                                      , tstrb: tstrb
                                                      , tkeep: tkeep
                                                      , tlast: tlast
                                                      , tid  : tid
                                                      , tdest: tdest
                                                      , tuser: tuser }));
    endaction;
  method tready = snk.canPut;
endmodule

function AXI4Stream_Master #(id_, data_, dest_, user_)
  debugAXI4Stream_Master ( AXI4Stream_Master #(id_, data_, dest_, user_) m
                         , Fmt msg) = debugSource (m, $format (msg, " t"));

function AXI4Stream_Slave #(id_, data_, dest_, user_)
  debugAXI4Stream_Slave ( AXI4Stream_Slave #(id_, data_, dest_, user_) s
                        , Fmt msg) = debugSink (s,$format (msg, " t"));

module toUnguarded_AXI4Stream_Master
  #(AXI4Stream_Master #(id_, data_, dest_, user_) m)
   (AXI4Stream_Master #(id_, data_, dest_, user_));
  let ugm <- toUnguardedSource (m, ?);
  return ugm;
endmodule

module mkAXI4StreamWideToNarrow
  (Tuple2 #( AXI4Stream_Slave #(id_, data_wide, dest_, user_)
           , AXI4Stream_Master #(id_, data_narrow, dest_, user_) ))
  provisos ( NumAlias #(n, TDiv #(data_wide, data_narrow))
           , Add #(_a, data_narrow, data_wide)
           , Add #(_b, TDiv #(data_narrow, 8), TDiv #(data_wide, 8)) );

  Reg #(Bit #(data_wide)) tdata <- mkRegU;
  Reg #(Bit #(TDiv#(data_wide, 8))) tstrb <- mkRegU;
  Reg #(Bit #(TDiv#(data_wide, 8))) tkeep <- mkRegU;
  Reg #(Bool) tlast <- mkRegU;
  Reg #(Bit #(id_)) tid <- mkRegU;
  Reg #(Bit #(dest_)) tdest <- mkRegU;
  Reg #(Bit #(user_)) tuser <- mkRegU;

  Reg #(Bit #(TLog#(n))) cnt <- mkRegU;
  Reg #(Bool) busy <- mkReg(False);

  return tuple2(
    interface AXI4Stream_Slave;
      method canPut = !busy;
      method put(x) if (!busy) = action
        tdata <= x.tdata;
        tstrb <= x.tstrb;
        tkeep <= x.tkeep;
        tlast <= x.tlast;
        tid   <= x.tid;
        tdest <= x.tdest;
        tuser <= x.tuser;
        cnt   <= fromInteger(valueOf(TSub#(n, 1)));
        busy  <= True;
      endaction;
    endinterface
  , interface AXI4Stream_Master;
      method canPeek = busy;
      method peek if (busy) = AXI4Stream_Flit {
          tdata: truncate(tdata)
        , tstrb: truncate(tstrb)
        , tkeep: truncate(tkeep)
        , tlast: tlast && (cnt == 0)
        , tid: tid
        , tdest: tdest
        , tuser: tuser
        };
      method drop if (busy) = action
        tdata <= tdata >> valueOf(data_narrow);
        tstrb <= tstrb >> valueOf(TDiv#(data_narrow, 8));
        tkeep <= tkeep >> valueOf(TDiv#(data_narrow, 8));
        cnt <= cnt - 1;
        busy <= cnt != 0;
      endaction;
    endinterface
  );

endmodule

module mkAXI4StreamNarrowToWide
  (Tuple2 #( AXI4Stream_Slave #(id_, data_narrow, dest_, user_)
           , AXI4Stream_Master #(id_, data_wide, dest_, user_) ))
  provisos ( NumAlias #(n, TDiv #(data_wide, data_narrow))
           , Add #(_a, data_narrow, data_wide)
           , Add #(_b, TDiv #(data_narrow, 8), TDiv #(data_wide, 8)) );

  Reg #(Bit #(data_wide)) tdata <- mkRegU;
  Reg #(Bit #(TDiv#(data_wide, 8))) tstrb <- mkReg(0);
  Reg #(Bit #(TDiv#(data_wide, 8))) tkeep <- mkReg(0);
  Reg #(Bool) tlast <- mkRegU;
  Reg #(Bit #(id_)) tid <- mkRegU;
  Reg #(Bit #(dest_)) tdest <- mkRegU;
  Reg #(Bit #(user_)) tuser <- mkRegU;

  Reg #(Bit #(TLog#(n))) cnt <- mkRegU;
  Reg #(Bool) flitReady <- mkReg(False);

  return tuple2(
    interface AXI4Stream_Slave;
      method canPut = !flitReady;
      method put(x) if (!flitReady) = action
        tdata <= (tdata >> valueOf(data_narrow)) | {x.tdata, 0};
        tstrb <= (tstrb >> valueOf(TDiv#(data_narrow, 8))) | {x.tstrb, 0};
        tkeep <= (tkeep >> valueOf(TDiv#(data_narrow, 8))) | {x.tkeep, 0};
        tlast <= x.tlast;
        tid   <= x.tid;
        tdest <= x.tdest;
        tuser <= x.tuser;
        cnt   <= cnt - 1;
        flitReady <= x.tlast || cnt == 1;
      endaction;
    endinterface
  , interface AXI4Stream_Master;
      method canPeek = flitReady;
      method peek if (flitReady) = AXI4Stream_Flit {
          tdata: tdata
        , tstrb: tstrb
        , tkeep: tkeep
        , tlast: tlast
        , tid: tid
        , tdest: tdest
        , tuser: tuser
        };
      method drop if (flitReady) = action
        tdata <= ?;
        tstrb <= 0;
        tkeep <= 0;
        cnt <= fromInteger(valueOf(n));
        flitReady <= False;
      endaction;
    endinterface
  );

endmodule

module toUnguarded_AXI4Stream_Slave
  #(AXI4Stream_Slave #(id_, data_, dest_, user_) s)
   (AXI4Stream_Slave #(id_, data_, dest_, user_));
   let ugs <- toUnguardedSink (s);
   return ugs;
endmodule

endpackage
