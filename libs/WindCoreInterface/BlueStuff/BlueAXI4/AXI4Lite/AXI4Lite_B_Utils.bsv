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

import SourceSink :: *;

import AXI4Lite_Types :: *;

import FIFOF :: *;
import SpecialFIFOs :: *;

////////////////////////////////
// AXI Write Response Channel //
////////////////////////////////////////////////////////////////////////////////

// map over flit type
////////////////////////////////////////////////////////////////////////////////

function AXI4Lite_BFlit #(user_out)
  mapAXI4Lite_BFlit_buser ( function Bit #(user_out) f (Bit #(user_in) a)
                          , AXI4Lite_BFlit #(user_in) x ) =
  AXI4Lite_BFlit { bresp: x.bresp, buser: f (x.buser) };

// typeclasses to convert to/from the flit type
////////////////////////////////////////////////////////////////////////////////

typeclass ToAXI4Lite_BFlit#(type t, numeric type user_);
  function AXI4Lite_BFlit#(user_) toAXI4Lite_BFlit (t x);
endtypeclass

instance ToAXI4Lite_BFlit#(AXI4Lite_BFlit#(user_), user_);
  function toAXI4Lite_BFlit = id;
endinstance

typeclass FromAXI4Lite_BFlit#(type t, numeric type user_);
  function t fromAXI4Lite_BFlit (AXI4Lite_BFlit#(user_) x);
endtypeclass

instance FromAXI4Lite_BFlit#(AXI4Lite_BFlit#(user_), user_);
  function fromAXI4Lite_BFlit = id;
endinstance

// convert to/from Sig Master interface
////////////////////////////////////////////////////////////////////////////////

module toAXI4Lite_B_Master_Sig #(snk_t m) (AXI4Lite_B_Master_Sig#(user_))
  provisos (ToSink#(snk_t, t), FromAXI4Lite_BFlit#(t, user_), Bits#(t, t_sz));
  let snk <- toUnguardedSink(m);
  method bflit(bvalid, bresp, buser) = action
    if (bvalid && snk.canPut) snk.put(fromAXI4Lite_BFlit(AXI4Lite_BFlit{
      bresp: bresp, buser: buser
    }));
  endaction;
  method bready = snk.canPut;
endmodule

module fromAXI4Lite_B_Master_Sig #(AXI4Lite_B_Master_Sig#(user_) m)
                                  (Sink#(AXI4Lite_BFlit#(user_)));
  // We use a guarded buffer to export as a guarded sink, and use an unguarded
  // source as an internal interface to it for connection to the Sig interface
  FIFOF#(AXI4Lite_BFlit#(user_)) buffer <- mkSizedBypassFIFOF(1);
  let src <- toUnguardedSource(buffer, ?);
  (* fire_when_enabled, no_implicit_conditions *)
  rule forwardFlit;
    m.bflit(src.canPeek, src.peek.bresp, src.peek.buser);
  endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule dropFlit (src.canPeek && m.bready); src.drop; endrule
  return toSink(buffer);
endmodule

// convert to/from Sig Slave interface
////////////////////////////////////////////////////////////////////////////////

module toAXI4Lite_B_Slave_Sig #(src_t#(t) s) (AXI4Lite_B_Slave_Sig#(user_))
  provisos ( ToSource#(src_t#(t), t)
           , ToAXI4Lite_BFlit#(t, user_)
           , Bits#(t, t_sz));
  let src <- toUnguardedSource(s, ?);
  AXI4Lite_BFlit#(user_) flit = toAXI4Lite_BFlit(src.peek);
  method bresp  = flit.bresp;
  method buser  = flit.buser;
  method bvalid = src.canPeek;
  method bready(rdy) = action if (src.canPeek && rdy) src.drop; endaction;
endmodule

module fromAXI4Lite_B_Slave_Sig #(AXI4Lite_B_Slave_Sig#(user_) s)
                                 (Source#(AXI4Lite_BFlit#(user_)));
  FIFOF#(AXI4Lite_BFlit#(user_)) buffer <- mkSizedBypassFIFOF(1);
  let snk <- toUnguardedSink(buffer);
  (* fire_when_enabled, no_implicit_conditions *)
  rule forwardFlit (s.bvalid && snk.canPut);
    snk.put (AXI4Lite_BFlit { bresp: s.bresp, buser: s.buser });
  endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule forwardReady; s.bready(snk.canPut); endrule
  return toSource(buffer);
endmodule
