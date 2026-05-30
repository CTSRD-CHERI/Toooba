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

import AXI4_Types :: *;

import FIFOF :: *;
import SpecialFIFOs :: *;

////////////////////////////////
// AXI Write Response Channel //
////////////////////////////////////////////////////////////////////////////////

// map over flit type
////////////////////////////////////////////////////////////////////////////////

function AXI4_BFlit #(id_out, user)
  mapAXI4_BFlit_bid (
    function Bit #(id_out) f (Bit #(id_in) a)
  , AXI4_BFlit #(id_in, user) x ) =
  AXI4_BFlit { bid:   f (x.bid)
             , bresp: x.bresp
             , buser: x.buser };

function AXI4_BFlit #(id, user_out)
  mapAXI4_BFlit_buser (
    function Bit #(user_out) f (Bit #(user_in) a)
  , AXI4_BFlit #(id, user_in) x ) =
  AXI4_BFlit { bid:   x.bid
             , bresp: x.bresp
             , buser: f (x.buser) };

// typeclasses to convert to/from the flit type
////////////////////////////////////////////////////////////////////////////////

typeclass ToAXI4_BFlit#(type t, numeric type id_, numeric type user_);
  function AXI4_BFlit#(id_, user_) toAXI4_BFlit (t x);
endtypeclass

instance ToAXI4_BFlit#(AXI4_BFlit#(a, b), a, b);
  function toAXI4_BFlit = id;
endinstance

typeclass FromAXI4_BFlit#(type t, numeric type id_, numeric type user_);
  function t fromAXI4_BFlit (AXI4_BFlit#(id_, user_) x);
endtypeclass

instance FromAXI4_BFlit#(AXI4_BFlit#(a, b), a, b);
  function fromAXI4_BFlit = id;
endinstance

// convert to/from Sig Master interface
////////////////////////////////////////////////////////////////////////////////

module toAXI4_B_Master_Sig #(snk_t m) (AXI4_B_Master_Sig#(id_, user_))
  provisos (ToSink#(snk_t, t), FromAXI4_BFlit#(t, id_, user_), Bits#(t, t_sz));
  let snk <- toUnguardedSink(m);
  method bflit(bvalid, bid, bresp, buser) = action
    if (bvalid && snk.canPut) snk.put(fromAXI4_BFlit(AXI4_BFlit{
      bid: bid, bresp: bresp, buser: buser
    }));
  endaction;
  method bready = snk.canPut;
endmodule

module fromAXI4_B_Master_Sig #(AXI4_B_Master_Sig#(id_, user_) m)
                              (Sink#(AXI4_BFlit#(id_, user_)));
  // We use a guarded buffer to export as a guarded sink, and use an unguarded
  // source as an internal interface to it for connection to the Sig interface
  FIFOF#(AXI4_BFlit#(id_, user_)) buffer <- mkSizedBypassFIFOF(1);
  let src <- toUnguardedSource(buffer, ?);
  (* fire_when_enabled, no_implicit_conditions *)
  rule forwardFlit;
    m.bflit(src.canPeek, src.peek.bid, src.peek.bresp, src.peek.buser);
  endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule dropFlit (src.canPeek && m.bready); src.drop; endrule
  return toSink(buffer);
endmodule

// convert to/from Sig Slave interface
////////////////////////////////////////////////////////////////////////////////

module toAXI4_B_Slave_Sig #(src_t#(t) s) (AXI4_B_Slave_Sig#(id_, user_))
  provisos ( ToSource#(src_t#(t), t)
           , ToAXI4_BFlit#(t, id_, user_)
           , Bits#(t, t_sz));
  let src <- toUnguardedSource(s, ?);
  AXI4_BFlit#(id_, user_) flit = toAXI4_BFlit(src.peek);
  method bid    = flit.bid;
  method bresp  = flit.bresp;
  method buser  = flit.buser;
  method bvalid = src.canPeek;
  method bready(rdy) = action if (src.canPeek && rdy) src.drop; endaction;
endmodule

module fromAXI4_B_Slave_Sig #(AXI4_B_Slave_Sig#(id_, user_) s)
                             (Source#(AXI4_BFlit#(id_, user_)));
  FIFOF#(AXI4_BFlit#(id_, user_)) buffer <- mkSizedBypassFIFOF(1);
  let snk <- toUnguardedSink(buffer);
  (* fire_when_enabled, no_implicit_conditions *)
  rule forwardFlit (s.bvalid && snk.canPut);
    snk.put (AXI4_BFlit { bid:   s.bid
                        , bresp: s.bresp
                        , buser: s.buser });
  endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule forwardReady; s.bready(snk.canPut); endrule
  return toSource(buffer);
endmodule
