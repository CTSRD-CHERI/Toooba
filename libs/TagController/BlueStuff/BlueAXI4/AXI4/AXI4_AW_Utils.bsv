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

///////////////////////////////
// AXI Address Write Channel //
////////////////////////////////////////////////////////////////////////////////

// map over flit type
////////////////////////////////////////////////////////////////////////////////

function AXI4_AWFlit #(id_out, addr, user)
  mapAXI4_AWFlit_awid (
    function Bit #(id_out) f (Bit #(id_in) a)
  , AXI4_AWFlit #(id_in, addr, user) x ) =
  AXI4_AWFlit { awid: f (x.awid)
              , awaddr: x.awaddr
              , awlen: x.awlen
              , awsize: x.awsize
              , awburst: x.awburst
              , awlock: x.awlock
              , awcache: x.awcache
              , awprot: x.awprot
              , awqos: x.awqos
              , awregion: x.awregion
              , awuser: x.awuser };

function AXI4_AWFlit #(id, addr_out, user)
  mapAXI4_AWFlit_awaddr (
    function Bit #(addr_out) f (Bit #(addr_in) a)
  , AXI4_AWFlit #(id, addr_in, user) x ) =
  AXI4_AWFlit { awid: x.awid
              , awaddr: f (x.awaddr)
              , awlen: x.awlen
              , awsize: x.awsize
              , awburst: x.awburst
              , awlock: x.awlock
              , awcache: x.awcache
              , awprot: x.awprot
              , awqos: x.awqos
              , awregion: x.awregion
              , awuser: x.awuser };

function AXI4_AWFlit #(id, addr, user_out)
  mapAXI4_AWFlit_awuser (
    function Bit #(user_out) f (Bit #(user_in) a)
  , AXI4_AWFlit #(id, addr, user_in) x ) =
  AXI4_AWFlit { awid: x.awid
              , awaddr: x.awaddr
              , awlen: x.awlen
              , awsize: x.awsize
              , awburst: x.awburst
              , awlock: x.awlock
              , awcache: x.awcache
              , awprot: x.awprot
              , awqos: x.awqos
              , awregion: x.awregion
              , awuser: f (x.awuser) };

// to convert to/from the flit type
////////////////////////////////////////////////////////////////////////////////

typeclass ToAXI4_AWFlit#( type t
                        , numeric type id_
                        , numeric type addr_
                        , numeric type user_)
  dependencies ( t determines (id_, addr_, user_)
               , (id_, addr_, user_) determines t );
  function AXI4_AWFlit#(id_, addr_, user_) toAXI4_AWFlit (t x);
endtypeclass

instance ToAXI4_AWFlit#(AXI4_AWFlit#(a, b, c), a, b, c);
  function toAXI4_AWFlit = id;
endinstance

typeclass FromAXI4_AWFlit#( type t
                          , numeric type id_
                          , numeric type addr_
                          , numeric type user_)
  dependencies ( t determines (id_, addr_, user_)
               , (id_, addr_, user_) determines t );
  function t fromAXI4_AWFlit (AXI4_AWFlit#(id_, addr_, user_) x);
endtypeclass

instance FromAXI4_AWFlit#(AXI4_AWFlit#(a, b, c), a, b, c);
  function fromAXI4_AWFlit = id;
endinstance

// augment master / slave Sig "on action" function
////////////////////////////////////////////////////////////////////////////////

function AXI4_AW_Master_Sig #(id_, addr_, user_)
  on_awready ( function Action f ( Bool _valid
                                 , Bool _ready
                                 , AXI4_AWFlit #(id_, addr_, user_) _flit )
             , AXI4_AW_Master_Sig #(id_, addr_, user_) m) =
  interface AXI4_AW_Master_Sig;
    method awid     = m.awid;
    method awaddr   = m.awaddr;
    method awlen    = m.awlen;
    method awsize   = m.awsize;
    method awburst  = m.awburst;
    method awlock   = m.awlock;
    method awcache  = m.awcache;
    method awprot   = m.awprot;
    method awqos    = m.awqos;
    method awregion = m.awregion;
    method awuser   = m.awuser;
    method awvalid  = m.awvalid;
    method awready (rdy) = action
      f (m.awvalid, rdy, AXI4_AWFlit { awid:     m.awid
                                     , awaddr:   m.awaddr
                                     , awlen:    m.awlen
                                     , awsize:   m.awsize
                                     , awburst:  m.awburst
                                     , awlock:   m.awlock
                                     , awcache:  m.awcache
                                     , awprot:   m.awprot
                                     , awqos:    m.awqos
                                     , awregion: m.awregion
                                     , awuser:   m.awuser });
      m.awready (rdy);
    endaction;
  endinterface;

function AXI4_AW_Slave_Sig #(id_, addr_, user_)
  on_awflit ( function Action f ( Bool _valid
                                , Bool _ready
                                , AXI4_AWFlit #(id_, addr_, user_) _flit )
            , AXI4_AW_Slave_Sig #(id_, addr_, user_) s ) =
  interface AXI4_AW_Slave_Sig;
    method awflit ( awvalid
                  , awid
                  , awaddr
                  , awlen
                  , awsize
                  , awburst
                  , awlock
                  , awcache
                  , awprot
                  , awqos
                  , awregion
                  , awuser ) = action
      f ( awvalid, s.awready, AXI4_AWFlit { awid:     awid
                                          , awaddr:   awaddr
                                          , awlen:    awlen
                                          , awsize:   awsize
                                          , awburst:  awburst
                                          , awlock:   awlock
                                          , awcache:  awcache
                                          , awprot:   awprot
                                          , awqos:    awqos
                                          , awregion: awregion
                                          , awuser:   awuser } );
      s.awflit ( awvalid
               , awid
               , awaddr
               , awlen
               , awsize
               , awburst
               , awlock
               , awcache
               , awprot
               , awqos
               , awregion
               , awuser );
    endaction;
    method awready = s.awready;
  endinterface;

// augment master / slave Sig
////////////////////////////////////////////////////////////////////////////////

module augmentAXI4_AW_Master_Sig #(
    function module #(Empty) f (Bool awvalid, Bool awready, flit_t awflit)
  , aw_master_sig m) (aw_master_sig)
  provisos ( Alias #(aw_master_sig, AXI4_AW_Master_Sig #(id_, addr_, user_))
           , Alias #(flit_t, AXI4_AWFlit #(id_, addr_, user_)) );
  let awreadyWire <- mkPulseWire;
  f (m.awvalid, awreadyWire, AXI4_AWFlit { awid:     m.awid
                                         , awaddr:   m.awaddr
                                         , awlen:    m.awlen
                                         , awsize:   m.awsize
                                         , awburst:  m.awburst
                                         , awlock:   m.awlock
                                         , awcache:  m.awcache
                                         , awprot:   m.awprot
                                         , awqos:    m.awqos
                                         , awregion: m.awregion
                                         , awuser:   m.awuser });
  function g (_awvalid , awready , _flit) = action
    if (awready) awreadyWire.send;
  endaction;
  return on_awready (g, m);
endmodule

module augmentAXI4_AW_Slave_Sig #(
    function module #(Empty) f (Bool awvalid, Bool awready, flit_t awflit)
  , aw_slave_sig s) (aw_slave_sig)
  provisos ( Alias #(aw_slave_sig, AXI4_AW_Slave_Sig #(id_, addr_, user_))
           , Alias #(flit_t, AXI4_AWFlit #(id_, addr_, user_)) );
  let awvalidWire <- mkPulseWire;
  let awflitWire <- mkDWire (?);
  f (awvalidWire, s.awready, awflitWire);
  function g (awvalid, _awready, awflit) = action
    if (awvalid) awvalidWire.send;
    awflitWire <= awflit;
  endaction;
  return on_awflit (g, s);
endmodule

// convert to/from Sig Master interface
////////////////////////////////////////////////////////////////////////////////

module toAXI4_AW_Master_Sig #(src_t#(t) s)
                             (AXI4_AW_Master_Sig#(id_, addr_, user_))
  provisos ( ToSource#( src_t#(t), t)
           , ToAXI4_AWFlit#(t, id_, addr_, user_)
           , Bits#(t, t_sz));
  let src <- toUnguardedSource(s, ?);
  AXI4_AWFlit#(id_, addr_, user_) flit = toAXI4_AWFlit(src.peek);
  method awid     = flit.awid;
  method awaddr   = flit.awaddr;
  method awlen    = flit.awlen;
  method awsize   = flit.awsize;
  method awburst  = flit.awburst;
  method awlock   = flit.awlock;
  method awcache  = flit.awcache;
  method awprot   = flit.awprot;
  method awqos    = flit.awqos;
  method awregion = flit.awregion;
  method awuser   = flit.awuser;
  method awvalid  = src.canPeek;
  method awready(rdy) = action if (src.canPeek && rdy) src.drop; endaction;
endmodule

module fromAXI4_AW_Master_Sig #(AXI4_AW_Master_Sig#(id_, addr_, user_) m)
                               (Source#(AXI4_AWFlit#(id_, addr_, user_)));
  FIFOF#(AXI4_AWFlit#(id_, addr_, user_)) buffer <- mkSizedBypassFIFOF(1);
  let snk <- toUnguardedSink(buffer);
  (* fire_when_enabled, no_implicit_conditions *)
  rule forwardFlit (m.awvalid && snk.canPut);
    snk.put (AXI4_AWFlit { awid:     m.awid
                         , awaddr:   m.awaddr
                         , awlen:    m.awlen
                         , awsize:   m.awsize
                         , awburst:  m.awburst
                         , awlock:   m.awlock
                         , awcache:  m.awcache
                         , awprot:   m.awprot
                         , awqos:    m.awqos
                         , awregion: m.awregion
                         , awuser:   m.awuser });
  endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule forwardReady; m.awready(snk.canPut); endrule
  return toSource(buffer);
endmodule

// convert to/from Sig Slave interface
////////////////////////////////////////////////////////////////////////////////

module toAXI4_AW_Slave_Sig #(snk_t s)
                            (AXI4_AW_Slave_Sig#(id_, addr_, user_))
  provisos ( ToSink#(snk_t, t)
           , FromAXI4_AWFlit#(t, id_, addr_, user_)
           , Bits#(t, t_sz));
  let snk <- toUnguardedSink(s);
  method awflit( awvalid
               , awid
               , awaddr
               , awlen
               , awsize
               , awburst
               , awlock
               , awcache
               , awprot
               , awqos
               , awregion
               , awuser) = action if (awvalid && snk.canPut)
    snk.put(fromAXI4_AWFlit(AXI4_AWFlit{ awid:     awid
                                       , awaddr:   awaddr
                                       , awlen:    awlen
                                       , awsize:   awsize
                                       , awburst:  awburst
                                       , awlock:   awlock
                                       , awcache:  awcache
                                       , awprot:   awprot
                                       , awqos:    awqos
                                       , awregion: awregion
                                       , awuser:   awuser }));
  endaction;
  method awready = snk.canPut;
endmodule

module fromAXI4_AW_Slave_Sig #(AXI4_AW_Slave_Sig#(id_, addr_, user_) s)
                              (Sink#(AXI4_AWFlit#(id_, addr_, user_)));
  // We use a guarded buffer to export as a guarded sink, and use an unguarded
  // source as an internal interface to it for connection to the Sig interface
  FIFOF#(AXI4_AWFlit#(id_, addr_, user_)) buffer <- mkSizedBypassFIFOF(1);
  let src <- toUnguardedSource(buffer, ?);
  (* fire_when_enabled, no_implicit_conditions *)
  rule forwardFlit;
    s.awflit( src.canPeek
            , src.peek.awid
            , src.peek.awaddr
            , src.peek.awlen
            , src.peek.awsize
            , src.peek.awburst
            , src.peek.awlock
            , src.peek.awcache
            , src.peek.awprot
            , src.peek.awqos
            , src.peek.awregion
            , src.peek.awuser);
  endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule dropFlit (src.canPeek && s.awready); src.drop; endrule
  return toSink(buffer);
endmodule

// probe AW flit
////////////////////////////////////////////////////////////////////////////////

module probeAXI4_AWFlit #( Bool awvalid
                         , Bool awready
                         , AXI4_AWFlit #(id_, addr_, user_) awflit) (Empty);
  let awid_prb <- mkProbe;
  let awaddr_prb <- mkProbe;
  let awlen_prb <- mkProbe;
  let awsize_prb <- mkProbe;
  let awburst_prb <- mkProbe;
  let awlock_prb <- mkProbe;
  let awcache_prb <- mkProbe;
  let awprot_prb <- mkProbe;
  let awqos_prb <- mkProbe;
  let awregion_prb <- mkProbe;
  let awuser_prb <- mkProbe;
  let awvalid_prb <- mkProbe;
  let awready_prb <- mkProbe;
  (* fire_when_enabled, no_implicit_conditions *)
  rule probe_signals;
    awid_prb <= awflit.awid;
    awaddr_prb <= awflit.awaddr;
    awlen_prb <= awflit.awlen;
    awsize_prb <= awflit.awsize;
    awburst_prb <= awflit.awburst;
    awlock_prb <= awflit.awlock;
    awcache_prb <= awflit.awcache;
    awprot_prb <= awflit.awprot;
    awqos_prb <= awflit.awqos;
    awregion_prb <= awflit.awregion;
    awuser_prb <= awflit.awuser;
    awvalid_prb <= awvalid;
    awready_prb <= awready;
  endrule
endmodule

// probe Master interface
////////////////////////////////////////////////////////////////////////////////

module probeAXI4_AW_Master_Sig #(AXI4_AW_Master_Sig #(id_, addr_, user_) m)
                                (AXI4_AW_Master_Sig #(id_, addr_, user_));
  augmentAXI4_AW_Master_Sig (probeAXI4_AWFlit, m);
  return m;
endmodule

module probeAXI4_AWFlit_Source #(src_t src) (Source #(flit_t))
  provisos ( Alias #(flit_t, AXI4_AWFlit #(id_, addr_, user_))
           , ToSource #(src_t, flit_t) );
  let probed <- augmentSourceWith (probeAXI4_AWFlit, src);
  return probed;
endmodule

// probe Slave interface
////////////////////////////////////////////////////////////////////////////////

module probeAXI4_AW_Slave_Sig #(AXI4_AW_Slave_Sig #(id_, addr_, user_) s)
                               (AXI4_AW_Slave_Sig #(id_, addr_, user_));
  augmentAXI4_AW_Slave_Sig (probeAXI4_AWFlit, s);
  return s;
endmodule

module probeAXI4_AWFlit_Sink #(snk_t snk) (Sink #(flit_t))
  provisos ( Alias #(flit_t, AXI4_AWFlit #(id_, addr_, user_))
           , ToSink #(snk_t, flit_t) );
  module f #(Bool canPut, Maybe #(flit_t) mData) (Empty);
    probeAXI4_AWFlit (isValid (mData), canPut, fromMaybe (?, mData));
  endmodule
  let probed <- augmentSinkWith (f, snk);
  return probed;
endmodule
