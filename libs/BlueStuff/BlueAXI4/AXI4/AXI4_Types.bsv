/*-
 * Copyright (c) 2018-2022 Alexandre Joannou
 * Copyright (c) 2019 Peter Rugg
 * Copyright (c) 2020 Jonas Fiala
 * Copyright (c) 2021 Ivan Ribeiro
 * All rights reserved.
 *
 * This hardware design was developed by the University of Cambridge Computer
 * Laboratory (Department of Computer Science and Technology) under EPSRC award
 * EP/S030867/1 ("SIPP"); and by SRI International and the University of
 * Cambridge Computer Laboratory (Department of Computer Science and
 * Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
 * DARPA SSITH research programme.
 *
 * This material is based upon work supported by the DoD Information Analysis
 * Center Program Management Office (DoD IAC PMO), sponsored by the Defense
 * Technical Information Center (DTIC) under Contract No. FA807518D0004.  Any
 * opinions, findings and conclusions or recommendations expressed in this
 * material are those of the author(s) and do not necessarily reflect the views
 * of the Air Force Installation Contracting Agency (AFICA).
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

import FIFOF :: *;
import Connectable :: *;
import DefaultValue :: *;

// BlueStuff import
import Routable :: *;
// BlueBasics import
import SourceSink :: *;
import MasterSlave :: *;

import AXI4_Common_Types :: *;

////////////////////////////////
// AXI4 Address Write Channel //
////////////////////////////////////////////////////////////////////////////////

// Flit type
typedef struct {
  Bit#(id_)   awid;
  Bit#(addr_) awaddr;
  AXI4_Len    awlen;
  AXI4_Size   awsize;
  AXI4_Burst  awburst;
  AXI4_Lock   awlock;
  AXI4_Cache  awcache;
  AXI4_Prot   awprot;
  AXI4_QoS    awqos;
  AXI4_Region awregion;
  Bit#(user_) awuser;
} AXI4_AWFlit#(numeric type id_, numeric type addr_, numeric type user_)
deriving (Bits, FShow);
instance DefaultValue#(AXI4_AWFlit#(id_, addr_, user_));
  function defaultValue = AXI4_AWFlit {
    awid: 0, awaddr: ?, awlen: 0, awsize: 1,
    awburst: INCR, awlock: NORMAL, awcache: 0,
    awprot: 0, awqos: 0, awregion: 0, awuser: ?
  };
endinstance
instance Has_routingField #(AXI4_AWFlit #(id_, addr_, user_), Bit #(addr_));
  function routingField (x) = x.awaddr;
endinstance
instance Has_isLast #(AXI4_AWFlit #(id_, addr_, user_));
  function isLast = constFn (True);
endinstance

// Master interfaces
(* always_ready, always_enabled *)
interface AXI4_AW_Master_Sig #( numeric type id_
                              , numeric type addr_
                              , numeric type user_);
  method Bit#(id_)   awid;
  method Bit#(addr_) awaddr;
  method AXI4_Len    awlen;
  method AXI4_Size   awsize;
  method AXI4_Burst  awburst;
  method AXI4_Lock   awlock;
  method AXI4_Cache  awcache;
  method AXI4_Prot   awprot;
  method AXI4_QoS    awqos;
  method AXI4_Region awregion;
  method Bit#(user_) awuser;
  method Bool        awvalid;
  (* prefix="" *) method Action awready(Bool awready);
endinterface

instance CulDeSac#(AXI4_AW_Master_Sig #(id_, addr_, user_));
  function culDeSac = interface AXI4_AW_Master_Sig;
    method awid       = ?;
    method awaddr     = ?;
    method awlen      = ?;
    method awsize     = ?;
    method awburst    = ?;
    method awlock     = ?;
    method awcache    = ?;
    method awprot     = ?;
    method awqos      = ?;
    method awregion   = ?;
    method awuser     = ?;
    method awvalid    = False;
    method awready(_) = noAction;
  endinterface;
endinstance

// Slave interfaces
(* always_ready, always_enabled *)
interface AXI4_AW_Slave_Sig #( numeric type id_
                             , numeric type addr_
                             , numeric type user_);
  (* prefix="" *) method Action awflit ( Bool        awvalid
                                       , Bit#(id_)   awid
                                       , Bit#(addr_) awaddr
                                       , AXI4_Len    awlen
                                       , AXI4_Size   awsize
                                       , AXI4_Burst  awburst
                                       , AXI4_Lock   awlock
                                       , AXI4_Cache  awcache
                                       , AXI4_Prot   awprot
                                       , AXI4_QoS    awqos
                                       , AXI4_Region awregion
                                       , Bit#(user_) awuser);
  method Bool awready;
endinterface

instance CulDeSac#(AXI4_AW_Slave_Sig #(id_, addr_, user_));
  function culDeSac = interface AXI4_AW_Slave_Sig;
    method awflit (a,b,c,d,e,f,g,h,i,j,k,l) = noAction;
    method awready = True;
  endinterface;
endinstance

// connectable instances
instance Connectable#(AXI4_AW_Master_Sig#(a, b, c),
                      AXI4_AW_Slave_Sig#(a, b, c));
  module mkConnection#(AXI4_AW_Master_Sig#(a, b, c) m,
                       AXI4_AW_Slave_Sig#(a, b, c) s) (Empty);
    (* fire_when_enabled, no_implicit_conditions *)
    rule connect;
      s.awflit( m.awvalid
              , m.awid
              , m.awaddr
              , m.awlen
              , m.awsize
              , m.awburst
              , m.awlock
              , m.awcache
              , m.awprot
              , m.awqos
              , m.awregion
              , m.awuser);
      m.awready(s.awready);
    endrule
  endmodule
endinstance
instance Connectable#(AXI4_AW_Slave_Sig#(a, b, c),
                      AXI4_AW_Master_Sig#(a, b, c));
  module mkConnection#(AXI4_AW_Slave_Sig#(a, b, c) s,
                       AXI4_AW_Master_Sig#(a, b, c) m) (Empty);
    mkConnection(m, s);
  endmodule
endinstance

/////////////////////////////
// AXI4 Write Data Channel //
////////////////////////////////////////////////////////////////////////////////

// Flit type
typedef struct {
  Bit#(data_)           wdata;
  Bit#(TDiv#(data_, 8)) wstrb;
  Bool                  wlast;
  Bit#(user_)           wuser;
} AXI4_WFlit#(numeric type data_, numeric type user_) deriving (Bits, FShow);
instance DefaultValue#(AXI4_WFlit#(data_, user_));
  function defaultValue = AXI4_WFlit {
    wdata: ?, wstrb: ~0, wlast: True, wuser: ?
  };
endinstance
instance Has_isLast #(AXI4_WFlit #(data_, user_));
  function isLast (x) = x.wlast;
endinstance

// Master interfaces
(* always_ready, always_enabled *)
interface AXI4_W_Master_Sig #(numeric type data_, numeric type user_);
  method Bit#(data_)           wdata;
  method Bit#(TDiv#(data_, 8)) wstrb;
  method Bool                  wlast;
  method Bit#(user_)           wuser;
  method Bool                  wvalid;
  (* prefix="" *) method Action wready(Bool wready);
endinterface

instance CulDeSac#(AXI4_W_Master_Sig #(data_, user_));
  function culDeSac = interface AXI4_W_Master_Sig;
    method wdata     = ?;
    method wstrb     = ?;
    method wlast     = ?;
    method wuser     = ?;
    method wvalid    = False;
    method wready(_) = noAction;
  endinterface;
endinstance

// Slave interfaces
(* always_ready, always_enabled *)
interface AXI4_W_Slave_Sig #(numeric type data_, numeric type user_);
  (* prefix="" *) method Action wflit ( Bool                  wvalid
                                      , Bit#(data_)           wdata
                                      , Bit#(TDiv#(data_, 8)) wstrb
                                      , Bool                  wlast
                                      , Bit#(user_)           wuser);
  method Bool wready;
endinterface

instance CulDeSac#(AXI4_W_Slave_Sig #(data_, user_));
  function culDeSac = interface AXI4_W_Slave_Sig;
    method wflit (a,b,c,d,e) = noAction;
    method wready = False;
  endinterface;
endinstance

// connectable instances
instance Connectable#(AXI4_W_Master_Sig#(a, b), AXI4_W_Slave_Sig#(a, b));
  module mkConnection#(AXI4_W_Master_Sig#(a, b) m,
                       AXI4_W_Slave_Sig#(a, b) s)(Empty);
    (* fire_when_enabled, no_implicit_conditions *)
    rule connect;
      s.wflit(m.wvalid, m.wdata, m.wstrb, m.wlast, m.wuser);
      m.wready(s.wready);
    endrule
  endmodule
endinstance
instance Connectable#(AXI4_W_Slave_Sig#(a, b), AXI4_W_Master_Sig#(a, b));
  module mkConnection#(AXI4_W_Slave_Sig#(a, b) s,
                       AXI4_W_Master_Sig#(a, b) m)(Empty);
    mkConnection(m, s);
  endmodule
endinstance

/////////////////////////////////
// AXI4 Write Response Channel //
////////////////////////////////////////////////////////////////////////////////

// Flit type
typedef struct {
  Bit#(id_)   bid;
  AXI4_Resp   bresp;
  Bit#(user_) buser;
} AXI4_BFlit#(numeric type id_, numeric type user_) deriving (Bits, FShow);
instance DefaultValue#(AXI4_BFlit#(id_, user_));
  function defaultValue = AXI4_BFlit { bid: 0, bresp: OKAY, buser: ? };
endinstance
instance Has_routingField #(AXI4_BFlit #(id_, user_), Bit #(id_));
  function routingField (x) = x.bid;
endinstance
instance Has_isLast #(AXI4_BFlit #(id_, user_));
  function isLast = constFn (True);
endinstance

// Master interfaces
(* always_ready, always_enabled *)
interface AXI4_B_Master_Sig #(numeric type id_, numeric type user_);
  (* prefix="" *) method Action bflit ( Bool        bvalid
                                      , Bit#(id_)   bid
                                      , AXI4_Resp   bresp
                                      , Bit#(user_) buser);
  method Bool bready;
endinterface

instance CulDeSac#(AXI4_B_Master_Sig #(id_, user_));
  function culDeSac = interface AXI4_B_Master_Sig;
    method bflit (a,b,c,d) = noAction;
    method bready = False;
  endinterface;
endinstance

// Slave interfaces
(* always_ready, always_enabled *)
interface AXI4_B_Slave_Sig #(numeric type id_, numeric type user_);
  method Bit#(id_)   bid;
  method AXI4_Resp   bresp;
  method Bit#(user_) buser;
  method Bool        bvalid;
  (* prefix="" *) method Action bready(Bool bready);
endinterface

instance CulDeSac#(AXI4_B_Slave_Sig #(id_, user_));
  function culDeSac = interface AXI4_B_Slave_Sig;
    method bid       = ?;
    method bresp     = ?;
    method buser     = ?;
    method bvalid    = False;
    method bready(_) = noAction;
  endinterface;
endinstance

// connectable instances
instance Connectable#(AXI4_B_Master_Sig#(a, b), AXI4_B_Slave_Sig#(a, b));
  module mkConnection#(AXI4_B_Master_Sig#(a, b) m,
                       AXI4_B_Slave_Sig#(a, b) s)(Empty);
    (* fire_when_enabled, no_implicit_conditions *)
    rule connect;
      m.bflit(s.bvalid, s.bid, s.bresp, s.buser);
      s.bready(m.bready);
    endrule
  endmodule
endinstance
instance Connectable#(AXI4_B_Slave_Sig#(a, b), AXI4_B_Master_Sig#(a, b));
  module mkConnection#(AXI4_B_Slave_Sig#(a, b) s,
                       AXI4_B_Master_Sig#(a, b) m)(Empty);
    mkConnection(m, s);
  endmodule
endinstance

///////////////////////////////
// AXI4 Read Address Channel //
////////////////////////////////////////////////////////////////////////////////

// Flit type
typedef struct {
  Bit#(id_)   arid;
  Bit#(addr_) araddr;
  AXI4_Len    arlen;
  AXI4_Size   arsize;
  AXI4_Burst  arburst;
  AXI4_Lock   arlock;
  AXI4_Cache  arcache;
  AXI4_Prot   arprot;
  AXI4_QoS    arqos;
  AXI4_Region arregion;
  Bit#(user_) aruser;
} AXI4_ARFlit#(numeric type id_, numeric type addr_, numeric type user_)
deriving (Bits, FShow);
instance DefaultValue#(AXI4_ARFlit#(id_, addr_, user_));
  function defaultValue = AXI4_ARFlit {
    arid: 0, araddr: ?, arlen: 0, arsize: 1,
    arburst: INCR, arlock: NORMAL, arcache: 0,
    arprot: 0, arqos: 0, arregion: 0, aruser: ?
  };
endinstance
instance Has_routingField #(AXI4_ARFlit #(id_, addr_, user_), Bit #(addr_));
  function routingField (x) = x.araddr;
endinstance
instance Has_isLast #(AXI4_ARFlit #(id_, addr_, user_));
  function isLast = constFn (True);
endinstance

// Master interfaces
(* always_ready, always_enabled *)
interface AXI4_AR_Master_Sig #( numeric type id_
                              , numeric type addr_
                              , numeric type user_);
  method Bit#(id_)   arid;
  method Bit#(addr_) araddr;
  method AXI4_Len    arlen;
  method AXI4_Size   arsize;
  method AXI4_Burst  arburst;
  method AXI4_Lock   arlock;
  method AXI4_Cache  arcache;
  method AXI4_Prot   arprot;
  method AXI4_QoS    arqos;
  method AXI4_Region arregion;
  method Bit#(user_) aruser;
  method Bool        arvalid;
  (* prefix="" *) method Action arready(Bool arready);
endinterface

instance CulDeSac#(AXI4_AR_Master_Sig #(id_, addr_, user_));
  function culDeSac = interface AXI4_AR_Master_Sig;
    method arid       = ?;
    method araddr     = ?;
    method arlen      = ?;
    method arsize     = ?;
    method arburst    = ?;
    method arlock     = ?;
    method arcache    = ?;
    method arprot     = ?;
    method arqos      = ?;
    method arregion   = ?;
    method aruser     = ?;
    method arvalid    = False;
    method arready(_) = noAction;
  endinterface;
endinstance

// Slave interfaces
(* always_ready, always_enabled *)
interface AXI4_AR_Slave_Sig #( numeric type id_
                             , numeric type addr_
                             , numeric type user_);
  (* prefix="" *) method Action arflit ( Bool        arvalid
                                       , Bit#(id_)   arid
                                       , Bit#(addr_) araddr
                                       , AXI4_Len    arlen
                                       , AXI4_Size   arsize
                                       , AXI4_Burst  arburst
                                       , AXI4_Lock   arlock
                                       , AXI4_Cache  arcache
                                       , AXI4_Prot   arprot
                                       , AXI4_QoS    arqos
                                       , AXI4_Region arregion
                                       , Bit#(user_) aruser);
  method Bool arready;
endinterface

instance CulDeSac#(AXI4_AR_Slave_Sig #(id_, addr_, user_));
  function culDeSac = interface AXI4_AR_Slave_Sig;
    method arflit (a,b,c,d,e,f,g,h,i,j,k,l) = noAction;
    method arready = False;
  endinterface;
endinstance

// connectable instances
instance Connectable#(AXI4_AR_Master_Sig#(a, b, c),
                      AXI4_AR_Slave_Sig#(a, b, c));
  module mkConnection#(AXI4_AR_Master_Sig#(a, b, c) m,
                       AXI4_AR_Slave_Sig#(a, b, c) s)(Empty);
    (* fire_when_enabled, no_implicit_conditions *)
    rule connect;
      s.arflit( m.arvalid
              , m.arid
              , m.araddr
              , m.arlen
              , m.arsize
              , m.arburst
              , m.arlock
              , m.arcache
              , m.arprot
              , m.arqos
              , m.arregion
              , m.aruser);
      m.arready(s.arready);
    endrule
  endmodule
endinstance
instance Connectable#(AXI4_AR_Slave_Sig#(a, b, c),
                      AXI4_AR_Master_Sig#(a, b, c));
  module mkConnection#(AXI4_AR_Slave_Sig#(a, b, c) s,
                       AXI4_AR_Master_Sig#(a, b, c) m)(Empty);
    mkConnection(m, s);
  endmodule
endinstance

////////////////////////////
// AXI4 Read Data Channel //
////////////////////////////////////////////////////////////////////////////////

// Flit type
typedef struct {
  Bit#(id_)   rid;
  Bit#(data_) rdata;
  AXI4_Resp   rresp;
  Bool        rlast;
  Bit#(user_) ruser;
} AXI4_RFlit#(numeric type id_, numeric type data_, numeric type user_)
deriving (Bits, FShow);
instance DefaultValue#(AXI4_RFlit#(id_, data_, user_));
  function defaultValue = AXI4_RFlit {
    rid: 0, rdata: ?, rresp: OKAY, rlast: True, ruser: ?
  };
endinstance
instance Has_routingField #(AXI4_RFlit #(id_, data_, user_), Bit #(id_));
  function routingField (x) = x.rid;
endinstance
instance Has_isLast #(AXI4_RFlit #(id_, data_, user_));
  function isLast (x) = x.rlast;
endinstance

// Master interfaces
(* always_ready, always_enabled *)
interface AXI4_R_Master_Sig #( numeric type id_
                             , numeric type data_
                             , numeric type user_);
  (* prefix="" *) method Action rflit ( Bool        rvalid
                                      , Bit#(id_)   rid
                                      , Bit#(data_) rdata
                                      , AXI4_Resp   rresp
                                      , Bool        rlast
                                      , Bit#(user_) ruser);
  method Bool rready;
endinterface

instance CulDeSac#(AXI4_R_Master_Sig #(id_, data_, user_));
  function culDeSac = interface AXI4_R_Master_Sig;
    method rflit (a,b,c,d,e,f) = noAction;
    method rready = False;
  endinterface;
endinstance

// Slave interfaces
(* always_ready, always_enabled *)
interface AXI4_R_Slave_Sig #( numeric type id_
                            , numeric type data_
                            , numeric type user_);
  method Bit#(id_)   rid;
  method Bit#(data_) rdata;
  method AXI4_Resp   rresp;
  method Bool        rlast;
  method Bit#(user_) ruser;
  method Bool        rvalid;
  (* prefix="" *) method Action rready(Bool rready);
endinterface

instance CulDeSac#(AXI4_R_Slave_Sig #(id_, data_, user_));
  function culDeSac = interface AXI4_R_Slave_Sig;
    method rid       = ?;
    method rdata     = ?;
    method rresp     = ?;
    method rlast     = ?;
    method ruser     = ?;
    method rvalid    = False;
    method rready(_) = noAction;
  endinterface;
endinstance

// connectable instances
instance Connectable#(AXI4_R_Master_Sig#(a, b, c),
                      AXI4_R_Slave_Sig#(a, b, c));
  module mkConnection#(AXI4_R_Master_Sig#(a, b, c) m,
                       AXI4_R_Slave_Sig#(a, b, c) s)(Empty);
    (* fire_when_enabled, no_implicit_conditions *)
    rule connect;
      m.rflit(s.rvalid, s.rid, s.rdata, s.rresp, s.rlast, s.ruser);
      s.rready(m.rready);
    endrule
  endmodule
endinstance
instance Connectable#(AXI4_R_Slave_Sig#(a, b, c),
                      AXI4_R_Master_Sig#(a, b, c));
  module mkConnection#(AXI4_R_Slave_Sig#(a, b, c) s,
                       AXI4_R_Master_Sig#(a, b, c) m)(Empty);
    mkConnection(m, s);
  endmodule
endinstance

/////////////////
// AXI4 Master //
////////////////////////////////////////////////////////////////////////////////

interface AXI4_Master#(
  numeric type id_,
  numeric type addr_,
  numeric type data_,
  numeric type awuser_,
  numeric type wuser_,
  numeric type buser_,
  numeric type aruser_,
  numeric type ruser_);
  interface Source#(AXI4_AWFlit#(id_, addr_, awuser_)) aw;
  interface Source#(AXI4_WFlit#(data_, wuser_))        w;
  interface Sink#(AXI4_BFlit#(id_, buser_))            b;
  interface Source#(AXI4_ARFlit#(id_, addr_, aruser_)) ar;
  interface Sink#(AXI4_RFlit#(id_, data_, ruser_))     r;
endinterface

instance CulDeSac#(AXI4_Master#(id_,
                                addr_,
                                data_,
                                awuser_,
                                wuser_,
                                buser_,
                                aruser_,
                                ruser_));
  function culDeSac = interface AXI4_Master;
    interface aw = nullSource;
    interface  w = nullSource;
    interface  b = nullSink;
    interface ar = nullSource;
    interface  r = nullSink;
  endinterface;
endinstance

interface AXI4_Master_Sig #( numeric type id_
                           , numeric type addr_
                           , numeric type data_
                           , numeric type awuser_
                           , numeric type wuser_
                           , numeric type buser_
                           , numeric type aruser_
                           , numeric type ruser_);
  (* prefix = "" *) interface AXI4_AW_Master_Sig#(id_, addr_, awuser_) aw;
  (* prefix = "" *) interface AXI4_W_Master_Sig#(data_, wuser_)        w;
  (* prefix = "" *) interface AXI4_B_Master_Sig#(id_, buser_)          b;
  (* prefix = "" *) interface AXI4_AR_Master_Sig#(id_, addr_, aruser_) ar;
  (* prefix = "" *) interface AXI4_R_Master_Sig#(id_, data_, ruser_)   r;
endinterface

instance CulDeSac#(AXI4_Master_Sig #( id_
                                    , addr_
                                    , data_
                                    , awuser_
                                    , wuser_
                                    , buser_
                                    , aruser_
                                    , ruser_))
  provisos (
    CulDeSac#(AXI4_AW_Master_Sig#(id_, addr_, awuser_)),
    CulDeSac#(AXI4_W_Master_Sig#(data_, wuser_)),
    CulDeSac#(AXI4_B_Master_Sig#(id_, buser_)),
    CulDeSac#(AXI4_AR_Master_Sig#(id_, addr_, aruser_)),
    CulDeSac#(AXI4_R_Master_Sig#(id_, data_, ruser_))
  );
  function culDeSac = interface AXI4_Master_Sig;
    interface aw = culDeSac;
    interface  w = culDeSac;
    interface  b = culDeSac;
    interface ar = culDeSac;
    interface  r = culDeSac;
  endinterface;
endinstance

////////////////
// AXI4 Slave //
////////////////////////////////////////////////////////////////////////////////

interface AXI4_Slave#(
  numeric type id_,
  numeric type addr_,
  numeric type data_,
  numeric type awuser_,
  numeric type wuser_,
  numeric type buser_,
  numeric type aruser_,
  numeric type ruser_);
  interface Sink#(AXI4_AWFlit#(id_, addr_, awuser_)) aw;
  interface Sink#(AXI4_WFlit#(data_, wuser_))        w;
  interface Source#(AXI4_BFlit#(id_, buser_))        b;
  interface Sink#(AXI4_ARFlit#(id_, addr_, aruser_)) ar;
  interface Source#(AXI4_RFlit#(id_, data_, ruser_)) r;
endinterface

instance CulDeSac#(AXI4_Slave#(id_,
                               addr_,
                               data_,
                               awuser_,
                               wuser_,
                               buser_,
                               aruser_,
                               ruser_));
  function culDeSac = interface AXI4_Slave;
    interface aw = nullSink;
    interface  w = nullSink;
    interface  b = nullSource;
    interface ar = nullSink;
    interface  r = nullSource;
  endinterface;
endinstance

interface AXI4_Slave_Sig #( numeric type id_
                          , numeric type addr_
                          , numeric type data_
                          , numeric type awuser_
                          , numeric type wuser_
                          , numeric type buser_
                          , numeric type aruser_
                          , numeric type ruser_);
  (* prefix = "" *) interface AXI4_AW_Slave_Sig#(id_, addr_, awuser_) aw;
  (* prefix = "" *) interface AXI4_W_Slave_Sig#(data_, wuser_)        w;
  (* prefix = "" *) interface AXI4_B_Slave_Sig#(id_, buser_)          b;
  (* prefix = "" *) interface AXI4_AR_Slave_Sig#(id_, addr_, aruser_) ar;
  (* prefix = "" *) interface AXI4_R_Slave_Sig#(id_, data_, ruser_)   r;
endinterface

instance CulDeSac#(AXI4_Slave_Sig #( id_
                                   , addr_
                                   , data_
                                   , awuser_
                                   , wuser_
                                   , buser_
                                   , aruser_
                                   , ruser_))
  provisos (
    CulDeSac#(AXI4_AW_Slave_Sig#(id_, addr_, awuser_)),
    CulDeSac#(AXI4_W_Slave_Sig#(data_, wuser_)),
    CulDeSac#(AXI4_B_Slave_Sig#(id_, buser_)),
    CulDeSac#(AXI4_AR_Slave_Sig#(id_, addr_, aruser_)),
    CulDeSac#(AXI4_R_Slave_Sig#(id_, data_, ruser_))
  );
  function culDeSac = interface AXI4_Slave_Sig;
    interface aw = culDeSac;
    interface  w = culDeSac;
    interface  b = culDeSac;
    interface ar = culDeSac;
    interface  r = culDeSac;
  endinterface;
endinstance

////////////////////////////////
// AXI4 Shim Master <-> Slave //
////////////////////////////////////////////////////////////////////////////////

interface AXI4_Shim#(
  numeric type id_,
  numeric type addr_,
  numeric type data_,
  numeric type awuser_,
  numeric type wuser_,
  numeric type buser_,
  numeric type aruser_,
  numeric type ruser_);
  method Action clear;
  interface AXI4_Master#(
    id_, addr_, data_, awuser_, wuser_, buser_, aruser_, ruser_
  ) master;
  interface AXI4_Slave#(
    id_, addr_, data_, awuser_, wuser_, buser_, aruser_, ruser_
  ) slave;
endinterface

interface AXI4_Shim_Sig #( numeric type id_
                         , numeric type addr_
                         , numeric type data_
                         , numeric type awuser_
                         , numeric type wuser_
                         , numeric type buser_
                         , numeric type aruser_
                         , numeric type ruser_);
  method Action clear;
  interface AXI4_Master_Sig #(
    id_, addr_, data_, awuser_, wuser_, buser_, aruser_, ruser_
  ) master;
  interface AXI4_Slave_Sig #(
    id_, addr_, data_, awuser_, wuser_, buser_, aruser_, ruser_
  ) slave;
endinterface

// Type of events that can be monitored on an AXI4 port
typedef struct {
  Bool evt_AW_FLIT;
  Bool evt_W_FLIT;
  Bool evt_W_FLIT_FINAL;
  Bool evt_B_FLIT;
  Bool evt_AR_FLIT;
  Bool evt_R_FLIT;
  Bool evt_R_FLIT_FINAL;
} AXI4_Events deriving (Bits, FShow);
instance DefaultValue#(AXI4_Events);
  function defaultValue = AXI4_Events {
    evt_AW_FLIT: False,
    evt_W_FLIT: False,
    evt_W_FLIT_FINAL: False,
    evt_B_FLIT: False,
    evt_AR_FLIT: False,
    evt_R_FLIT: False,
    evt_R_FLIT_FINAL: False
  };
endinstance

////////////////////////////////
// AXI4 Connectable instances //
////////////////////////////////////////////////////////////////////////////////

instance Connectable#(
  AXI4_Master#(a, b, c, d, e, f, g, h),
  AXI4_Slave#(a, b, c, d, e, f, g, h));
  module mkConnection#(
    AXI4_Master#(a, b, c, d, e, f, g, h) m,
    AXI4_Slave#(a, b, c, d, e, f, g, h) s)
    (Empty);
    mkConnection(m.aw, s.aw);
    mkConnection(m.w, s.w);
    mkConnection(m.b, s.b);
    mkConnection(m.ar, s.ar);
    mkConnection(m.r, s.r);
  endmodule
endinstance
instance Connectable#(
  AXI4_Slave#(a, b, c, d, e, f, g, h),
  AXI4_Master#(a, b, c, d, e, f, g, h));
  module mkConnection#(
    AXI4_Slave#(a, b, c, d, e, f, g, h) s,
    AXI4_Master#(a, b, c, d, e, f, g, h) m)
    (Empty);
    mkConnection(m, s);
  endmodule
endinstance

instance Connectable#(
  AXI4_Master_Sig#(a, b, c, d, e, f, g, h),
  AXI4_Slave_Sig#(a, b, c, d, e, f, g, h));
  module mkConnection#(
    AXI4_Master_Sig#(a, b, c, d, e, f, g, h) m,
    AXI4_Slave_Sig#(a, b, c, d, e, f, g, h) s)
    (Empty);
    mkConnection(m.aw, s.aw);
    mkConnection(m.w, s.w);
    mkConnection(m.b, s.b);
    mkConnection(m.ar, s.ar);
    mkConnection(m.r, s.r);
  endmodule
endinstance
instance Connectable#(
  AXI4_Slave_Sig#(a, b, c, d, e, f, g, h),
  AXI4_Master_Sig#(a, b, c, d, e, f, g, h));
  module mkConnection#(
    AXI4_Slave_Sig#(a, b, c, d, e, f, g, h) s,
    AXI4_Master_Sig#(a, b, c, d, e, f, g, h) m)
    (Empty);
    mkConnection(m, s);
  endmodule
endinstance

////////////////////////////////////
// AXI4 write channel helper type //
////////////////////////////////////////////////////////////////////////////////

typedef union tagged {
  Tuple2#(AXI4_AWFlit#(id_, addr_, awuser_),
          AXI4_WFlit#(data_, wuser_)) FirstFlit;
  AXI4_WFlit#(data_, wuser_) OtherFlit;
} AXI4_WriteFlit#(
  numeric type id_,
  numeric type addr_,
  numeric type data_,
  numeric type awuser_,
  numeric type wuser_) deriving (FShow, Bits);
instance Has_routingField #(AXI4_WriteFlit #(id_, addr_, data_, awuser_, wuser_)
                           , Bit #(addr_));
  function routingField (x) = case (x) matches
    tagged FirstFlit {.aw, .w}: routingField (aw);
    default: 0;
  endcase;
endinstance
instance Has_isLast #(AXI4_WriteFlit #(id_, addr_, data_, awuser_, wuser_));
  function isLast (x) = case (x) matches
    tagged FirstFlit {.aw, .w}: isLast (w);
    tagged OtherFlit .w: isLast (w);
  endcase;
endinstance

////////////////////////////////
// ExpandableReqRsp instances //
////////////////////////////////////////////////////////////////////////////////

instance ExpandableReqRsp#(
  AXI4_WriteFlit#(id_, addr_, data_, awuser_, wuser_),
  AXI4_WriteFlit#(sid_, addr_, data_, awuser_, wuser_),
  AXI4_BFlit#(sid_, buser_),
  AXI4_BFlit#(id_, buser_),
  n) provisos (Add#(id_, TLog#(n), sid_));
  function expand(x, r) = case (r) matches
    tagged FirstFlit {.aw, .w}: FirstFlit(tuple2(AXI4_AWFlit {
      awid: {x, aw.awid}, awaddr: aw.awaddr, awlen: aw.awlen, awsize: aw.awsize,
      awburst: aw.awburst, awlock: aw.awlock, awcache: aw.awcache,
      awprot: aw.awprot, awqos: aw.awqos, awregion: aw.awregion,
      awuser: aw.awuser
    }, w));
    tagged OtherFlit .f: OtherFlit(f);
  endcase;
  function shrink(r) = tuple2(truncateLSB(r.bid), AXI4_BFlit {
    bid: truncate(r.bid), bresp: r.bresp, buser: r.buser
  });
endinstance

instance FallibleRoute#( AXI4_WriteFlit#(sid_, addr_, data_, awuser_, wuser_)
                       , AXI4_BFlit#(sid_, buser_));
  module mkNoRouteSlave (Slave #( AXI4_WriteFlit#(sid_, addr_, data_, awuser_, wuser_)
                                , AXI4_BFlit#(sid_, buser_)));
    let awidReg <- mkRegU;
    let rspFF <- mkFIFOF;
    interface req = interface Sink;
      method canPut = rspFF.notFull;
      method put (x) if (rspFF.notFull) = action
        let currentAwid = awidReg;
        case (x) matches
          tagged FirstFlit {.aw, ._}: currentAwid = aw.awid;
        endcase
        if (isLast (x)) rspFF.enq (AXI4_BFlit{ bid: currentAwid
                                               , bresp: DECERR
                                               , buser: ? });
        awidReg <= currentAwid;
      endaction;
    endinterface;
    interface rsp = toSource (rspFF);
  endmodule
endinstance
instance ExpandableReqRsp#(
  AXI4_ARFlit#(id_, addr_, aruser_),
  AXI4_ARFlit#(sid_, addr_, aruser_),
  AXI4_RFlit#(sid_, data_, ruser_),
  AXI4_RFlit#(id_, data_, ruser_),
  n) provisos (Add#(id_, TLog#(n), sid_));
  function expand(x, ar) = AXI4_ARFlit {
    arid: {x, ar.arid}, araddr: ar.araddr, arlen: ar.arlen, arsize: ar.arsize,
    arburst: ar.arburst, arlock: ar.arlock, arcache: ar.arcache,
    arprot: ar.arprot, arqos: ar.arqos, arregion: ar.arregion,
    aruser: ar.aruser
  };
  function shrink(r) = tuple2(truncateLSB(r.rid), AXI4_RFlit {
    rid: truncate(r.rid), rdata: r.rdata, rresp: r.rresp,
    rlast: r.rlast, ruser: r.ruser
  });
endinstance

instance FallibleRoute#( AXI4_ARFlit#(sid_, addr_, aruser_)
                       , AXI4_RFlit#(sid_, data_, ruser_));
  module mkNoRouteSlave (Slave #( AXI4_ARFlit#(sid_, addr_, aruser_)
                                , AXI4_RFlit#(sid_, data_, ruser_)));
    Reg#(AXI4_ARFlit#(sid_, addr_, aruser_)) currentReq <- mkRegU;
    Reg#(Bit#(TAdd#(SizeOf#(AXI4_Len), 1)))   flitCount <- mkReg(0);
    interface req = interface Sink;
      method canPut = flitCount == 0;
      method put (x) if (flitCount == 0) = action
        currentReq <= x;
        flitCount  <= zeroExtend(x.arlen) + 1;
      endaction;
    endinterface;
    interface rsp = interface Source;
      method canPeek = flitCount != 0;
      method peek if (flitCount != 0) = AXI4_RFlit{ rid: currentReq.arid
                                                  , rdata: ?
                                                  , rresp: DECERR
                                                  , rlast: flitCount == 1
                                                  , ruser: ? };
      method drop if (flitCount != 0) = action
        flitCount <= flitCount - 1;
      endaction;
    endinterface;
  endmodule
endinstance
