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
interface Master #(type req_t, type rsp_t);
  interface Source #(req_t) req;
  interface Sink   #(rsp_t) rsp;
endinterface

// A 'Slave' is a sink for requests and a source of responses
interface Slave #(type req_t, type rsp_t);
  interface Sink   #(req_t) req;
  interface Source #(rsp_t) rsp;
endinterface

///////////////////////////
// Connectable instances //
////////////////////////////////////////////////////////////////////////////////
// Simply connect a 'Master' 's request source to a 'Slave' 's request sink,
// and a 'Slave' 's response source to a 'Master' 's response sink

instance Connectable #(Master #(req_t, rsp_t), Slave #(req_t, rsp_t))
  provisos (Bits #(req_t, _a), Bits #(rsp_t, _b));
  module mkConnection #(Master #(req_t, rsp_t) m, Slave #(req_t, rsp_t) s)
                       (Empty);
    mkConnection (m.req, s.req);
    mkConnection (m.rsp, s.rsp);
  endmodule
endinstance

instance Connectable #(Slave #(req_t, rsp_t), Master #(req_t, rsp_t))
  provisos (Bits #(req_t, _a), Bits #(rsp_t, _b));
  module mkConnection #(Slave #(req_t, rsp_t) s, Master #(req_t, rsp_t) m)
                       (Empty);
    mkConnection (s.req, m.req);
    mkConnection (s.rsp, m.rsp);
  endmodule
endinstance

///////////
// Debug //
////////////////////////////////////////////////////////////////////////////////
// simple debug utilities using the underlying 'debugSource' and 'debugSink'
// functions which print provided messages on source drop / sink put

function Master #(req_t, rsp_t) debugMaster (Master #(req_t, rsp_t) m, Fmt msg)
  provisos (FShow #(req_t), FShow #(rsp_t)) = interface Master;
    interface req = debugSource (m.req, msg);
    interface rsp = debugSink   (m.rsp, msg);
  endinterface;

function Slave #(req_t, rsp_t) debugSlave (Slave #(req_t, rsp_t) s, Fmt msg)
  provisos (FShow #(req_t), FShow #(rsp_t)) = interface Slave;
    interface req = debugSink   (s.req, msg);
    interface rsp = debugSource (s.rsp, msg);
  endinterface;

///////////
// Utils //
////////////////////////////////////////////////////////////////////////////////
// Get desired Master / Slave sub-interface

function Source #(req_t) getMasterReqIfc (Master #(req_t, _a) m) = m.req;
function Sink   #(rsp_t) getMasterRspIfc (Master #(_a, rsp_t) m) = m.rsp;
function Sink   #(req_t) getSlaveReqIfc  (Slave #(req_t, _a) s)  = s.req;
function Source #(rsp_t) getSlaveRspIfc  (Slave #(_a, rsp_t) s)  = s.rsp;

endpackage
