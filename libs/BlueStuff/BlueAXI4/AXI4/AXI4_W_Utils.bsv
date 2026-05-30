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

////////////////////////////
// AXI Write Data Channel //
////////////////////////////////////////////////////////////////////////////////

// map over flit type
////////////////////////////////////////////////////////////////////////////////

function AXI4_WFlit #(data_out, user)
  mapAXI4_WFlit_wdata (
    function Bit #(data_out) f (Bit #(data_in) a)
  , function Bit #(TDiv #(data_out, 8)) g (Bit #(TDiv #(data_in, 8)) a)
  , AXI4_WFlit #(data_in, user) x ) =
  AXI4_WFlit { wdata: f (x.wdata)
             , wstrb: g (x.wstrb)
             , wlast: x.wlast
             , wuser: x.wuser };

function AXI4_WFlit #(data, user_out)
  mapAXI4_WFlit_wuser (
    function Bit #(user_out) f (Bit #(user_in) a)
  , AXI4_WFlit #(data, user_in) x ) =
  AXI4_WFlit { wdata: x.wdata
             , wstrb: x.wstrb
             , wlast: x.wlast
             , wuser: f (x.wuser) };

// typeclasses to convert to/from the flit type
////////////////////////////////////////////////////////////////////////////////

typeclass ToAXI4_WFlit#(type t, numeric type data_, numeric type user_)
  dependencies ( t determines (data_, user_)
               , (data_, user_) determines t );
  function AXI4_WFlit#(data_, user_) toAXI4_WFlit (t x);
endtypeclass

instance ToAXI4_WFlit#(AXI4_WFlit#(a, b), a, b);
  function toAXI4_WFlit = id;
endinstance

typeclass FromAXI4_WFlit#(type t, numeric type data_, numeric type user_)
  dependencies ( t determines (data_, user_)
               , (data_, user_) determines t );
  function t fromAXI4_WFlit (AXI4_WFlit#(data_, user_) x);
endtypeclass

instance FromAXI4_WFlit#(AXI4_WFlit#(a, b), a, b);
  function fromAXI4_WFlit = id;
endinstance

// augment master / slave Sig "on action" function
////////////////////////////////////////////////////////////////////////////////

function AXI4_W_Master_Sig #(data_, user_)
  on_wready ( function Action f ( Bool _valid
                                , Bool _ready
                                , AXI4_WFlit #(data_, user_) _flit )
            , AXI4_W_Master_Sig #(data_, user_) m) =
  interface AXI4_W_Master_Sig;
    method wdata = m.wdata;
    method wstrb = m.wstrb;
    method wlast = m.wlast;
    method wuser = m.wuser;
    method wvalid  = m.wvalid;
    method wready (rdy) = action
      f (m.wvalid, rdy, AXI4_WFlit { wdata: m.wdata
                                   , wstrb: m.wstrb
                                   , wlast: m.wlast
                                   , wuser: m.wuser });
      m.wready (rdy);
    endaction;
  endinterface;

function AXI4_W_Slave_Sig #(data_, user_)
  on_wflit ( function Action f ( Bool _valid
                               , Bool _ready
                               , AXI4_WFlit #(data_, user_) _flit )
           , AXI4_W_Slave_Sig #(data_, user_) s ) =
  interface AXI4_W_Slave_Sig;
    method wflit (wvalid, wdata, wstrb, wlast, wuser) = action
      f (wvalid, s.wready, AXI4_WFlit { wdata: wdata
                                      , wstrb: wstrb
                                      , wlast: wlast
                                      , wuser: wuser });
      s.wflit (wvalid, wdata, wstrb, wlast, wuser);
    endaction;
    method wready = s.wready;
  endinterface;

// augment master / slave Sig
////////////////////////////////////////////////////////////////////////////////

module augmentAXI4_W_Master_Sig #(
    function module #(Empty) f (Bool wvalid, Bool wready, flit_t wflit)
  , w_master_sig m) (w_master_sig)
  provisos ( Alias #(w_master_sig, AXI4_W_Master_Sig #(data_, user_))
           , Alias #(flit_t, AXI4_WFlit #(data_, user_)) );
  let wreadyWire <- mkPulseWire;
  f (m.wvalid, wreadyWire, AXI4_WFlit { wdata: m.wdata
                                      , wstrb: m.wstrb
                                      , wlast: m.wlast
                                      , wuser: m.wuser });
  function g (_wvalid , wready , _flit) = action
    if (wready) wreadyWire.send;
  endaction;
  return on_wready (g, m);
endmodule

module augmentAXI4_W_Slave_Sig #(
    function module #(Empty) f (Bool wvalid, Bool wready, flit_t wflit)
  , w_slave_sig s) (w_slave_sig)
  provisos ( Alias #(w_slave_sig, AXI4_W_Slave_Sig #(data_, user_))
           , Alias #(flit_t, AXI4_WFlit #(data_, user_)) );
  let wvalidWire <- mkPulseWire;
  let wflitWire <- mkDWire (?);
  f (wvalidWire, s.wready, wflitWire);
  function g (wvalid, _wready, wflit) = action
    if (wvalid) wvalidWire.send;
    wflitWire <= wflit;
  endaction;
  return on_wflit (g, s);
endmodule

// convert to/from Sig Master interface
////////////////////////////////////////////////////////////////////////////////

module toAXI4_W_Master_Sig #(src_t#(t) s) (AXI4_W_Master_Sig#(data_, user_))
  provisos ( ToSource#(src_t#(t), t)
           , ToAXI4_WFlit#(t, data_, user_)
           , Bits#(t, t_sz));
  let src <- toUnguardedSource(s, ?);
  AXI4_WFlit#(data_, user_) flit = toAXI4_WFlit(src.peek);
  method wdata  = flit.wdata;
  method wstrb  = flit.wstrb;
  method wlast  = flit.wlast;
  method wuser  = flit.wuser;
  method wvalid = src.canPeek;
  method wready(rdy) = action if (src.canPeek && rdy) src.drop; endaction;
endmodule

module fromAXI4_W_Master_Sig #(AXI4_W_Master_Sig#(data_, user_) m)
                              (Source#(AXI4_WFlit#(data_, user_)));
  FIFOF#(AXI4_WFlit#(data_, user_)) buffer <- mkSizedBypassFIFOF(1);
  let snk <- toUnguardedSink(buffer);
  (* fire_when_enabled, no_implicit_conditions *)
  rule forwardFlit (m.wvalid && snk.canPut);
    snk.put (AXI4_WFlit {
      wdata: m.wdata, wstrb: m.wstrb, wlast: m.wlast, wuser: m.wuser
    });
  endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule forwardReady; m.wready(snk.canPut); endrule
  return toSource(buffer);
endmodule

// convert to/from Sig Slave interface
////////////////////////////////////////////////////////////////////////////////

module toAXI4_W_Slave_Sig #(snk_t s)
                           (AXI4_W_Slave_Sig#(data_, user_))
  provisos ( ToSink#(snk_t, t)
           , FromAXI4_WFlit#(t, data_, user_)
           , Bits#(t, t_sz));
  let snk <- toUnguardedSink(s);
  method wflit(wvalid, wdata, wstrb, wlast, wuser) = action
    if (wvalid && snk.canPut) snk.put(fromAXI4_WFlit(AXI4_WFlit{
      wdata: wdata, wstrb: wstrb, wlast: wlast, wuser: wuser
    }));
  endaction;
  method wready = snk.canPut;
endmodule

module fromAXI4_W_Slave_Sig #(AXI4_W_Slave_Sig#(data_, user_) s)
                             (Sink#(AXI4_WFlit#(data_, user_)));
  // We use a guarded buffer to export as a guarded sink, and use an unguarded
  // source as an internal interface to it for connection to the Sig interface
  FIFOF#(AXI4_WFlit#(data_, user_)) buffer <- mkSizedBypassFIFOF(1);
  let src <- toUnguardedSource(buffer, ?);
  (* fire_when_enabled, no_implicit_conditions *)
  rule forwardFlit;
    s.wflit( src.canPeek
           , src.peek.wdata
           , src.peek.wstrb
           , src.peek.wlast
           , src.peek.wuser);
  endrule
  (* fire_when_enabled, no_implicit_conditions *)
  rule dropFlit (src.canPeek && s.wready); src.drop; endrule
  return toSink(buffer);
endmodule

// probe W flit
////////////////////////////////////////////////////////////////////////////////

module probeAXI4_WFlit #( Bool w_valid
                        , Bool w_ready
                        , AXI4_WFlit #(data_, user_) w_flit) (Empty);
  let wdata <- mkSignalProbe (w_flit.wdata);
  let wstrb <- mkSignalProbe (w_flit.wstrb);
  let wlast <- mkSignalProbe (w_flit.wlast);
  let wuser <- mkSignalProbe (w_flit.wuser);
  let wvalid <- mkSignalProbe (w_valid);
  let wready <- mkSignalProbe (w_ready);
endmodule

// probe Master interface
////////////////////////////////////////////////////////////////////////////////

module probeAXI4_W_Master_Sig #(AXI4_W_Master_Sig #(data_, user_) m)
                               (AXI4_W_Master_Sig #(data_, user_));
  augmentAXI4_W_Master_Sig (probeAXI4_WFlit, m);
  return m;
endmodule

module probeAXI4_WFlit_Source #(src_t src) (Source #(flit_t))
  provisos ( Alias #(flit_t, AXI4_WFlit #(data_, user_))
           , ToSource #(src_t, flit_t) );
  let probed <- augmentSourceWith (probeAXI4_WFlit, src);
  return probed;
endmodule

// probe Slave interface
////////////////////////////////////////////////////////////////////////////////

module probeAXI4_W_Slave_Sig #(AXI4_W_Slave_Sig #(data_, user_) s)
                              (AXI4_W_Slave_Sig #(data_, user_));
  augmentAXI4_W_Slave_Sig (probeAXI4_WFlit, s);
  return s;
endmodule

module probeAXI4_WFlit_Sink #(snk_t snk) (Sink #(flit_t))
  provisos ( Alias #(flit_t, AXI4_WFlit #(data_, user_))
           , ToSink #(snk_t, flit_t) );
  module f #(Bool canPut, Maybe #(flit_t) mData) (Empty);
    probeAXI4_WFlit (isValid (mData), canPut, fromMaybe (?, mData));
  endmodule
  let probed <- augmentSinkWith (f, snk);
  return probed;
endmodule
