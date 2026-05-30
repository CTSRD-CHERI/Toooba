/*-
 * Copyright (c) 2018-2021 Alexandre Joannou
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

import Connectable :: *;
import DefaultValue :: *;

// BlueStuff import
import Routable :: *;
// BlueBasics import
import SourceSink :: *;
import MasterSlave :: *;

import AXI4_Common_Types :: *;

////////////////////////////////////
// AXI4Lite Address Write Channel //
////////////////////////////////////////////////////////////////////////////////

// Flit type
typedef struct {
  Bit#(addr_) awaddr;
  AXI4_Prot   awprot;
  Bit#(user_) awuser;
} AXI4Lite_AWFlit#(numeric type addr_,
                   numeric type user_) deriving (Bits, FShow);
instance DefaultValue#(AXI4Lite_AWFlit#(addr_, user_));
  function defaultValue = AXI4Lite_AWFlit { awaddr: ?, awprot: 0, awuser: ? };
endinstance
instance Has_routingField #(AXI4Lite_AWFlit #(addr_, user_), Bit #(addr_));
  function routingField (x) = x.awaddr;
endinstance
instance Has_isLast #(AXI4Lite_AWFlit #(addr_, user_));
  function isLast = constFn (True);
endinstance

// Master interfaces
(* always_ready, always_enabled *)
interface AXI4Lite_AW_Master_Sig#(numeric type addr_, numeric type user_);
  method Bit#(addr_) awaddr;
  method AXI4_Prot   awprot;
  method Bit#(user_) awuser;
  method Bool        awvalid;
  (* prefix="" *) method Action awready(Bool awready);
endinterface

instance CulDeSac#(AXI4Lite_AW_Master_Sig#(addr_, user_));
  function culDeSac = interface AXI4Lite_AW_Master_Sig;
    method awaddr     = ?;
    method awprot     = ?;
    method awuser     = ?;
    method awvalid    = False;
    method awready(_) = noAction;
  endinterface;
endinstance

// Slave interfaces
(* always_ready, always_enabled *)
interface AXI4Lite_AW_Slave_Sig#(numeric type addr_, numeric type user_);
  (* prefix="" *) method Action awflit ( Bool        awvalid
                                       , Bit#(addr_) awaddr
                                       , AXI4_Prot   awprot
                                       , Bit#(user_) awuser);
  method Bool awready;
endinterface

instance CulDeSac#(AXI4Lite_AW_Slave_Sig#(addr_, user_));
  function culDeSac = interface AXI4Lite_AW_Slave_Sig;
    method awflit (a, b, c, d) = noAction;
    method awready = True;
  endinterface;
endinstance

// connectable instances
instance Connectable#(AXI4Lite_AW_Master_Sig#(a, b),
                      AXI4Lite_AW_Slave_Sig#(a, b));
  module mkConnection#(AXI4Lite_AW_Master_Sig#(a,b ) m,
                       AXI4Lite_AW_Slave_Sig#(a, b) s)(Empty);
    (* fire_when_enabled, no_implicit_conditions *)
    rule connect;
      s.awflit(m.awvalid, m.awaddr, m.awprot, m.awuser);
      m.awready(s.awready);
    endrule
  endmodule
endinstance
instance Connectable#(AXI4Lite_AW_Slave_Sig#(a, b),
                      AXI4Lite_AW_Master_Sig#(a, b));
  module mkConnection#(AXI4Lite_AW_Slave_Sig#(a, b) s,
                       AXI4Lite_AW_Master_Sig#(a, b) m)(Empty);
    mkConnection(m, s);
  endmodule
endinstance

/////////////////////////////////
// AXI4Lite Write Data Channel //
////////////////////////////////////////////////////////////////////////////////

// Flit type
typedef struct {
  Bit#(data_)           wdata;
  Bit#(TDiv#(data_, 8)) wstrb;
  Bit#(user_)           wuser;
} AXI4Lite_WFlit#(numeric type data_,
                  numeric type user_) deriving (Bits, FShow);
instance DefaultValue#(AXI4Lite_WFlit#(data_, user_));
  function defaultValue = AXI4Lite_WFlit { wdata: ?, wstrb: ~0, wuser: ? };
endinstance
instance Has_isLast #(AXI4Lite_WFlit #(data_, user_));
  function isLast = constFn (True);
endinstance

// Master interfaces
(* always_ready, always_enabled *)
interface AXI4Lite_W_Master_Sig#(numeric type data_, numeric type user_);
  method Bit#(data_)           wdata;
  method Bit#(TDiv#(data_, 8)) wstrb;
  method Bit#(user_)           wuser;
  method Bool                  wvalid;
  (* prefix="" *) method Action wready(Bool wready);
endinterface

instance CulDeSac#(AXI4Lite_W_Master_Sig#(data_, user_));
  function culDeSac = interface AXI4Lite_W_Master_Sig;
    method wdata     = ?;
    method wstrb     = ?;
    method wuser     = ?;
    method wvalid    = False;
    method wready(_) = noAction;
  endinterface;
endinstance

// Slave interfaces
(* always_ready, always_enabled *)
interface AXI4Lite_W_Slave_Sig#(numeric type data_, numeric type user_);
  (* prefix="" *) method Action wflit ( Bool                  wvalid
                                      , Bit#(data_)           wdata
                                      , Bit#(TDiv#(data_, 8)) wstrb
                                      , Bit#(user_)           wuser);
  method Bool wready;
endinterface

instance CulDeSac#(AXI4Lite_W_Slave_Sig#(data_, user_));
  function culDeSac = interface AXI4Lite_W_Slave_Sig;
    method wflit (a, b, c, d) = noAction;
    method wready = False;
  endinterface;
endinstance

// connectable instances
instance Connectable#(AXI4Lite_W_Master_Sig#(a, b),
                      AXI4Lite_W_Slave_Sig#(a, b));
  module mkConnection#(AXI4Lite_W_Master_Sig#(a, b) m,
                       AXI4Lite_W_Slave_Sig#(a, b) s)(Empty);
    (* fire_when_enabled, no_implicit_conditions *)
    rule connect;
      s.wflit(m.wvalid, m.wdata, m.wstrb, m.wuser);
      m.wready(s.wready);
    endrule
  endmodule
endinstance
instance Connectable#(AXI4Lite_W_Slave_Sig#(a, b),
                      AXI4Lite_W_Master_Sig#(a, b));
  module mkConnection#(AXI4Lite_W_Slave_Sig#(a, b) s,
                       AXI4Lite_W_Master_Sig#(a, b) m)(Empty);
    mkConnection(m, s);
  endmodule
endinstance

/////////////////////////////////////
// AXI4Lite Write Response Channel //
////////////////////////////////////////////////////////////////////////////////

// Flit type
typedef struct {
  AXI4_Resp   bresp;
  Bit#(user_) buser;
} AXI4Lite_BFlit#(numeric type user_) deriving (Bits, FShow);
instance DefaultValue#(AXI4Lite_BFlit#(user_));
  function defaultValue = AXI4Lite_BFlit { bresp: OKAY, buser: ? };
endinstance
instance Has_isLast #(AXI4Lite_BFlit #(user_));
  function isLast = constFn (True);
endinstance

// Master interfaces
(* always_ready, always_enabled *)
interface AXI4Lite_B_Master_Sig#(numeric type user_);
  (* prefix="" *) method Action bflit ( Bool        bvalid
                                      , AXI4_Resp   bresp
                                      , Bit#(user_) buser);
  method Bool bready;
endinterface

instance CulDeSac#(AXI4Lite_B_Master_Sig#(user_));
  function culDeSac = interface AXI4Lite_B_Master_Sig;
    method bflit (a, b, c) = noAction;
    method bready = False;
  endinterface;
endinstance

// Slave interfaces
(* always_ready, always_enabled *)
interface AXI4Lite_B_Slave_Sig#(numeric type user_);
  method AXI4_Resp   bresp;
  method Bit#(user_) buser;
  method Bool        bvalid;
  (* prefix="" *) method Action bready(Bool bready);
endinterface

instance CulDeSac#(AXI4Lite_B_Slave_Sig#(user_));
  function culDeSac = interface AXI4Lite_B_Slave_Sig;
    method bresp     = ?;
    method buser     = ?;
    method bvalid    = False;
    method bready(_) = noAction;
  endinterface;
endinstance

// connectable instances
instance Connectable#(AXI4Lite_B_Master_Sig#(a), AXI4Lite_B_Slave_Sig#(a));
  module mkConnection#(AXI4Lite_B_Master_Sig#(a) m,
                       AXI4Lite_B_Slave_Sig#(a) s)(Empty);
    (* fire_when_enabled, no_implicit_conditions *)
    rule connect;
      m.bflit(s.bvalid, s.bresp, s.buser);
      s.bready(m.bready);
    endrule
  endmodule
endinstance
instance Connectable#(AXI4Lite_B_Slave_Sig#(a), AXI4Lite_B_Master_Sig#(a));
  module mkConnection#(AXI4Lite_B_Slave_Sig#(a) s,
                       AXI4Lite_B_Master_Sig#(a) m)(Empty);
    mkConnection(m, s);
  endmodule
endinstance

///////////////////////////////////
// AXI4Lite Read Address Channel //
////////////////////////////////////////////////////////////////////////////////

// Flit type
typedef struct {
  Bit#(addr_) araddr;
  AXI4_Prot   arprot;
  Bit#(user_) aruser;
} AXI4Lite_ARFlit#(numeric type addr_,
                   numeric type user_) deriving (Bits, FShow);
instance DefaultValue#(AXI4Lite_ARFlit#(addr_, user_));
  function defaultValue = AXI4Lite_ARFlit { araddr: ?, arprot: 0, aruser: ? };
endinstance
instance Has_routingField #(AXI4Lite_ARFlit #(addr_, user_), Bit #(addr_));
  function routingField (x) = x.araddr;
endinstance
instance Has_isLast #(AXI4Lite_ARFlit #(addr_, user_));
  function isLast = constFn (True);
endinstance

// Master interfaces
(* always_ready, always_enabled *)
interface AXI4Lite_AR_Master_Sig#(numeric type addr_, numeric type user_);
  method Bit#(addr_) araddr;
  method AXI4_Prot   arprot;
  method Bit#(user_) aruser;
  method Bool        arvalid;
  (* prefix="" *) method Action arready(Bool arready);
endinterface

instance CulDeSac#(AXI4Lite_AR_Master_Sig#(addr_, user_));
  function culDeSac = interface AXI4Lite_AR_Master_Sig;
    method araddr     = ?;
    method arprot     = ?;
    method aruser     = ?;
    method arvalid    = False;
    method arready(_) = noAction;
  endinterface;
endinstance

// Slave interfaces
(* always_ready, always_enabled *)
interface AXI4Lite_AR_Slave_Sig#(numeric type addr_, numeric type user_);
  (* prefix="" *) method Action arflit ( Bool        arvalid
                                       , Bit#(addr_) araddr
                                       , AXI4_Prot   arprot
                                       , Bit#(user_) aruser);
  method Bool arready;
endinterface

instance CulDeSac#(AXI4Lite_AR_Slave_Sig#(addr_, user_));
  function culDeSac = interface AXI4Lite_AR_Slave_Sig;
    method arflit (a, b, c, d) = noAction;
    method arready = False;
  endinterface;
endinstance

// connectable instances
instance Connectable#(AXI4Lite_AR_Master_Sig#(a, b),
                      AXI4Lite_AR_Slave_Sig#(a, b));
  module mkConnection#(AXI4Lite_AR_Master_Sig#(a, b) m,
                       AXI4Lite_AR_Slave_Sig#(a, b) s)(Empty);
    (* fire_when_enabled, no_implicit_conditions *)
    rule connect;
      s.arflit(m.arvalid, m.araddr, m.arprot, m.aruser);
      m.arready(s.arready);
    endrule
  endmodule
endinstance
instance Connectable#(AXI4Lite_AR_Slave_Sig#(a, b),
                      AXI4Lite_AR_Master_Sig#(a, b));
  module mkConnection#(AXI4Lite_AR_Slave_Sig#(a, b) s,
                       AXI4Lite_AR_Master_Sig#(a, b) m)(Empty);
    mkConnection(m, s);
  endmodule
endinstance

////////////////////////////////
// AXI4Lite Read Data Channel //
////////////////////////////////////////////////////////////////////////////////

// Flit type
typedef struct {
  Bit#(data_) rdata;
  AXI4_Resp   rresp;
  Bit#(user_) ruser;
} AXI4Lite_RFlit#(numeric type data_,
                  numeric type user_) deriving (Bits, FShow);
instance DefaultValue#(AXI4Lite_RFlit#(data_, user_));
  function defaultValue = AXI4Lite_RFlit { rdata: ?, rresp: OKAY, ruser: ? };
endinstance
instance Has_isLast #(AXI4Lite_RFlit #(data_, user_));
  function isLast = constFn (True);
endinstance

// Master interfaces
(* always_ready, always_enabled *)
interface AXI4Lite_R_Master_Sig#(numeric type data_, numeric type user_);
  (* prefix="" *) method Action rflit ( Bool        rvalid
                                      , Bit#(data_) rdata
                                      , AXI4_Resp   rresp
                                      , Bit#(user_) ruser);
  method Bool rready;
endinterface

instance CulDeSac#(AXI4Lite_R_Master_Sig#(data_, user_));
  function culDeSac = interface AXI4Lite_R_Master_Sig;
    method rflit (a, b, c, d) = noAction;
    method rready = False;
  endinterface;
endinstance

// Slave interfaces
(* always_ready, always_enabled *)
interface AXI4Lite_R_Slave_Sig#(numeric type data_, numeric type user_);
  method Bit#(data_) rdata;
  method AXI4_Resp   rresp;
  method Bit#(user_) ruser;
  method Bool        rvalid;
  (* prefix="" *) method Action rready(Bool rready);
endinterface

instance CulDeSac#(AXI4Lite_R_Slave_Sig#(data_, user_));
  function culDeSac = interface AXI4Lite_R_Slave_Sig;
    method rdata     = ?;
    method rresp     = ?;
    method ruser     = ?;
    method rvalid    = False;
    method rready(_) = noAction;
  endinterface;
endinstance

// connectable instances
instance Connectable#(AXI4Lite_R_Master_Sig#(a, b),
                      AXI4Lite_R_Slave_Sig#(a, b));
  module mkConnection#(AXI4Lite_R_Master_Sig#(a, b) m,
                       AXI4Lite_R_Slave_Sig#(a, b) s)(Empty);
    (* fire_when_enabled, no_implicit_conditions *)
    rule connect;
      m.rflit(s.rvalid, s.rdata, s.rresp, s.ruser);
      s.rready(m.rready);
    endrule
  endmodule
endinstance
instance Connectable#(AXI4Lite_R_Slave_Sig#(a, b),
                      AXI4Lite_R_Master_Sig#(a, b));
  module mkConnection#(AXI4Lite_R_Slave_Sig#(a, b) s,
                       AXI4Lite_R_Master_Sig#(a, b) m)(Empty);
    mkConnection(m, s);
  endmodule
endinstance

/////////////////////
// AXI4Lite Master //
////////////////////////////////////////////////////////////////////////////////

interface AXI4Lite_Master#(
  numeric type addr_,
  numeric type data_,
  numeric type awuser_,
  numeric type wuser_,
  numeric type buser_,
  numeric type aruser_,
  numeric type ruser_);
  interface Source#(AXI4Lite_AWFlit#(addr_, awuser_)) aw;
  interface Source#(AXI4Lite_WFlit#(data_, wuser_))   w;
  interface Sink#(AXI4Lite_BFlit#(buser_))            b;
  interface Source#(AXI4Lite_ARFlit#(addr_, aruser_)) ar;
  interface Sink#(AXI4Lite_RFlit#(data_, ruser_))     r;
endinterface

instance CulDeSac#(AXI4Lite_Master#( addr_
                                   , data_
                                   , awuser_
                                   , wuser_
                                   , buser_
                                   , aruser_
                                   , ruser_));
  function culDeSac = interface AXI4Lite_Master;
    interface aw = nullSource;
    interface  w = nullSource;
    interface  b = nullSink;
    interface ar = nullSource;
    interface  r = nullSink;
  endinterface;
endinstance

interface AXI4Lite_Master_Sig#(
  numeric type addr_,
  numeric type data_,
  numeric type awuser_,
  numeric type wuser_,
  numeric type buser_,
  numeric type aruser_,
  numeric type ruser_);
  (* prefix = "" *) interface AXI4Lite_AW_Master_Sig#(addr_, awuser_) aw;
  (* prefix = "" *) interface AXI4Lite_W_Master_Sig#(data_, wuser_)   w;
  (* prefix = "" *) interface AXI4Lite_B_Master_Sig#(buser_)          b;
  (* prefix = "" *) interface AXI4Lite_AR_Master_Sig#(addr_, aruser_) ar;
  (* prefix = "" *) interface AXI4Lite_R_Master_Sig#(data_, ruser_)   r;
endinterface

instance CulDeSac#(AXI4Lite_Master_Sig#( addr_
                                       , data_
                                       , awuser_
                                       , wuser_
                                       , buser_
                                       , aruser_
                                       , ruser_))
  provisos (
    CulDeSac#(AXI4Lite_AW_Master_Sig#(addr_, awuser_)),
    CulDeSac#(AXI4Lite_W_Master_Sig#(data_, wuser_)),
    CulDeSac#(AXI4Lite_B_Master_Sig#(buser_)),
    CulDeSac#(AXI4Lite_AR_Master_Sig#(addr_, aruser_)),
    CulDeSac#(AXI4Lite_R_Master_Sig#(data_, ruser_))
  );
  function culDeSac = interface AXI4Lite_Master_Sig;
    interface aw = culDeSac;
    interface  w = culDeSac;
    interface  b = culDeSac;
    interface ar = culDeSac;
    interface  r = culDeSac;
  endinterface;
endinstance

interface AXI4Lite_Master_Xactor#(
  numeric type addr_,
  numeric type data_,
  numeric type awuser_,
  numeric type wuser_,
  numeric type buser_,
  numeric type aruser_,
  numeric type ruser_);
  method Action clear;
  interface AXI4Lite_Slave#( addr_
                           , data_
                           , awuser_
                           , wuser_
                           , buser_
                           , aruser_
                           , ruser_) slave;
  interface AXI4Lite_Master_Sig#( addr_
                                , data_
                                , awuser_
                                , wuser_
                                , buser_
                                , aruser_
                                , ruser_) masterSig;
endinterface

////////////////////
// AXI4Lite Slave //
////////////////////////////////////////////////////////////////////////////////

interface AXI4Lite_Slave#(
  numeric type addr_,
  numeric type data_,
  numeric type awuser_,
  numeric type wuser_,
  numeric type buser_,
  numeric type aruser_,
  numeric type ruser_);
  interface Sink#(AXI4Lite_AWFlit#(addr_, awuser_)) aw;
  interface Sink#(AXI4Lite_WFlit#(data_, wuser_))   w;
  interface Source#(AXI4Lite_BFlit#(buser_))        b;
  interface Sink#(AXI4Lite_ARFlit#(addr_, aruser_)) ar;
  interface Source#(AXI4Lite_RFlit#(data_, ruser_)) r;
endinterface

instance CulDeSac#(AXI4Lite_Slave#( addr_
                                  , data_
                                  , awuser_
                                  , wuser_
                                  , buser_
                                  , aruser_
                                  , ruser_));
  function culDeSac = interface AXI4Lite_Slave;
    interface aw = nullSink;
    interface  w = nullSink;
    interface  b = nullSource;
    interface ar = nullSink;
    interface  r = nullSource;
  endinterface;
endinstance

interface AXI4Lite_Slave_Sig#(
  numeric type addr_,
  numeric type data_,
  numeric type awuser_,
  numeric type wuser_,
  numeric type buser_,
  numeric type aruser_,
  numeric type ruser_);
  (* prefix = "" *) interface AXI4Lite_AW_Slave_Sig#(addr_, awuser_) aw;
  (* prefix = "" *) interface AXI4Lite_W_Slave_Sig#(data_, wuser_)   w;
  (* prefix = "" *) interface AXI4Lite_B_Slave_Sig#(buser_)          b;
  (* prefix = "" *) interface AXI4Lite_AR_Slave_Sig#(addr_, aruser_) ar;
  (* prefix = "" *) interface AXI4Lite_R_Slave_Sig#(data_, ruser_)   r;
endinterface

instance CulDeSac#(AXI4Lite_Slave_Sig#( addr_
                                      , data_
                                      , awuser_
                                      , wuser_
                                      , buser_
                                      , aruser_
                                      , ruser_))
  provisos (
    CulDeSac#(AXI4Lite_AW_Slave_Sig#(addr_, awuser_)),
    CulDeSac#(AXI4Lite_W_Slave_Sig#(data_, wuser_)),
    CulDeSac#(AXI4Lite_B_Slave_Sig#(buser_)),
    CulDeSac#(AXI4Lite_AR_Slave_Sig#(addr_, aruser_)),
    CulDeSac#(AXI4Lite_R_Slave_Sig#(data_, ruser_))
  );
  function culDeSac = interface AXI4Lite_Slave_Sig;
    interface aw = culDeSac;
    interface  w = culDeSac;
    interface  b = culDeSac;
    interface ar = culDeSac;
    interface  r = culDeSac;
  endinterface;
endinstance

interface AXI4Lite_Slave_Xactor#(
  numeric type addr_,
  numeric type data_,
  numeric type awuser_,
  numeric type wuser_,
  numeric type buser_,
  numeric type aruser_,
  numeric type ruser_);
  method Action clear;
  interface AXI4Lite_Master#( addr_
                            , data_
                            , awuser_
                            , wuser_
                            , buser_
                            , aruser_
                            , ruser_) master;
  interface AXI4Lite_Slave_Sig#( addr_
                               , data_
                               , awuser_
                               , wuser_
                               , buser_
                               , aruser_
                               , ruser_) slaveSig;
endinterface

////////////////////////////////////
// AXI4Lite Shim Master <-> Slave //
////////////////////////////////////////////////////////////////////////////////

interface AXI4Lite_Shim#(
  numeric type addr_,
  numeric type data_,
  numeric type awuser_,
  numeric type wuser_,
  numeric type buser_,
  numeric type aruser_,
  numeric type ruser_);
  method Action clear;
  interface AXI4Lite_Master#(
    addr_, data_, awuser_, wuser_, buser_, aruser_, ruser_
  ) master;
  interface AXI4Lite_Slave#(
    addr_, data_, awuser_, wuser_, buser_, aruser_, ruser_
  ) slave;
endinterface

interface AXI4Lite_Shim_Sig#(
  numeric type addr_,
  numeric type data_,
  numeric type awuser_,
  numeric type wuser_,
  numeric type buser_,
  numeric type aruser_,
  numeric type ruser_);
  method Action clear;
  interface AXI4Lite_Master_Sig#(
    addr_, data_, awuser_, wuser_, buser_, aruser_, ruser_
  ) master;
  interface AXI4Lite_Slave_Sig#(
    addr_, data_, awuser_, wuser_, buser_, aruser_, ruser_
  ) slave;
endinterface

////////////////////////////////////
// AXI4Lite Connectable instances //
////////////////////////////////////////////////////////////////////////////////

instance Connectable#(
  AXI4Lite_Master#(a, b, c, d, e, f, g),
  AXI4Lite_Slave#(a, b, c, d, e, f, g));
  module mkConnection#(
    AXI4Lite_Master#(a, b, c, d, e, f, g) m,
    AXI4Lite_Slave#(a, b, c, d, e, f, g) s)
    (Empty);
    mkConnection(m.aw, s.aw);
    mkConnection(m.w, s.w);
    mkConnection(m.b, s.b);
    mkConnection(m.ar, s.ar);
    mkConnection(m.r, s.r);
  endmodule
endinstance
instance Connectable#(
  AXI4Lite_Slave#(a, b, c, d, e, f, g),
  AXI4Lite_Master#(a, b, c, d, e, f, g));
  module mkConnection#(
    AXI4Lite_Slave#(a, b, c, d, e, f, g) s,
    AXI4Lite_Master#(a, b, c, d, e, f, g) m)
    (Empty);
    mkConnection(m, s);
  endmodule
endinstance

instance Connectable#(
  AXI4Lite_Master_Sig#(a, b, c, d, e, f, g),
  AXI4Lite_Slave_Sig#(a, b, c, d, e, f, g));
  module mkConnection#(
    AXI4Lite_Master_Sig#(a, b, c, d, e, f, g) m,
    AXI4Lite_Slave_Sig#(a, b, c, d, e, f, g) s)
    (Empty);
    mkConnection(m.aw, s.aw);
    mkConnection(m.w, s.w);
    mkConnection(m.b, s.b);
    mkConnection(m.ar, s.ar);
    mkConnection(m.r, s.r);
  endmodule
endinstance
instance Connectable#(
  AXI4Lite_Slave_Sig#(a, b, c, d, e, f, g),
  AXI4Lite_Master_Sig#(a, b, c, d, e, f, g));
  module mkConnection#(
    AXI4Lite_Slave_Sig#(a, b, c, d, e, f, g) s,
    AXI4Lite_Master_Sig#(a, b, c, d, e, f, g) m)
    (Empty);
    mkConnection(m, s);
  endmodule
endinstance

////////////////////////////////////////
// AXI4Lite write channel helper type //
////////////////////////////////////////////////////////////////////////////////

typedef struct {
  AXI4Lite_AWFlit#(addr_, awuser_) aw;
  AXI4Lite_WFlit#(data_, wuser_)  w;
} AXI4Lite_WriteFlit#(
  numeric type addr_,
  numeric type data_,
  numeric type awuser_,
  numeric type wuser_) deriving (Bits, FShow);
instance Has_routingField #(AXI4Lite_WriteFlit #(addr_, data_, awuser_, wuser_)
                           , Bit #(addr_));
  function routingField (x) = routingField (x.aw);
endinstance
instance Has_isLast #(AXI4Lite_WriteFlit #(addr_, data_, awuser_, wuser_));
  function isLast = constFn (True);
endinstance

/////////////////////////////
// FallibleRoute instances //
////////////////////////////////////////////////////////////////////////////////

instance FallibleRoute #( AXI4Lite_WriteFlit #(addr_, data_, awuser_, wuser_)
                        , AXI4Lite_BFlit #(buser_));
  module mkNoRouteSlave ( Slave #(
      AXI4Lite_WriteFlit #(addr_, data_, awuser_, wuser_)
    , AXI4Lite_BFlit #(buser_)));
    Reg #(Bool) send_rsp[2] <- mkCReg (2, False);
    interface req = interface Sink;
      method canPut = !send_rsp[0];
      method put (x) if (!send_rsp[0]) = action
        send_rsp[0] <= True;
      endaction;
    endinterface;
    interface rsp = interface Source;
      method canPeek = send_rsp[1];
      method peek if (send_rsp[1]) = AXI4Lite_BFlit { bresp: DECERR, buser: ? };
      method drop if (send_rsp[1]) = writeReg (send_rsp[1], False);
    endinterface;
  endmodule
endinstance

instance FallibleRoute #(
  WithMetaInfo #(AXI4Lite_WriteFlit #(addr_, data_, awuser_, wuser_), down_t)
, WithRouteInfo #(AXI4Lite_BFlit #(buser_), down_t))
provisos ( Bits #(down_t, down_t_sz) );
  module mkNoRouteSlave (Slave #(
    WithMetaInfo #(AXI4Lite_WriteFlit #(addr_, data_, awuser_, wuser_), down_t)
  , WithRouteInfo #(AXI4Lite_BFlit #(buser_), down_t)));
    Reg #(Maybe #(down_t)) m_send_rsp[2] <- mkCReg (2, Invalid);
    interface req = interface Sink;
      method canPut = !isValid (m_send_rsp[0]);
      method put (x) if (!isValid (m_send_rsp[0])) = action
        m_send_rsp[0] <= Valid (x.metaInfo);
      endaction;
    endinterface;
    interface rsp = interface Source;
      method canPeek = isValid (m_send_rsp[1]);
      method peek if (isValid (m_send_rsp[1])) =
        WithRouteInfo { routeInfo: m_send_rsp[1].Valid
                      , payload: AXI4Lite_BFlit { bresp: DECERR, buser: ? } };
      method drop if (isValid (m_send_rsp[1])) =
        writeReg (m_send_rsp[1], Invalid);
    endinterface;
  endmodule
endinstance

instance FallibleRoute #( AXI4Lite_ARFlit #(addr_, aruser_)
                        , AXI4Lite_RFlit #(data_, ruser_));
  module mkNoRouteSlave ( Slave #(
      AXI4Lite_ARFlit #(addr_, aruser_)
    , AXI4Lite_RFlit #(data_, ruser_)));
    Reg #(Bool) send_rsp[2] <- mkCReg (2, False);
    interface req = interface Sink;
      method canPut = !send_rsp[0];
      method put (x) if (!send_rsp[0]) = action
        send_rsp[0] <= True;
      endaction;
    endinterface;
    interface rsp = interface Source;
      method canPeek = send_rsp[1];
      method peek if (send_rsp[1]) = AXI4Lite_RFlit { rdata: ?
                                                    , rresp: DECERR
                                                    , ruser: ? };
      method drop if (send_rsp[1]) = writeReg (send_rsp[1], False);
    endinterface;
  endmodule
endinstance

instance FallibleRoute #(
  WithMetaInfo #(AXI4Lite_ARFlit #(addr_, aruser_), down_t)
, WithRouteInfo #(AXI4Lite_RFlit #(data_, ruser_), down_t))
provisos ( Bits #(down_t, down_t_sz) );
  module mkNoRouteSlave (Slave #(
    WithMetaInfo #(AXI4Lite_ARFlit #(addr_, aruser_), down_t)
  , WithRouteInfo #(AXI4Lite_RFlit #(data_, ruser_), down_t)));
    Reg #(Maybe #(down_t)) m_send_rsp[2] <- mkCReg (2, Invalid);
    interface req = interface Sink;
      method canPut = !isValid (m_send_rsp[0]);
      method put (x) if (!isValid (m_send_rsp[0])) = action
        m_send_rsp[0] <= Valid (x.metaInfo);
      endaction;
    endinterface;
    interface rsp = interface Source;
      method canPeek = isValid (m_send_rsp[1]);
      method peek if (isValid (m_send_rsp[1])) =
        WithRouteInfo { routeInfo: m_send_rsp[1].Valid
                      , payload: AXI4Lite_RFlit { rdata: ?
                                                , rresp: DECERR
                                                , ruser: ? } };
      method drop if (isValid (m_send_rsp[1])) =
        writeReg (m_send_rsp[1], Invalid);
    endinterface;
  endmodule
endinstance
