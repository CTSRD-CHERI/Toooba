/*-
 * Copyright (c) 2018-2022 Alexandre Joannou
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

import BlueBasics :: *;

import AXI4_Types :: *;

import Probe :: *;
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

typeclass ToAXI4_BFlit#(type t, numeric type id_, numeric type user_)
  dependencies ( t determines (id_, user_)
               , (id_, user_) determines t );
  function AXI4_BFlit#(id_, user_) toAXI4_BFlit (t x);
endtypeclass

instance ToAXI4_BFlit#(AXI4_BFlit#(a, b), a, b);
  function toAXI4_BFlit = id;
endinstance

typeclass FromAXI4_BFlit#(type t, numeric type id_, numeric type user_)
  dependencies ( t determines (id_, user_)
               , (id_, user_) determines t );
  function t fromAXI4_BFlit (AXI4_BFlit#(id_, user_) x);
endtypeclass

instance FromAXI4_BFlit#(AXI4_BFlit#(a, b), a, b);
  function fromAXI4_BFlit = id;
endinstance

// augment master / slave Sig "on action" function
////////////////////////////////////////////////////////////////////////////////

function AXI4_B_Master_Sig #(id_, user_)
  on_bready ( function Action f ( Bool _valid
                                , Bool _ready
                                , AXI4_BFlit #(id_, user_) _flit )
           , AXI4_B_Master_Sig #(id_, user_) m ) =
  interface AXI4_B_Master_Sig;
    method bflit (bvalid, bid, bresp, buser) = action
      f (bvalid, m.bready, AXI4_BFlit { bid: bid
                                      , bresp: bresp
                                      , buser: buser });
      m.bflit (bvalid, bid, bresp, buser);
    endaction;
    method bready = m.bready;
  endinterface;

function AXI4_B_Slave_Sig #(id_, user_)
  on_bflit ( function Action f ( Bool _valid
                               , Bool _ready
                               , AXI4_BFlit #(id_, user_) _flit )
            , AXI4_B_Slave_Sig #(id_, user_) s) =
  interface AXI4_B_Slave_Sig;
    method bid = s.bid;
    method bresp = s.bresp;
    method buser = s.buser;
    method bvalid  = s.bvalid;
    method bready (rdy) = action
      f (s.bvalid, rdy, AXI4_BFlit { bid: s.bid
                                   , bresp: s.bresp
                                   , buser: s.buser });
      s.bready (rdy);
    endaction;
  endinterface;

// augment master / slave Sig
////////////////////////////////////////////////////////////////////////////////

module augmentAXI4_B_Master_Sig #(
    function module #(Empty) f (Bool bvalid, Bool bready, flit_t bflit)
  , b_master_sig m) (b_master_sig)
  provisos ( Alias #(b_master_sig, AXI4_B_Master_Sig #(id_, user_))
           , Alias #(flit_t, AXI4_BFlit #(id_, user_)) );
  let bvalidWire <- mkPulseWire;
  let bflitWire <- mkDWire (?);
  f (bvalidWire, m.bready, bflitWire);
  function g (bvalid, _bready, bflit) = action
    if (bvalid) bvalidWire.send;
    bflitWire <= bflit;
  endaction;
  return on_bready (g, m);
endmodule

module augmentAXI4_B_Slave_Sig #(
    function module #(Empty) f (Bool bvalid, Bool bready, flit_t bflit)
  , b_slave_sig s) (b_slave_sig)
  provisos ( Alias #(b_slave_sig, AXI4_B_Slave_Sig #(id_, user_))
           , Alias #(flit_t, AXI4_BFlit #(id_, user_)) );
  let breadyWire <- mkPulseWire;
  f (s.bvalid, breadyWire, AXI4_BFlit { bid: s.bid
                                      , bresp: s.bresp
                                      , buser: s.buser });
  function g (_bvalid , bready , _flit) = action
    if (bready) breadyWire.send;
  endaction;
  return on_bflit (g, s);
endmodule

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

// probe B flit
////////////////////////////////////////////////////////////////////////////////

module probeAXI4_BFlit #( Bool bvalid
                        , Bool bready
                        , AXI4_BFlit #(id_, user_) bflit) (Empty);
  let bid_prb <- mkProbe;
  let bresp_prb <- mkProbe;
  let buser_prb <- mkProbe;
  let bvalid_prb <- mkProbe;
  let bready_prb <- mkProbe;
  (* fire_when_enabled, no_implicit_conditions *)
  rule probe_signals;
    bid_prb <= bflit.bid;
    bresp_prb <= bflit.bresp;
    buser_prb <= bflit.buser;
    bvalid_prb <= bvalid;
    bready_prb <= bready;
  endrule
endmodule

// probe Master interface
////////////////////////////////////////////////////////////////////////////////

module probeAXI4_B_Master_Sig #(AXI4_B_Master_Sig #(id_, user_) m)
                               (AXI4_B_Master_Sig #(id_, user_));
  augmentAXI4_B_Master_Sig (probeAXI4_BFlit, m);
  return m;
endmodule

module probeAXI4_BFlit_Source #(src_t src) (Source #(flit_t))
  provisos ( Alias #(flit_t, AXI4_BFlit #(id_, user_))
           , ToSource #(src_t, flit_t) );
  let probed <- augmentSourceWith (probeAXI4_BFlit, src);
  return probed;
endmodule

// probe Slave interface
////////////////////////////////////////////////////////////////////////////////

module probeAXI4_B_Slave_Sig #(AXI4_B_Slave_Sig #(id_, user_) s)
                              (AXI4_B_Slave_Sig #(id_, user_));
  augmentAXI4_B_Slave_Sig (probeAXI4_BFlit, s);
  return s;
endmodule

module probeAXI4_BFlit_Sink #(snk_t snk) (Sink #(flit_t))
  provisos ( Alias #(flit_t, AXI4_BFlit #(id_, user_))
           , ToSink #(snk_t, flit_t) );
  module f #(Bool canPut, Maybe #(flit_t) mData) (Empty);
    probeAXI4_BFlit (isValid (mData), canPut, fromMaybe (?, mData));
  endmodule
  let probed <- augmentSinkWith (f, snk);
  return probed;
endmodule
