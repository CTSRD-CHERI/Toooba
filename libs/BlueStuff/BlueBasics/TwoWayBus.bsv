/*-
 * Copyright (c) 2018-2022 Alexandre Joannou
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
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

package TwoWayBus;

export composeMWithInteger;
export wrapMaster_id;
export wrapMaster_WithIndex;
export wrapMaster_SingleReq;
export wrapSlave_id;
export wrapSlave_KeepRouteInfo;
export wrapSlave_HandleRouteBack;

export mkTwoWayBus;
export mkTwoWayBusNoRoute;
export mkUpDownSwitch;
export mkRelaxedTwoWayBus;
export mkRouteBackTwoWayBus;
export mkInOrderTwoWayBus;

import Routable    :: *;
import OneWayBus   :: *;
import SourceSink  :: *;
import MasterSlave :: *;

import FIFOF  :: *;
import Vector :: *;

// Master wrappers
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

function (function module #(c) _f_g (a _x, Integer _i))
         composeMWithInteger ( function module #(c) f (b _x, Integer _i)
                             , function module #(b) g (a _x, Integer _i) );
  module f_g #(a x, Integer i) (c);
    let xx <- g (x, i);
    let xxx <- f (xx, i);
    return xxx;
  endmodule
  return f_g;
endfunction

// Identity, no transformation
module wrapMaster_id #(Master #(req_t, rsp_t) m, Integer _idx)
                      (Master #(req_t, rsp_t));
  return m;
endmodule

// - augments requests with the master's index on the bus for later route
//   back using the WithMetaInfo type
// - extracts the response from the payload field in the WithRouteInfo type
//   used for inner responses
module wrapMaster_WithIndex #(Master #(req_t0, rsp_t0) m, Integer idx)
                             (Master #(req_t1, rsp_t1))
  provisos ( Alias #(req_t1, WithMetaInfo #(req_t0, Bit #(n)))
           , Has_payload #(rsp_t1, rsp_t0) );
  function req_t1 toReq1 (req_t0 r) =
    WithMetaInfo { payload: r, metaInfo: fromInteger (idx) };
  function rsp_t0 fromRsp1 (rsp_t1 r) = payload (r);
  interface req = mapSource (toReq1, m.req);
  interface rsp = mapSink   (fromRsp1, m.rsp);
endmodule

// guarantee that no more than a single request is consumed from the master at a
// time. THIS DOES NOT SUPPORT BURSTS
module wrapMaster_SingleReq #(Master #(req_t, rsp_t) m, Integer idx)
                             (Master #(req_t, rsp_t));
  FIFOF #(Bit #(0)) ff <- mkFIFOF1;
  interface req = onDrop (constFn (ff.enq (?)), m.req);
  interface rsp =  onPut (constFn (ff.deq)    , m.rsp);
endmodule

// Slave wrappers
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

// no transformation on slaves
module wrapSlave_id #(Slave #(req_t, rsp_t) s) (Slave #(req_t, rsp_t));
  return s;
endmodule

// This slave wrapper preserves the onformation necessary to route a response
// back in the types accessible to the slave:
// - creates the fat request out of the information in the WithMetaInfo
//   request received from the Master using the expand method
// - prepares the inner response from the Slave's response into a
//   WithRouteInfo using the shrink method
module wrapSlave_KeepRouteInfo #(Slave #(req_t0, rsp_t0) s)
                                (Slave #(req_t1, rsp_t1))
  provisos ( ExpandableReqRsp #(req_t, req_t0, rsp_t0, rsp_t, n)
           , Alias #(req_t1,  WithMetaInfo #(req_t, Bit #(TLog #(n))))
           , Alias #(rsp_t1, WithRouteInfo #(rsp_t, Bit #(TLog #(n)))) );
  function req_t0 fromReq1 (req_t1 r) = expand (r.metaInfo, r.payload);
  function rsp_t1 toRsp1 (rsp_t0 r);
    match {.r_info, .rsp} = shrink (r);
    return WithRouteInfo { routeInfo: r_info, payload: rsp };
  endfunction
  interface req = mapSink   (fromReq1, s.req);
  interface rsp = mapSource (toRsp1, s.rsp);
endmodule

// This slave wrapper presents to the slave types that do not embed information
// necessary to route back a response. It instead preserve that information
// just outside the slave, and takes care of re wrapping responses. THIS WILL
// ONLY BEHAVE IF THE ACTUAL SLAVE DOES NOT REORDER TRANSACTIONS.
// - extract the routing information from the inner request and stash it in a
//   fifo while the vanilla request is being processed by the slave
// - dequeue the fifo and augment the vanilla slave response with the routing
//   information for the inner response
module wrapSlave_HandleRouteBack #(Slave #(req_t0, rsp_t0) s)
                                  (Slave #(req_t1, rsp_t1))
  provisos ( Alias #(req_t1,  WithMetaInfo #(req_t0, info_t))
           , Alias #(rsp_t1, WithRouteInfo #(rsp_t0, info_t))
           , Has_isLast #(req_t1)
           , Has_isLast #(rsp_t0)
           , Bits #(info_t, info_sz) );
  let ff <- mkUGFIFOF;
  let reqInfoSaved <- mkReg (False);
  let guardReq =
    s.req.canPut && (reqInfoSaved || (!reqInfoSaved && ff.notFull));
  let guardRsp = s.rsp.canPeek && ff.notEmpty;
  interface req = interface Sink;
    method canPut = guardReq;
    method put (x) if (guardReq) = action
      if (!reqInfoSaved) begin
        ff.enq (x.metaInfo);
        if (!isLast (x)) reqInfoSaved <= True;
      end
      if (isLast (x)) reqInfoSaved <= False;
      s.req.put (x.payload);
    endaction;
  endinterface;
  interface rsp = interface Source;
    method canPeek = guardRsp;
    method peek if (guardRsp) = WithRouteInfo { routeInfo: ff.first
                                              , payload: s.rsp.peek };
    method drop if (guardRsp) = action
      s.rsp.drop;
      if (isLast (s.rsp.peek)) ff.deq;
    endaction;
  endinterface;
endmodule

/////////////////
// Two-Way Bus //
////////////////////////////////////////////////////////////////////////////////
// A two-way bus connects masters and slaves by using two one-way buses, one to
// route requests from masters to slaves, and one to route responses from slaves
// to masters.
// A default "no route" slave is targeted in the case routing does not identify
// a valid target slave.
// This module offers the user the ability to provide wrapper modules functions
// which will be mapped on the collections of masters and slaves. This allows
// for construction of buses with more subtle behaviours (see mkRelaxedTwoWayBus
// and mkRouteBackTwoWayBus for example)

module mkTwoWayBus #(
  function Vector #(nSlvs, Bool)  routeUp    (r_up_t x)
, function Vector #(nMsts, Bool)  routeDown  (r_down_t x)
, slave_t                         noRouteSlv
, function module #(inner_master) wrapMaster (master_t m, Integer idx)
, function module #(inner_slave)  wrapSlave  (slave_t s)
, Vector #(nMsts, master_t)       ms
, Vector #(nSlvs,  slave_t)       ss
) (Empty) provisos (
  Alias #(master_t,     Master #(req_t,     rsp_t))
, Alias #(inner_master, Master #(inner_req, inner_rsp))
, Alias #(inner_slave,  Slave  #(inner_req, inner_rsp))
, Alias #(slave_t,      Slave  #(req_fat_t, rsp_fat_t))
, Bits #(inner_req, inner_req_sz), Bits #(inner_rsp, inner_rsp_sz)
, Routable #(inner_req, r_up_t)
, Routable #(inner_rsp, r_down_t)
  // assertion on argument sizes
, Add #(1, _a, nMsts) // at least one Master is needed
, Add #(1, _b, nSlvs) // at least one slave is needed
);

  let innerMasters    <- zipWithM  (wrapMaster, ms, genVector);
  let innerSlaves     <- mapM      (wrapSlave, ss);
  let innerNoRouteSlv <- wrapSlave (noRouteSlv);

  // Requests bus, from Master to Slave
  //////////////////////////////////////////////////////////////////////////////
  mkOneWayBusNoRoute ( routeUp
                     , getSlaveReqIfc (innerNoRouteSlv)
                     , map (getMasterReqIfc, innerMasters)
                     , map (getSlaveReqIfc, innerSlaves));

  // Responses bus, from Slave to Master
  //////////////////////////////////////////////////////////////////////////////
  mkOneWayBus ( routeDown
              , map (getSlaveRspIfc, cons (innerNoRouteSlv, innerSlaves))
              , map (getMasterRspIfc, innerMasters));

endmodule

module mkTwoWayBusNoRoute #(
  function Vector #(nSlvs, Bool)  routeUp    (r_up_t x)
, function Vector #(nMsts, Bool)  routeDown  (r_down_t x)
, function module #(inner_master) wrapMaster (master_t m ,Integer idx)
, function module #(inner_slave)  wrapSlave  (slave_t s)
, Vector #(nMsts, master_t)       ms
, Vector #(nSlvs,  slave_t)       ss
) (Empty) provisos (
  Alias #(master_t,     Master #(req_t,     rsp_t))
, Alias #(inner_master, Master #(inner_req, inner_rsp))
, Alias #(inner_slave,  Slave  #(inner_req, inner_rsp))
, Alias #(slave_t,      Slave  #(req_fat_t, rsp_fat_t))
, Bits #(inner_req, inner_req_sz), Bits #(inner_rsp, inner_rsp_sz)
, Routable #(inner_req, r_up_t)
, Routable #(inner_rsp, r_down_t)
, FallibleRoute #(req_fat_t, rsp_fat_t)
  // assertion on argument sizes
, Add #(1, _a, nMsts) // at least one Master is needed
, Add #(1, _b, nSlvs) // at least one slave is needed
);
  // no route slave
  let noRouteSlv <- mkNoRouteSlave;
  // inner core bus
  mkTwoWayBus (routeUp, routeDown, noRouteSlv, wrapMaster, wrapSlave, ms, ss);
endmodule

////////////////////
// Up/Down switch //
////////////////////////////////////////////////////////////////////////////////
// A simple module routing traffic up from masters to slaves and back down from
// slaves to masters

module mkUpDownSwitch #(
  function Vector #(nSlvs, Bool)  routeUp    (r_up_t x)
, function Vector #(nMsts, Bool)  routeDown  (r_down_t x)
, Vector #(nMsts, Master #(req_t, rsp_t)) ms
, Vector #(nSlvs, Slave  #(req_t, rsp_t)) ss
) (Empty) provisos (
  Bits #(req_t, req_sz), Bits #(rsp_t, rsp_sz)
, Routable #(req_t, r_up_t)
, Routable #(rsp_t, r_down_t)
, FallibleRoute #(req_t, rsp_t)
  // assertion on argument sizes
, Add #(1, _a, nMsts) // at least one Master is needed
, Add #(1, _b, nSlvs) // at least one slave is needed
);
  // inner core bus
  mkTwoWayBusNoRoute (routeUp, routeDown, wrapMaster_id, wrapSlave_id, ms, ss);
endmodule

/////////////////////////
// Relaxed Two-Way Bus //
////////////////////////////////////////////////////////////////////////////////
// A "relaxed" two-way bus is a simple two-way bus which takes care of wrapping
// the masters and slaves in appropriate calls to 'expend' on masters' requests
// and 'shrink' on slave responses (for requests and response types related by
// the ExpandableReqRsp typeclass)

module mkRelaxedTwoWayBus #( function Vector #(n_slaves, Bool) route (r_up_t x)
                           , Vector #(n_masters, master_t) ms
                           , Vector #(n_slaves,  slave_t) ss ) (Empty)
  provisos (
    Bits #(req_t, req_sz), Bits #(rsp_t, rsp_sz)
  , Bits #(req_fat_t, req_fat_sz), Bits #(rsp_fat_t, rsp_fat_sz)
  , Routable #(inner_req, r_up_t)
  , Routable #(inner_rsp, r_down_t)
  , FallibleRoute #(req_fat_t, rsp_fat_t)
  , ExpandableReqRsp #(req_t, req_fat_t, rsp_fat_t, rsp_t, n_masters)
    // type aliases
  , Alias #(inner_req, WithMetaInfo  #(req_t, r_down_t))
  , Alias #(inner_rsp, WithRouteInfo #(rsp_t, r_down_t))
  , Alias #(master_t,  Master #(req_t,     rsp_t))
  , Alias #(slave_t,   Slave  #(req_fat_t, rsp_fat_t))
    // assertion on argument sizes
  , Add #(1, _a, n_masters) // at least one Master is needed
  , Add #(1, _b, n_slaves)  // at least one slave is needed
  );

  // Call underlying general 'mkTwoWayBus' constructor
  //////////////////////////////////////////////////////////////////////////////
  mkTwoWayBusNoRoute ( route, indexToOneHot
                     , wrapMaster_WithIndex, wrapSlave_KeepRouteInfo
                     , ms, ss );

endmodule

///////////////////////////
// RouteBack Two-Way Bus //
////////////////////////////////////////////////////////////////////////////////
// An "route-back" two-way bus is a two-way bus which keeps the request and
// response types simple for the slaves by extracting route-back information
// from the requests and enqueuing it in a FIFO for each slave.
// /!\ Slaves must not reorder responses /!\

module mkRouteBackTwoWayBus #(
    function Vector #(n_slaves, Bool) route (r_up_t x)
  , Vector #(n_masters, master_t) ms
  , Vector #(n_slaves,  slave_t) ss
  ) (Empty)
  provisos (
    Bits #(req_t, req_sz), Bits #(rsp_t, rsp_sz)
  , Routable #(req_t, r_up_t)
  , Has_isLast #(rsp_t)
  , FallibleRoute #(req_t, rsp_t)
    // type aliases
  , Alias #(master_t, Master #(req_t, rsp_t))
  , Alias #(slave_t,   Slave #(req_t, rsp_t))
    // assertion on argument sizes
  , Add #(1, a__, n_masters) // at least one Master is needed
  , Add #(1, b__, n_slaves)  // at least one slave is needed
  );

  // Call underlying general 'mkTwoWayBus' constructor
  //////////////////////////////////////////////////////////////////////////////
  mkTwoWayBusNoRoute ( route, indexToOneHot
                     , wrapMaster_WithIndex, wrapSlave_HandleRouteBack
                     , ms, ss );

endmodule

///////////////////////////
// In-order Two-Way Bus //
////////////////////////////////////////////////////////////////////////////////
// An "in-order" two-way bus is a two-way bus which returns the response for the
// requests sent by a master in the same order.

module mkInOrderTwoWayBus #(
    function Vector #(n_slaves, Bool) route (r_up_t x)
  , Vector #(n_masters, master_t) ms
  , Vector #(n_slaves,  slave_t) ss
  ) (Empty)
  provisos (
    Bits #(req_t, req_sz), Bits #(rsp_t, rsp_sz)
  , Routable #(req_t, r_up_t)
  , Routable #(rsp_t, Bit #(TLog #(n_masters)))
  , FallibleRoute #(req_t, rsp_t)
    // type aliases
  , Alias #(master_t, Master #(req_t, rsp_t))
  , Alias #(slave_t,   Slave #(req_t, rsp_t))
    // assertion on argument sizes
  , Add #(1, a__, n_masters) // at least one Master is needed
  , Add #(1, b__, n_slaves)  // at least one slave is needed
  );

  // Call underlying general 'mkTwoWayBus' constructor
  //////////////////////////////////////////////////////////////////////////////
  mkTwoWayBusNoRoute ( route, indexToOneHot
                     , wrapMaster_SingleReq, wrapSlave_id
                     , ms, ss );

endmodule

endpackage
