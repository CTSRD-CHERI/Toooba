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
  #(function module #(FIFOF #(AXI4Stream_Flit #(a, b, c, d))) mkFF ())
  (AXI4Stream_Shim#(a, b, c, d));
  let ff <- mkFF;
  method clear = ff.clear;
  interface master = toSource(ff);
  interface slave  = toSink(ff);
endmodule

`define defAXI4StreamShimFIFOF (name, mkFF)\
module mkAXI4StreamShim``name (AXI4Stream_Shim#(a, b, c, d));\
  let shim <- mkAXI4StreamShim (mkFF);\
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

module toUnguarded_AXI4Stream_Slave
  #(AXI4Stream_Slave #(id_, data_, dest_, user_) s)
   (AXI4Stream_Slave #(id_, data_, dest_, user_));
   let ugs <- toUnguardedSink (s);
   return ugs;
endmodule

endpackage
