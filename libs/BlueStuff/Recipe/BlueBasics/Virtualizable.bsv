/*-
 * Copyright (c) 2018-2019 Alexandre Joannou
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

// This package provides a Virtualizable typeclass which provides a mean to turn
// a virtualizable interface into an array of "n" virtualized interfaces to a
// provided instance via a call to the 'virtualize' method.
// It also provides Virtualizable instances for:
// * Reg #(t)
// * Server #(req_t, rsp_t)
// * Slave #(req_t, rsp_t)
//
// A 'NeedRsp' typeclass is also defined to help implement instances of
// Virtualizable for types which may pair requests and responses such as Server
// and Slave. A call to the 'needRsp' method on a request will return whether
// the virtualized interfaces are expected to produce a coresponding response or
// not.

package Virtualizable;

import FIFO         :: *;
import FIFOF        :: *;
import GetPut       :: *;
import Printf       :: *;
import SourceSink   :: *;
import MasterSlave  :: *;
import ClientServer :: *;
import SpecialFIFOs :: *;

// typeclass definitions
////////////////////////////////////////////////////////////////////////////////

// Virtualizable class
//////////////////////
typeclass Virtualizable #(type t);
  // receive an instance of an interface and an integer 'n' and return an array
  // of 'n' virtualized interfaces to the provided interface instance
  module virtualize #(t x, Integer n)(Array #(t));
endtypeclass

// NeedRsp class
////////////////
typeclass NeedRsp #(type req_t);
  // receive a request and returns "True" if it expects a corresponding response
  function Bool needRsp (req_t req);
endtypeclass

// typeclass instances
////////////////////////////////////////////////////////////////////////////////

// NeedRsp instance for 'Either #(a, b)'
// XXX Always expect a response...
instance NeedRsp #(Either #(a, b));
  function needRsp (_) = True;
endinstance

// Virtualizable instance for 'Reg #(t)'.
// Reads all read the register's value.
// Writes are statically prioritized, with lower interface indices having
// priority over higher indices (this is _not_ a 'CReg').
////////////////////////////////////////////////////////////////////////////////

instance Virtualizable #(Reg #(t)) provisos (Bits #(t, _a));

  module virtualize #(Reg #(t) r, Integer n) (Array #(Reg #(t)));

    Reg #(t) ifc[n];
    Rules ifcRules = emptyRules;

    for (Integer i = 0; i < n; i = i + 1) begin
      Wire #(t) wWrite <- mkWire;
      ifcRules = rJoinDescendingUrgency (ifcRules, rules
        rule doWrite; r <= wWrite; endrule
      endrules);
      ifc[i] = interface Reg;
        method _read = r._read;
        method _write = wWrite._write;
      endinterface;
    end

    addRules (ifcRules);

    return ifc;

  endmodule

endinstance

// Virtualizable instance for Server
// Per virtualized interface pairs of bypass FIFOs for requests and responses,
// and a gloval "virtualized interface index" FIFO to route responses back from
// the concrete interface to the appropriate virtualized interface (requests
// which do not expect a response do not participate in this).
// Requests are statically prioritized, with lower interface indices having
// priority over higher indices.
////////////////////////////////////////////////////////////////////////////////

instance Virtualizable #(Server#(req_t, rsp_t))
  provisos (NeedRsp #(req_t), Bits #(req_t, _a), Bits #(rsp_t, _b));

  module virtualize #(Server #(req_t, rsp_t) server, Integer n)
                     (Array #(Server #(req_t, rsp_t)));

    `define MAX_IDX_SZ 4
    if (log2 (n) > `MAX_IDX_SZ)
      error (sprintf ( "Asked for %0d interfaces, virtualize for Server can't "
                     + "support more than %0d", n, 2**`MAX_IDX_SZ));

    Server #(req_t, rsp_t) ifc[n];
    FIFO #(Bit #(`MAX_IDX_SZ)) ifcIdx <- mkFIFO;
    Rules ifcRules = emptyRules;

    for (Integer i = 0; i < n; i = i + 1) begin
      let reqFF <- mkBypassFIFO;
      let rspFF <- mkBypassFIFO;
      ifcRules = rJoinDescendingUrgency (ifcRules, rules
        rule doSendReq;
          reqFF.deq;
          let req = reqFF.first;
          server.request.put (req);
          if (needRsp (req)) ifcIdx.enq (fromInteger (i));
        endrule
        rule doGetRsp (ifcIdx.first == fromInteger (i));
          ifcIdx.deq;
          let rsp <- server.response.get;
          rspFF.enq (rsp);
        endrule
      endrules);
      ifc[i] = interface Server;
        interface  request = toPut (reqFF);
        interface response = toGet (rspFF);
      endinterface;
    end

    addRules(ifcRules);

    return ifc;

  endmodule
endinstance

// Virtualizable instance for Slave
// Per virtualized interface pairs of bypass FIFOs for requests and responses,
// and a gloval "virtualized interface index" FIFO to route responses back from
// the concrete interface to the appropriate virtualized interface (requests
// which do not expect a response do not participate in this).
// Requests are statically prioritized, with lower interface indices having
// priority over higher indices.
////////////////////////////////////////////////////////////////////////////////

instance Virtualizable #(Slave #(req_t, rsp_t))
  provisos (NeedRsp #(req_t), Bits #(req_t, a__), Bits #(rsp_t, b__));

  module virtualize #(Slave #(req_t, rsp_t) slave, Integer n)
                     (Array #(Slave #(req_t, rsp_t)));

    `define MAX_IDX_SZ 4
    if (log2 (n) > `MAX_IDX_SZ)
      error (sprintf ( "Asked for %0d interfaces, virtualize for Slave can't "
                     + "support more than %0d", n, 2**`MAX_IDX_SZ));

    Slave #(req_t, rsp_t) ifc[n];
    FIFO #(Bit #(`MAX_IDX_SZ)) ifcIdx <- mkFIFO;
    Rules ifcRules = emptyRules;

    for (Integer i = 0; i < n; i = i + 1) begin
      let reqFF <- mkBypassFIFOF;
      let rspFF <- mkBypassFIFOF;
      ifcRules = rJoinDescendingUrgency (ifcRules, rules
        rule doSendReq;
          reqFF.deq;
          let x = reqFF.first;
          slave.req.put (x);
          if (needRsp (x)) ifcIdx.enq (fromInteger (i));
        endrule
        rule doGetRsp (ifcIdx.first == fromInteger (i));
          ifcIdx.deq;
          let x <- get (slave.rsp);
          rspFF.enq (x);
        endrule
      endrules);
      ifc[i] = interface Slave;
        interface req = toSink (reqFF);
        interface rsp = toSource (rspFF);
      endinterface;
    end

    addRules (ifcRules);

    return ifc;

  endmodule
endinstance

endpackage
