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

import BlueBasics :: *;

import AXI4_Types :: *;

import Probe :: *;
import FIFOF :: *;
import SpecialFIFOs :: *;

///////////////////////////
// AXI Read Data Channel //
////////////////////////////////////////////////////////////////////////////////

// map over flit type
////////////////////////////////////////////////////////////////////////////////

function AXI4_RFlit #(id_out, data, user)
  mapAXI4_RFlit_rid (
    function Bit #(id_out) f (Bit #(id_in) a)
  , AXI4_RFlit #(id_in, data, user) x ) =
  AXI4_RFlit { rid:   f (x.rid)
             , rdata: x.rdata
             , rresp: x.rresp
             , rlast: x.rlast
             , ruser: x.ruser };

function AXI4_RFlit #(id, data_out, user)
  mapAXI4_RFlit_rdata (
    function Bit #(data_out) f (Bit #(data_in) a)
  , AXI4_RFlit #(id, data_in, user) x ) =
  AXI4_RFlit { rid:   x.rid
             , rdata: f (x.rdata)
             , rresp: x.rresp
             , rlast: x.rlast
             , ruser: x.ruser };

function AXI4_RFlit #(id, data, user_out)
  mapAXI4_RFlit_ruser (
    function Bit #(user_out) f (Bit #(user_in) a)
  , AXI4_RFlit #(id, data, user_in) x ) =
  AXI4_RFlit { rid:   x.rid
             , rdata: x.rdata
             , rresp: x.rresp
             , rlast: x.rlast
             , ruser: f (x.ruser) };

// typeclasses to convert to/from the flit type
////////////////////////////////////////////////////////////////////////////////

typeclass ToAXI4_RFlit#( type t
                       , numeric type id_
                       , numeric type data_
                       , numeric type user_)
  dependencies ( t determines (id_, data_, user_)
               , (id_, data_, user_) determines t );
  function AXI4_RFlit#(id_, data_, user_) toAXI4_RFlit (t x);
endtypeclass

instance ToAXI4_RFlit#(AXI4_RFlit#(a, b, c), a, b, c);
  function toAXI4_RFlit = id;
endinstance

typeclass FromAXI4_RFlit#( type t
                         , numeric type id_
                         , numeric type data_
                         , numeric type user_)
  dependencies ( t determines (id_, data_, user_)
               , (id_, data_, user_) determines t );
  function t fromAXI4_RFlit (AXI4_RFlit#(id_, data_, user_) x);
endtypeclass

instance FromAXI4_RFlit#(AXI4_RFlit#(a, b, c), a, b, c);
  function fromAXI4_RFlit = id;
endinstance

// augment master / slave Sig "on action" function
////////////////////////////////////////////////////////////////////////////////

function AXI4_R_Master_Sig #(id_, data_, user_)
  on_rready ( function Action f ( Bool _valid
                                , Bool _ready
                                , AXI4_RFlit #(id_, data_, user_) _flit )
           , AXI4_R_Master_Sig #(id_, data_, user_) m ) =
  interface AXI4_R_Master_Sig;
    method rflit (rvalid, rid, rdata, rresp, rlast, ruser) = action
      f (rvalid, m.rready, AXI4_RFlit { rid: rid
                                      , rdata: rdata
                                      , rresp: rresp
                                      , rlast: rlast
                                      , ruser: ruser });
      m.rflit (rvalid, rid, rdata, rresp, rlast, ruser);
    endaction;
    method rready = m.rready;
  endinterface;

function AXI4_R_Slave_Sig #(id_, data_, user_)
  on_rflit ( function Action f ( Bool _valid
                               , Bool _ready
                               , AXI4_RFlit #(id_, data_, user_) _flit )
            , AXI4_R_Slave_Sig #(id_, data_, user_) s) =
  interface AXI4_R_Slave_Sig;
    method rid = s.rid;
    method rdata = s.rdata;
    method rresp = s.rresp;
    method rlast = s.rlast;
    method ruser = s.ruser;
    method rvalid  = s.rvalid;
    method rready (rdy) = action
      f (s.rvalid, rdy, AXI4_RFlit { rid: s.rid
                                   , rdata: s.rdata
                                   , rresp: s.rresp
                                   , rlast: s.rlast
                                   , ruser: s.ruser });
      s.rready (rdy);
    endaction;
  endinterface;

// augment master / slave Sig
////////////////////////////////////////////////////////////////////////////////

module augmentAXI4_R_Master_Sig #(
    function module #(Empty) f (Bool rvalid, Bool rready, flit_t rflit)
  , r_master_sig m) (r_master_sig)
  provisos ( Alias #(r_master_sig, AXI4_R_Master_Sig #(id_, data_, user_))
           , Alias #(flit_t, AXI4_RFlit #(id_, data_, user_)) );
  let rvalidWire <- mkPulseWire;
  let rflitWire <- mkDWire (?);
  f (rvalidWire, m.rready, rflitWire);
  function g (rvalid, _rready, rflit) = action
    if (rvalid) rvalidWire.send;
    rflitWire <= rflit;
  endaction;
  return on_rready (g, m);
endmodule

module augmentAXI4_R_Slave_Sig #(
    function module #(Empty) f (Bool rvalid, Bool rready, flit_t rflit)
  , r_slave_sig s) (r_slave_sig)
  provisos ( Alias #(r_slave_sig, AXI4_R_Slave_Sig #(id_, data_, user_))
           , Alias #(flit_t, AXI4_RFlit #(id_, data_, user_)) );
  let rreadyWire <- mkPulseWire;
  f (s.rvalid, rreadyWire, AXI4_RFlit { rid: s.rid
                                      , rdata: s.rdata
                                      , rresp: s.rresp
                                      , rlast: s.rlast
                                      , ruser: s.ruser });
  function g (_rvalid , rready , _flit) = action
    if (rready) rreadyWire.send;
  endaction;
  return on_rflit (g, s);
endmodule

// convert to/from Sig Master interface
////////////////////////////////////////////////////////////////////////////////

module toAXI4_R_Master_Sig #(snk_t m)
                            (AXI4_R_Master_Sig#(id_, data_, user_))
  provisos ( ToSink#(snk_t, t)
           , FromAXI4_RFlit#(t, id_, data_, user_)
           , Bits#(t, t_sz));
  let snk <- toUnguardedSink(m);
  method rflit(rvalid, rid, rdata, rresp, rlast, ruser) = action
    if (rvalid && snk.canPut) snk.put(fromAXI4_RFlit(AXI4_RFlit{
      rid: rid, rdata: rdata, rresp: rresp, rlast: rlast, ruser: ruser
    }));
  endaction;
  method rready = snk.canPut;
endmodule

module fromAXI4_R_Master_Sig #(AXI4_R_Master_Sig#(id_, data_, user_) m)
                              (Sink#(AXI4_RFlit#(id_, data_, user_)));
  // We use a guarded buffer to export as a guarded sink, and use an unguarded
  // source as an internal interface to it for connection to the Sig interface
  FIFOF#(AXI4_RFlit#(id_, data_, user_)) buffer <- mkSizedBypassFIFOF(1);
  let src <- toUnguardedSource(buffer, ?);
  (* fire_when_enabled, no_implicit_conditions *)
  rule forwardFlit;
    m.rflit( src.canPeek
           , src.peek.rid
           , src.peek.rdata
           , src.peek.rresp
           , src.peek.rlast
           , src.peek.ruser);
  endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule dropFlit (src.canPeek && m.rready); src.drop; endrule
  return toSink(buffer);
endmodule

// convert to/from Sig Slave interface
////////////////////////////////////////////////////////////////////////////////

module toAXI4_R_Slave_Sig #(src_t#(t) s)
                           (AXI4_R_Slave_Sig#(id_, data_, user_))
  provisos ( ToSource#(src_t#(t), t)
           , ToAXI4_RFlit#(t, id_, data_, user_)
           , Bits#(t, t_sz));
  let src <- toUnguardedSource(s, ?);
  AXI4_RFlit#(id_, data_, user_) flit = toAXI4_RFlit(src.peek);
  method rid    = flit.rid;
  method rdata  = flit.rdata;
  method rresp  = flit.rresp;
  method rlast  = flit.rlast;
  method ruser  = flit.ruser;
  method rvalid = src.canPeek;
  method rready(rdy) = action if (src.canPeek && rdy) src.drop; endaction;
endmodule

module fromAXI4_R_Slave_Sig #(AXI4_R_Slave_Sig#(id_, data_, user_) s)
                             (Source#(AXI4_RFlit#(id_, data_, user_)));
  FIFOF#(AXI4_RFlit#(id_, data_, user_)) buffer <- mkSizedBypassFIFOF(1);
  let snk <- toUnguardedSink(buffer);
  (* fire_when_enabled, no_implicit_conditions *)
  rule forwardFlit (s.rvalid && snk.canPut);
    snk.put (AXI4_RFlit { rid:   s.rid
                        , rdata: s.rdata
                        , rresp: s.rresp
                        , rlast: s.rlast
                        , ruser: s.ruser });
  endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule forwardReady; s.rready(snk.canPut); endrule
  return toSource(buffer);
endmodule

// probe R flit
////////////////////////////////////////////////////////////////////////////////

module probeAXI4_RFlit #( Bool r_valid
                        , Bool r_ready
                        , AXI4_RFlit #(id_, data_, user_) r_flit) (Empty);
  let rid <- mkSignalProbe (r_flit.rid);
  let rdata <- mkSignalProbe (r_flit.rdata);
  let rresp <- mkSignalProbe (r_flit.rresp);
  let rlast <- mkSignalProbe (r_flit.rlast);
  let ruser <- mkSignalProbe (r_flit.ruser);
  let rvalid <- mkSignalProbe (r_valid);
  let rready <- mkSignalProbe (r_ready);
endmodule

// probe Master interface
////////////////////////////////////////////////////////////////////////////////

module probeAXI4_R_Master_Sig #(AXI4_R_Master_Sig #(id_, data_, user_) m)
                               (AXI4_R_Master_Sig #(id_, data_, user_));
  augmentAXI4_R_Master_Sig (probeAXI4_RFlit, m);
  return m;
endmodule

module probeAXI4_RFlit_Source #(src_t src) (Source #(flit_t))
  provisos ( Alias #(flit_t, AXI4_RFlit #(id_, data_, user_))
           , ToSource #(src_t, flit_t) );
  let probed <- augmentSourceWith (probeAXI4_RFlit, src);
  return probed;
endmodule

// probe Slave interface
////////////////////////////////////////////////////////////////////////////////

module probeAXI4_R_Slave_Sig #(AXI4_R_Slave_Sig #(id_, data_, user_) s)
                              (AXI4_R_Slave_Sig #(id_, data_, user_));
  augmentAXI4_R_Slave_Sig (probeAXI4_RFlit, s);
  return s;
endmodule

module probeAXI4_RFlit_Sink #(snk_t snk) (Sink #(flit_t))
  provisos ( Alias #(flit_t, AXI4_RFlit #(id_, data_, user_))
           , ToSink #(snk_t, flit_t) );
  module f #(Bool canPut, Maybe #(flit_t) mData) (Empty);
    probeAXI4_RFlit (isValid (mData), canPut, fromMaybe (?, mData));
  endmodule
  let probed <- augmentSinkWith (f, snk);
  return probed;
endmodule
