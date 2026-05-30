/*-
 * Copyright (c) 2018-2023 Alexandre Joannou
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

// This package provides a 'Master' and a 'Slave' interface, similar to the
// 'Client' and 'Server' interfaces from the standard Bluespec library, but
// using 'Source' and 'Sink' in place of the standard 'Get' and 'Put' underlying
// interfaces (e.g. 'Master' and 'Slave' offer explicit flow control methods).

package MasterSlave;

import SourceSink :: *;
import Connectable :: *;

///////////////////////////////
// Master / Slave interfaces //
////////////////////////////////////////////////////////////////////////////////

// A 'Master' is a source of requests and a sink for responses
interface Master #(type t_req, type t_rsp);
  interface Source #(t_req) req;
  interface Sink   #(t_rsp) rsp;
endinterface

// A 'Slave' is a sink for requests and a source of responses
interface Slave #(type t_req, type t_rsp);
  interface Sink   #(t_req) req;
  interface Source #(t_rsp) rsp;
endinterface

// constructors
function Master #(a, b) toMaster (src_a src, snk_b snk)
  provisos (ToSource #(src_a, a), ToSink #(snk_b, b)) = interface Master;
  interface req = toSource (src);
  interface rsp = toSink (snk);
endinterface;
function Slave #(a, b) toSlave (snk_a snk, src_b src)
  provisos (ToSink #(snk_a, a), ToSource #(src_b, b)) = interface Slave;
  interface req = toSink (snk);
  interface rsp = toSource (src);
endinterface;

///////////////////////////
// Connectable instances //
////////////////////////////////////////////////////////////////////////////////
// Simply connect a 'Master' 's request source to a 'Slave' 's request sink,
// and a 'Slave' 's response source to a 'Master' 's response sink

instance Connectable #(Master #(t_req, t_rsp), Slave #(t_req, t_rsp))
  provisos (Bits #(t_req, _a), Bits #(t_rsp, _b));
  module mkConnection #(Master #(t_req, t_rsp) m, Slave #(t_req, t_rsp) s)
                       (Empty);
    mkConnection (m.req, s.req);
    mkConnection (m.rsp, s.rsp);
  endmodule
endinstance

instance Connectable #(Slave #(t_req, t_rsp), Master #(t_req, t_rsp))
  provisos (Bits #(t_req, _a), Bits #(t_rsp, _b));
  module mkConnection #(Slave #(t_req, t_rsp) s, Master #(t_req, t_rsp) m)
                       (Empty);
    mkConnection (s.req, m.req);
    mkConnection (s.rsp, m.rsp);
  endmodule
endinstance

instance Connectable #( Master #(t_req, t_rsp)
                      , Tuple2 #(Sink #(t_req), Source #(t_rsp)) )
  provisos (Bits #(t_req, _a), Bits #(t_rsp, _b));
  module mkConnection #( Master #(t_req, t_rsp) m
                       , Tuple2 #(Sink #(t_req), Source #(t_rsp)) t )
                       (Empty);
    mkConnection (m.req, tpl_1 (t));
    mkConnection (m.rsp, tpl_2 (t));
  endmodule
endinstance

instance Connectable #( Tuple2 #(Sink #(t_req), Source #(t_rsp))
                      , Master #(t_req, t_rsp) )
  provisos (Bits #(t_req, _a), Bits #(t_rsp, _b));
  module mkConnection #( Tuple2 #(Sink #(t_req), Source #(t_rsp)) t
                       , Master #(t_req, t_rsp) m )
                       (Empty);
    mkConnection (tpl_1 (t), m.req);
    mkConnection (tpl_2 (t), m.rsp);
  endmodule
endinstance

instance Connectable #( Tuple2 #(Source #(t_req), Sink #(t_rsp))
                      , Slave #(t_req, t_rsp) )
  provisos (Bits #(t_req, _a), Bits #(t_rsp, _b));
  module mkConnection #( Tuple2 #(Source #(t_req), Sink #(t_rsp)) t
                       , Slave #(t_req, t_rsp) s )
                       (Empty);
    mkConnection (tpl_1 (t), s.req);
    mkConnection (tpl_2 (t), s.rsp);
  endmodule
endinstance

instance Connectable #( Slave #(t_req, t_rsp)
                      , Tuple2 #(Source #(t_req), Sink #(t_rsp)) )
  provisos (Bits #(t_req, _a), Bits #(t_rsp, _b));
  module mkConnection #( Slave #(t_req, t_rsp) s
                       , Tuple2 #(Source #(t_req), Sink #(t_rsp)) t )
                       (Empty);
    mkConnection (tpl_1 (t), s.req);
    mkConnection (tpl_2 (t), s.rsp);
  endmodule
endinstance

///////////
// Debug //
////////////////////////////////////////////////////////////////////////////////
// simple debug utilities using the underlying 'debugSource' and 'debugSink'
// functions which print provided messages on source drop / sink put

function Master #(t_req, t_rsp) conditionalDebugMaster
  (Bool p, Master #(t_req, t_rsp) m, Fmt msg)
  provisos (FShow #(t_req), FShow #(t_rsp)) = interface Master;
    interface req = conditionalDebugSource (p, m.req, msg);
    interface rsp = conditionalDebugSink   (p, m.rsp, msg);
  endinterface;

function Master #(t_req, t_rsp) debugMaster (Master #(t_req, t_rsp) m, Fmt msg)
  provisos (FShow #(t_req), FShow #(t_rsp)) =
  conditionalDebugMaster (True, m, msg);

function Slave #(t_req, t_rsp) conditionalDebugSlave
  (Bool p, Slave #(t_req, t_rsp) s, Fmt msg)
  provisos (FShow #(t_req), FShow #(t_rsp)) = interface Slave;
    interface req = conditionalDebugSink   (p, s.req, msg);
    interface rsp = conditionalDebugSource (p, s.rsp, msg);
  endinterface;

function Slave #(t_req, t_rsp) debugSlave (Slave #(t_req, t_rsp) s, Fmt msg)
  provisos (FShow #(t_req), FShow #(t_rsp)) =
  conditionalDebugSlave (True, s, msg);

///////////
// Utils //
////////////////////////////////////////////////////////////////////////////////
// Get desired Master / Slave sub-interface

function Source #(t_req) getMasterReqIfc (Master #(t_req, t) m) = m.req;
function Sink   #(t_rsp) getMasterRspIfc (Master #(t, t_rsp) m) = m.rsp;
function Sink   #(t_req) getSlaveReqIfc  (Slave #(t_req, t) s)  = s.req;
function Source #(t_rsp) getSlaveRspIfc  (Slave #(t, t_rsp) s)  = s.rsp;

function Master #(res_req, res_rsp) mapMaster ( function res_req fReq (req r)
                                              , function rsp fRsp (res_rsp r)
                                              , Master #(req, rsp) m ) =
  interface Master;
    interface req = mapSource (fReq, m.req);
    interface rsp = mapSink (fRsp, m.rsp);
  endinterface;

function Slave #(res_req, res_rsp) mapSlave ( function req fReq (res_req r)
                                            , function res_rsp fRsp (rsp r)
                                            , Slave #(req, rsp) s ) =
  interface Slave;
    interface req = mapSink (fReq, s.req);
    interface rsp = mapSource (fRsp, s.rsp);
  endinterface;

endpackage
