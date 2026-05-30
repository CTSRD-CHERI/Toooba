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
                        , numeric type user_);
  function AXI4_AWFlit#(id_, addr_, user_) toAXI4_AWFlit (t x);
endtypeclass

instance ToAXI4_AWFlit#(AXI4_AWFlit#(a, b, c), a, b, c);
  function toAXI4_AWFlit = id;
endinstance

typeclass FromAXI4_AWFlit#( type t
                          , numeric type id_
                          , numeric type addr_
                          , numeric type user_);
  function t fromAXI4_AWFlit (AXI4_AWFlit#(id_, addr_, user_) x);
endtypeclass

instance FromAXI4_AWFlit#(AXI4_AWFlit#(a, b, c), a, b, c);
  function fromAXI4_AWFlit = id;
endinstance

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
