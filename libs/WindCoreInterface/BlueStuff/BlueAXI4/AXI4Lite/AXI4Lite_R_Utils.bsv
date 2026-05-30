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

import SourceSink :: *;

import AXI4Lite_Types :: *;

import FIFOF :: *;
import SpecialFIFOs :: *;

///////////////////////////
// AXI Read Data Channel //
////////////////////////////////////////////////////////////////////////////////

// map over flit type
////////////////////////////////////////////////////////////////////////////////

function AXI4Lite_RFlit #(data_out, user)
  mapAXI4Lite_RFlit_rdata ( function Bit #(data_out) f (Bit #(data_in) a)
                          , AXI4Lite_RFlit #(data_in, user) x ) =
  AXI4Lite_RFlit { rdata: f (x.rdata), rresp: x.rresp, ruser: x.ruser };

function AXI4Lite_RFlit #(data, user_out)
  mapAXI4Lite_RFlit_ruser ( function Bit #(user_out) f (Bit #(user_in) a)
                          , AXI4Lite_RFlit #(data, user_in) x ) =
  AXI4Lite_RFlit { rdata: x.rdata, rresp: x.rresp, ruser: f (x.ruser) };

// typeclasses to convert to/from the flit type
////////////////////////////////////////////////////////////////////////////////

typeclass ToAXI4Lite_RFlit#(type t, numeric type data_, numeric type user_);
  function AXI4Lite_RFlit#(data_, user_) toAXI4Lite_RFlit (t x);
endtypeclass

instance ToAXI4Lite_RFlit#(AXI4Lite_RFlit#(a, b), a, b);
  function toAXI4Lite_RFlit = id;
endinstance

typeclass FromAXI4Lite_RFlit#(type t, numeric type data_, numeric type user_);
  function t fromAXI4Lite_RFlit (AXI4Lite_RFlit#(data_, user_) x);
endtypeclass

instance FromAXI4Lite_RFlit#(AXI4Lite_RFlit#(a, b), a, b);
  function fromAXI4Lite_RFlit = id;
endinstance

// convert to/from Sig Master interface
////////////////////////////////////////////////////////////////////////////////

module toAXI4Lite_R_Master_Sig #(snk_t m)
                                (AXI4Lite_R_Master_Sig#(data_, user_))
  provisos ( ToSink#(snk_t, t)
           , FromAXI4Lite_RFlit#(t, data_, user_)
           , Bits#(t, t_sz));
  let snk <- toUnguardedSink(m);
  method rflit(rvalid, rdata, rresp, ruser) = action
    if (rvalid && snk.canPut) snk.put(fromAXI4Lite_RFlit(AXI4Lite_RFlit{
      rdata: rdata, rresp: rresp, ruser: ruser
    }));
  endaction;
  method rready = snk.canPut;
endmodule

module fromAXI4Lite_R_Master_Sig #(AXI4Lite_R_Master_Sig#(data_, user_) m)
                                  (Sink#(AXI4Lite_RFlit#(data_, user_)));
  // We use a guarded buffer to export as a guarded sink, and use an unguarded
  // source as an internal interface to it for connection to the Sig interface
  FIFOF#(AXI4Lite_RFlit#(data_, user_)) buffer <- mkSizedBypassFIFOF(1);
  let src <- toUnguardedSource(buffer, ?);
  (* fire_when_enabled, no_implicit_conditions *)
  rule forwardFlit;
    m.rflit(src.canPeek, src.peek.rdata, src.peek.rresp, src.peek.ruser);
  endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule dropFlit (src.canPeek && m.rready); src.drop; endrule
  return toSink(buffer);
endmodule

// convert to/from Sig Slave interface
////////////////////////////////////////////////////////////////////////////////

module toAXI4Lite_R_Slave_Sig #(src_t#(t) s)
                               (AXI4Lite_R_Slave_Sig#(data_, user_))
  provisos ( ToSource#(src_t#(t), t)
           , ToAXI4Lite_RFlit#(t, data_, user_)
           , Bits#(t, t_sz));
  let src <- toUnguardedSource(s, ?);
  AXI4Lite_RFlit#(data_, user_) flit = toAXI4Lite_RFlit(src.peek);
  method rdata  = flit.rdata;
  method rresp  = flit.rresp;
  method ruser  = flit.ruser;
  method rvalid = src.canPeek;
  method rready(rdy) = action if (src.canPeek && rdy) src.drop; endaction;
endmodule

module fromAXI4Lite_R_Slave_Sig #(AXI4Lite_R_Slave_Sig#(data_, user_) s)
                                 (Source#(AXI4Lite_RFlit#(data_, user_)));
  FIFOF#(AXI4Lite_RFlit#(data_, user_)) buffer <- mkSizedBypassFIFOF(1);
  let snk <- toUnguardedSink(buffer);
  (* fire_when_enabled, no_implicit_conditions *)
  rule forwardFlit (s.rvalid && snk.canPut);
    snk.put (AXI4Lite_RFlit { rdata: s.rdata
                            , rresp: s.rresp
                            , ruser: s.ruser });
  endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule forwardReady; s.rready(snk.canPut); endrule
  return toSource(buffer);
endmodule
