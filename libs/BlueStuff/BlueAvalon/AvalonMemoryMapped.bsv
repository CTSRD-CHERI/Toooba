/*-
 * Copyright (c) 2023 Alexandre Joannou
 * All rights reserved.
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

package AvalonMemoryMapped;

import FIFOF :: *;
import SpecialFIFOs :: *;
import Assert :: *;
import Connectable :: *;

import BlueBasics :: *;

// info / debug prints
Integer curLvl = 0;
function Action lvlPrint (Integer tgtLvl, Fmt msg) = action
  if (curLvl >= tgtLvl) $display ("<%0t> ", $time, msg);
endaction;

// Flit types and interfaces
////////////////////////////////////////////////////////////////////////////////

// The AvalonMM{Request, Response} types are to be used when designing avalon
// components. The AvalonMM{Host2Agent, Agent2Host} types are useful to
// lower high level information contained in the AvalonMM{Request, Response}
// types (through the avalonMMReq2Host2Agent and avalonMMAgent2Host2Rsp utility
// functions) down to the actual [Pipelined]AvalonMM{Host, Agent} interfaces.

///////////////////
// Host -> Agent //
///////////////////

typedef struct {
  Bit #(t_byte_addr_w) address;
  Bool lock;
  Bit #(TDiv #(t_data_w, 8)) byteenable;
  // Bit #(t_burstcount_w) burstcount;
  union tagged {
    void Read;
    Bit #(t_data_w) Write;
  } operation;
} AvalonMMRequest #( numeric type t_byte_addr_w
                   , numeric type t_data_w )
deriving (Bits, FShow);

typeclass ToAvalonMMRequest #( type t
                             , numeric type t_byte_addr_w
                             , numeric type t_data_w );
  function AvalonMMRequest #(t_byte_addr_w, t_data_w) toAvalonMMRequest (t x);
endtypeclass

typeclass FromAvalonMMRequest #( type t
                               , numeric type t_byte_addr_w
                               , numeric type t_data_w );
  function t fromAvalonMMRequest (AvalonMMRequest #(t_byte_addr_w, t_data_w) x);
endtypeclass

typedef struct {
  Bit #(t_byte_addr_w) address;
  Bool lock;
  // Bit #(t_burstcount_w) burstcount;
  Bool read;
  Bool write;
  Bit #(TDiv #(t_data_w, 8)) byteenable;
  Bit #(t_data_w) writedata;
} AvalonMMHost2Agent #( numeric type t_byte_addr_w
                      , numeric type t_data_w )
deriving (Bits);

function AvalonMMHost2Agent #(t_byte_addr_w, t_data_w)
  avalonMMReq2Host2Agent (AvalonMMRequest #(t_byte_addr_w, t_data_w) req) =
  AvalonMMHost2Agent {
    address: req.address
  , lock: req.lock
  , read: req.operation matches tagged Read ? True : False
  , write: req.operation matches tagged Write .* ? True : False
  , byteenable: req.byteenable
  , writedata: req.operation.Write
  };

function AvalonMMRequest #(t_byte_addr_w, t_data_w)
  avalonMMHost2Agent2Req (AvalonMMHost2Agent #(t_byte_addr_w, t_data_w) h2a) =
  AvalonMMRequest {
    address: h2a.address
  , byteenable: h2a.byteenable
  , lock: h2a.lock
  , operation: h2a.read
             ? tagged Read
             : h2a.write
             ? tagged Write h2a.writedata
             : ? };

instance ToAvalonMMRequest #( AvalonMMHost2Agent #(t_byte_addr_w, t_data_w)
                            , t_byte_addr_w, t_data_w );
  function toAvalonMMRequest = avalonMMHost2Agent2Req;
endinstance

instance FromAvalonMMRequest #( AvalonMMHost2Agent #(t_byte_addr_w, t_data_w)
                             , t_byte_addr_w, t_data_w );
  function fromAvalonMMRequest = avalonMMReq2Host2Agent;
endinstance

///////////////////
// Agent -> Host //
///////////////////

typedef struct {
  Bit #(2) response;
  union tagged {
    Bit #(t_data_w) Read;
    void Write;
  } operation;
} AvalonMMResponse #(numeric type t_data_w)
deriving (Bits, FShow);

typeclass ToAvalonMMResponse #(type t, numeric type t_data_w);
  function AvalonMMResponse #(t_data_w) toAvalonMMResponse (t x);
endtypeclass

typeclass FromAvalonMMResponse #(type t, numeric type t_data_w);
  function t fromAvalonMMResponse (AvalonMMResponse #(t_data_w) x);
endtypeclass

typedef struct {
  Bit #(2) response;
  Bit #(t_data_w) readdata;
  Bool waitrequest;
  Bool readdatavalid;
  Bool writeresponsevalid;
} AvalonMMAgent2Host #(numeric type t_data_w)
deriving (Bits);

function AvalonMMResponse #(t_data_w)
  avalonMMAgent2Host2Rsp (AvalonMMAgent2Host #(t_data_w) a2h) =
  AvalonMMResponse { response: a2h.response
                   , operation: a2h.readdatavalid
                              ? tagged Read (a2h.readdata)
                              : a2h.writeresponsevalid
                              ? tagged Write
                              : ? };

function AvalonMMAgent2Host #(t_data_w)
  avalonMMRsp2Agent2Host (AvalonMMResponse #(t_data_w) rsp) =
  AvalonMMAgent2Host { response: rsp.response
                     , readdata: rsp.operation.Read
                     , waitrequest: error ("this should never be inspected")
                     , readdatavalid:
                         rsp.operation matches tagged Read .* ? True : False
                     , writeresponsevalid:
                         rsp.operation matches tagged Write ? True : False };

instance ToAvalonMMResponse #(AvalonMMAgent2Host #(t_data_w), t_data_w);
  function toAvalonMMResponse = avalonMMAgent2Host2Rsp;
endinstance

instance FromAvalonMMResponse #(AvalonMMAgent2Host #(t_data_w), t_data_w);
  function fromAvalonMMResponse = avalonMMRsp2Agent2Host;
endinstance

////////////////////
// Host intefaces //
////////////////////

(* always_ready, always_enabled *)
interface AvalonMMHost #( numeric type t_byte_addr_w
                        , numeric type t_data_w );
  // host to agent
  method Bit #(t_byte_addr_w) address;
  method Bool read;
  method Bool write;
  method Bit #(TDiv #(t_data_w, 8)) byteenable;
  method Bit #(t_data_w) writedata;
  method Bool lock;
  // agent to host
  (* prefix="" *) method Action agent2host ( Bool waitrequest
                                           , Bit #(2) response
                                           , Bit #(t_data_w) readdata );
endinterface

instance FShow #(AvalonMMHost #(t_byte_addr_w, t_data_w));
  function fshow (ifc) = $format ("AvalonMMHost")
    + $format ("\n  .address: ")    + fshow (ifc.address)
    + $format ("\n  .read: ")       + fshow (ifc.read)
    + $format ("\n  .write: ")      + fshow (ifc.write)
    + $format ("\n  .byteenable: ") + fshow (ifc.byteenable)
    + $format ("\n  .writedata: ")  + fshow (ifc.writedata)
    + $format ("\n  .lock: ")       + fshow (ifc.lock)
    ;
endinstance

(* always_ready, always_enabled *)
interface PipelinedAvalonMMHost #( numeric type t_byte_addr_w
                                 , numeric type t_data_w );
  // host to agent
  method Bit #(t_byte_addr_w) address;
  method Bool read;
  method Bool write;
  method Bit #(TDiv #(t_data_w, 8)) byteenable;
  method Bit #(t_data_w) writedata;
  method Bool lock;
  // agent to host
  (* prefix="" *) method Action agent2host ( Bool waitrequest
                                           , Bit #(2) response
                                           , Bit #(t_data_w) readdata
                                           , Bool readdatavalid
                                           , Bool writeresponsevalid );
endinterface

instance FShow #(PipelinedAvalonMMHost #(t_byte_addr_w, t_data_w));
  function fshow (ifc) = $format ("PipelinedAvalonMMHost")
    + $format ("\n  .address: ")    + fshow (ifc.address)
    + $format ("\n  .read: ")       + fshow (ifc.read)
    + $format ("\n  .write: ")      + fshow (ifc.write)
    + $format ("\n  .byteenable: ") + fshow (ifc.byteenable)
    + $format ("\n  .writedata: ")  + fshow (ifc.writedata)
    + $format ("\n  .lock: ")       + fshow (ifc.lock)
    ;
endinstance

//////////////////////
// Agent Interfaces //
//////////////////////

(* always_ready, always_enabled *)
interface AvalonMMAgent #( numeric type t_byte_addr_w
                         , numeric type t_data_w );
  // host to agent
  (* prefix="" *) method Action host2agent (
      Bit #(t_byte_addr_w) address
    , Bool read
    , Bool write
    , Bit #(TDiv #(t_data_w, 8)) byteenable
    , Bit #(t_data_w) writedata
    , Bool lock );
  // agent to host
  method Bool waitrequest;
  method Bit #(2) response;
  method Bit #(t_data_w) readdata;
endinterface

instance FShow #(AvalonMMAgent #(t_byte_addr_w, t_data_w));
  function fshow (ifc) = $format ("AvalonMMAgent")
    + $format ("\n  .waitrequest: ") + fshow (ifc.waitrequest)
    + $format ("\n  .response: ")    + fshow (ifc.response)
    + $format ("\n  .readdata: ")    + fshow (ifc.readdata)
    ;
endinstance

(* always_ready, always_enabled *)
interface PipelinedAvalonMMAgent #( numeric type t_byte_addr_w
                                  , numeric type t_data_w );
  // host to agent
  (* prefix="" *) method Action host2agent (
      Bit #(t_byte_addr_w) address
    , Bool read
    , Bool write
    , Bit #(TDiv #(t_data_w, 8)) byteenable
    , Bit #(t_data_w) writedata
    , Bool lock );
  // agent to host
  method Bool waitrequest;
  method Bit #(2) response;
  method Bit #(t_data_w) readdata;
  method Bool readdatavalid;
  method Bool writeresponsevalid;
endinterface

instance FShow #(PipelinedAvalonMMAgent #(t_byte_addr_w, t_data_w));
  function fshow (ifc) = $format ("PipelinedAvalonMMAgent")
    + $format ("\n  .waitrequest: ")        + fshow (ifc.waitrequest)
    + $format ("\n  .response: ")           + fshow (ifc.response)
    + $format ("\n  .readdata: ")           + fshow (ifc.readdata)
    + $format ("\n  .readdatavalid: ")      + fshow (ifc.readdatavalid)
    + $format ("\n  .writeresponsevalid: ") + fshow (ifc.writeresponsevalid)
    ;
endinstance

//////////////////////////
// connectable instance //
//////////////////////////

instance Connectable #( AvalonMMHost #(t_byte_addr_w, t_data_w)
                      , AvalonMMAgent #(t_byte_addr_w, t_data_w) );
  module mkConnection #( AvalonMMHost #(t_byte_addr_w, t_data_w) h
                       , AvalonMMAgent #(t_byte_addr_w, t_data_w) a ) (Empty);
    (* fire_when_enabled, no_implicit_conditions *)
    rule connect_a2h;
      h.agent2host (a.waitrequest, a.response, a.readdata);
    endrule
    (* fire_when_enabled, no_implicit_conditions *)
    rule connect_h2a;
      a.host2agent ( h.address
                   , h.read
                   , h.write
                   , h.byteenable
                   , h.writedata
                   , h.lock );
    endrule
  endmodule
endinstance

instance Connectable #( AvalonMMAgent #(t_byte_addr_w, t_data_w)
                      , AvalonMMHost #(t_byte_addr_w, t_data_w) );
  module mkConnection #( AvalonMMAgent #(t_byte_addr_w, t_data_w) a
                       , AvalonMMHost #(t_byte_addr_w, t_data_w) h ) (Empty);
    mkConnection (h, a);
  endmodule
endinstance

instance Connectable #( PipelinedAvalonMMHost #(t_byte_addr_w, t_data_w)
                      , PipelinedAvalonMMAgent #(t_byte_addr_w, t_data_w) );
  module mkConnection #( PipelinedAvalonMMHost #(t_byte_addr_w, t_data_w) h
                       , PipelinedAvalonMMAgent #(t_byte_addr_w, t_data_w) a )
                       (Empty);
    (* fire_when_enabled, no_implicit_conditions *)
    rule connect_a2h;
      h.agent2host ( a.waitrequest
                   , a.response
                   , a.readdata
                   , a.readdatavalid
                   , a.writeresponsevalid );
    endrule
    (* fire_when_enabled, no_implicit_conditions *)
    rule connect_h2a;
      a.host2agent ( h.address
                   , h.read
                   , h.write
                   , h.byteenable
                   , h.writedata
                   , h.lock );
    endrule
  endmodule
endinstance

instance Connectable #( PipelinedAvalonMMAgent #(t_byte_addr_w, t_data_w)
                      , PipelinedAvalonMMHost #(t_byte_addr_w, t_data_w) );
  module mkConnection #( PipelinedAvalonMMAgent #(t_byte_addr_w, t_data_w) a
                       , PipelinedAvalonMMHost #(t_byte_addr_w, t_data_w) h )
                       (Empty);
    mkConnection (h, a);
  endmodule
endinstance

// "transactors"
////////////////////////////////////////////////////////////////////////////////

// Simple to host
/////////////////

typedef enum {Idle, Wait} ToAvalonMMHostState deriving (Bits, Eq);
module avalonMMHostTransactor
  (Tuple2 #( Slave #( AvalonMMRequest #(t_byte_addr_w, t_data_w)
                    , AvalonMMResponse #(t_data_w) )
           , AvalonMMHost #(t_byte_addr_w, t_data_w) ));

  // responses / agent to host signaling
  FIFOF #(AvalonMMResponse #(t_data_w)) ff_a2h <- mkFIFOF;
  Wire #(AvalonMMAgent2Host #(t_data_w)) w_a2h <- mkBypassWire;
  // requests / host to agent signaling
  let ff_h2a <- mkBypassFIFOF;
  let src_h2a = mapSource (avalonMMReq2Host2Agent, toSource (ff_h2a));
  let w_h2a <- mkDWire (AvalonMMHost2Agent { address: ?
                                           , lock: ?
                                           // burstcount
                                           , read: False
                                           , write: False
                                           , byteenable: ?
                                           , writedata: ?
                                           });
  // state register
  Reg #(ToAvalonMMHostState) r_state <- mkReg (Idle);

  //////////////////////////////////////////////////////////////////////////////

  Bool can_sample_request = r_state == Idle && src_h2a.canPeek;

  rule sample_request (r_state == Idle && src_h2a.canPeek);
    w_h2a <= src_h2a.peek;
  endrule

  rule consume_request (r_state == Idle && src_h2a.canPeek
                                        && !w_a2h.waitrequest);
    src_h2a.drop;
    r_state <= Wait;
  endrule

  rule forward_response (r_state == Wait && ff_a2h.notFull
                                         && !w_a2h.waitrequest);
    ff_a2h.enq (avalonMMAgent2Host2Rsp (w_a2h));
    r_state <= Idle;
  endrule

  //////////////////////////////////////////////////////////////////////////////

  // AvalonMMHost interface
  let avmmh = interface AvalonMMHost;
    method Bit #(t_byte_addr_w) address = w_h2a.address;
    method Bool read = w_h2a.read;
    method Bool write = w_h2a.write;
    method Bit #(TDiv #(t_data_w, 8)) byteenable = w_h2a.byteenable;
    method Bit #(t_data_w) writedata = w_h2a.writedata;
    method Bool lock = w_h2a.lock;
    method Action agent2host ( Bool waitrequest
                             , Bit #(2) response
                             , Bit #(t_data_w) readdata ) = action
      w_a2h <= AvalonMMAgent2Host { waitrequest: waitrequest
                                  , response: response
                                  , readdata: readdata
                                  , readdatavalid: ?
                                  , writeresponsevalid: ? };
    endaction;
  endinterface;

  return tuple2 (toSlave (ff_h2a, ff_a2h), avmmh);

endmodule

// Pipelined to host
////////////////////

module toPipelinedAvalonMMHost #(
    parameter NumProxy #(t_depth) depth_proxy
  , Master #( AvalonMMRequest #(t_byte_addr_w, t_data_w)
            , AvalonMMResponse #(t_data_w) ) m
  ) (PipelinedAvalonMMHost #(t_byte_addr_w, t_data_w));
  // resources
  ////////////
  let w_h2a <- mkDWire (AvalonMMHost2Agent { address: ?
                                           , lock: ?
                                           // burstcount
                                           , read: False
                                           , write: False
                                           , byteenable: ?
                                           , writedata: ?
                                           });
  let h2a <- toSourceWithCredit (depth_proxy, m.req);
  let a2h <- toSinkWithCredit (depth_proxy, m.rsp);
  Wire #(AvalonMMAgent2Host #(t_data_w)) w_a2h <- mkBypassWire;

  // requests / host to agent signaling
  /////////////////////////////////////
  // can sample a request only if (1) there is one pending
  //                              (2) there is credit for it
  (* fire_when_enabled *)
  rule sample_consume_request (h2a.data.canPeek);
    w_h2a <= avalonMMReq2Host2Agent (h2a.data.peek);
    if (!w_a2h.waitrequest) h2a.data.drop;
  endrule

  // responses / agent to host signaling
  //////////////////////////////////////

  (* fire_when_enabled *)
  rule forward_response
    ((w_a2h.readdatavalid || w_a2h.writeresponsevalid) && a2h.data.canPut);
    a2h.data.put (avalonMMAgent2Host2Rsp (w_a2h));
  endrule

  // credits handling
  ///////////////////
  mkConnection (a2h.credit, h2a.credit);

  //////////////////////////////////////////////////////////////////////////////

  // PipelinedAvalonMMHost interface
  return interface PipelinedAvalonMMHost;
    method Bit #(t_byte_addr_w) address = w_h2a.address;
    method Bool read = w_h2a.read;
    method Bool write = w_h2a.write;
    method Bit #(TDiv #(t_data_w, 8)) byteenable = w_h2a.byteenable;
    method Bit #(t_data_w) writedata = w_h2a.writedata;
    method Bool lock = w_h2a.lock;
    method Action agent2host ( Bool waitrequest
                             , Bit #(2) response
                             , Bit #(t_data_w) readdata
                             , Bool readdatavalid
                             , Bool writeresponsevalid ) = action
      w_a2h <= AvalonMMAgent2Host { waitrequest: waitrequest
                                  , response: response
                                  , readdata: readdata
                                  , readdatavalid: readdatavalid
                                  , writeresponsevalid: writeresponsevalid };
    endaction;
  endinterface;

endmodule

module pipelinedAvalonMMHostTransactor #(
    parameter NumProxy #(t_depth) depth_proxy
  ) (Tuple2 #( Slave #( AvalonMMRequest #(t_byte_addr_w, t_data_w)
                      , AvalonMMResponse #(t_data_w) )
             , PipelinedAvalonMMHost #(t_byte_addr_w, t_data_w) ));
  let req_ff <- mkSizedFIFOF (valueOf (t_depth));
  let rsp_ff <- mkSizedFIFOF (valueOf (t_depth));
  let hostIfc <- toPipelinedAvalonMMHost ( depth_proxy
                                         , toMaster (req_ff, rsp_ff) );
  return tuple2 (toSlave (req_ff, rsp_ff), hostIfc);
endmodule

// Pipelined to agent
/////////////////////

module toPipelinedAvalonMMAgent #(
    parameter NumProxy #(t_depth) depth_proxy
  , Slave #( AvalonMMRequest #(t_byte_addr_w, t_data_w)
           , AvalonMMResponse #(t_data_w) ) s
  ) (PipelinedAvalonMMAgent #(t_byte_addr_w, t_data_w));
  let w_h2a <- mkDWire (AvalonMMHost2Agent { address: ?
                                           , lock: ?
                                           // burstcount
                                           , read: False
                                           , write: False
                                           , byteenable: ?
                                           , writedata: ?
                                           });
  let ff_req <- mkUGSizedFIFOF (valueOf (t_depth));
  let ff_rsp <- mkUGSizedFIFOF (valueOf (t_depth));
  mkConnection (toSource (ff_req), s.req);
  mkConnection (s.rsp, toSink (ff_rsp));
  let w_a2h <- mkDWire (AvalonMMAgent2Host { response: ?
                                           , readdata: ?
                                           , waitrequest: !ff_req.notFull
                                           , readdatavalid: False
                                           , writeresponsevalid: False
                                           });

  // requests / host to agent signaling
  /////////////////////////////////////
  (* fire_when_enabled, no_implicit_conditions *)
  rule accept_request (ff_req.notFull && (w_h2a.read || w_h2a.write));
    lvlPrint (2, $format ( "%m.toPipelinedAvalonMMAgent.accept_request - "
                         , "req: ", fshow (avalonMMHost2Agent2Req (w_h2a)) ));
    ff_req.enq (avalonMMHost2Agent2Req (w_h2a));
  endrule

  // responses / agent to host signaling
  //////////////////////////////////////
  (* fire_when_enabled, no_implicit_conditions *)
  rule forward_response (ff_rsp.notEmpty);
    lvlPrint (2, $format ( "%m.toPipelinedAvalonMMAgent.forward_response - "
                         , "ff_rsp.first: ", fshow (ff_rsp.first)
                         , ", ff_req.notFull: ", fshow (ff_req.notFull) ));
    AvalonMMResponse #(t_data_w) rsp = ff_rsp.first;
    ff_rsp.deq;
    w_a2h <= AvalonMMAgent2Host {
               response: rsp.response
             , readdata: rsp.operation.Read
             , waitrequest: !ff_req.notFull
             , readdatavalid:
                 rsp.operation matches tagged Read .* ? True : False
             , writeresponsevalid:
                 rsp.operation matches tagged Write ? True : False };
  endrule

  //////////////////////////////////////////////////////////////////////////////

  // PipelinedAvalonMMAgent interface
  return interface PipelinedAvalonMMAgent;
    method host2agent (address, read, write, byteenable, writedata, lock) =
      w_h2a._write (AvalonMMHost2Agent { address: address
                                       , lock: lock
                                       // burstcount
                                       , read: read
                                       , write: write
                                       , byteenable: byteenable
                                       , writedata: writedata
                                       });
    method waitrequest = w_a2h.waitrequest;
    method response = w_a2h.response;
    method readdata = w_a2h.readdata;
    method readdatavalid = w_a2h.readdatavalid;
    method writeresponsevalid = w_a2h.writeresponsevalid;
  endinterface;

endmodule

module pipelinedAvalonMMAgentTransactor #(
    parameter NumProxy #(t_depth) depth_proxy
  ) (Tuple2 #( Master #( AvalonMMRequest #(t_byte_addr_w, t_data_w)
                       , AvalonMMResponse #(t_data_w) )
             , PipelinedAvalonMMAgent #(t_byte_addr_w, t_data_w) ));
  let req_ff <- mkSizedFIFOF (valueOf (t_depth));
  let rsp_ff <- mkSizedFIFOF (valueOf (t_depth));
  let agentIfc <- toPipelinedAvalonMMAgent ( depth_proxy
                                           , toSlave (req_ff, rsp_ff) );
  return tuple2 (toMaster (req_ff, rsp_ff), agentIfc);
endmodule

endpackage
