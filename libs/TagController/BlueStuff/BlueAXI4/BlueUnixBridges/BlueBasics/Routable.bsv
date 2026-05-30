/*-
 * Copyright (c) 2018-2020 Alexandre Joannou
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

package Routable;

import Vector :: *;

import MasterSlave :: *;

//////////////////////
// Routable classes //
////////////////////////////////////////////////////////////////////////////////

// The Routable class provides methods to help routing a flit type through some
// interconnect logic. The routingField method extracts a field of the flit to
// be used as an argument to a separate routing function. Additionally, the
// isLast method identifies a flit as the last of a (possibly multi-flit)
// packet. It is useful to help keep track of state needed for packet switching
// logic.

typeclass Has_routingField #(type t, type r_t) dependencies (t determines r_t);
  function r_t routingField (t x);
endtypeclass

typeclass Has_isLast #(type t);
  function Bool isLast (t x);
endtypeclass

typeclass Routable #(type f_t, type r_t)
  provisos ( Has_routingField #(f_t, r_t)
           , Has_isLast #(f_t))
  dependencies (f_t determines r_t);
endtypeclass

instance Routable #(a, b) provisos (Has_routingField #(a, b), Has_isLast #(a));
endinstance

/////////////////////////
// FallibleRoute class //
////////////////////////////////////////////////////////////////////////////////

// The FallibleRoute class provides a mkNoRouteSlave module for a pair of
// request and response type. It will usually get any relevant metadata from
// the request that needs to be forwarded and send a response containing this
// information and a routing error code.

typeclass FallibleRoute #(type req_t, type rsp_t);
  module mkNoRouteSlave (Slave #(req_t, rsp_t));
endtypeclass

////////////////////////////
// ExpandableReqRsp class //
////////////////////////////////////////////////////////////////////////////////

// The ExpandableReqRsp class provides methods to enrich flits with information
// that interconnect logic uses when performing two-way request-response
// transfers. The request flits will typically be augmented with information
// identifying the original source of the packet (using the expand method).
// This information is mirrored in the enriched response flit which can then
// get trimmed (using the shrink method) to retrieve the information in order
// to target the original source of the request when routing the response back.

typeclass ExpandableReqRsp #( type req_t,     type req_fat_t
                            , type rsp_fat_t, type rsp_t
                            , numeric type n_masters)
  dependencies ( (req_t, req_fat_t) determines (rsp_t, rsp_fat_t, n_masters)
               , rsp_fat_t determines (rsp_t, n_masters, req_t, req_fat_t)
               , (rsp_t, rsp_fat_t) determines (req_t, req_fat_t, n_masters));
  function req_fat_t expand (Bit #(TLog #(n_masters)) x, req_t r);
  function Tuple2 #(Bit #(TLog #(n_masters)), rsp_t) shrink (rsp_fat_t r);
endtypeclass

///////////////////
// route helpers //
////////////////////////////////////////////////////////////////////////////////

// The WithRouteInfo type wraps any type with information that will be used to
// be routed with. If the wrapped type has an implementation of "isLast", this
// implementation is used for WithRouteInfo 's isLast.
// XXX Note that if the wrapped type has an implementation of "routingField",
// it is ignored and WithRouteInfo's routeInfo field is used instead.
typedef struct {
  t   payload;
  r_t routeInfo;
} WithRouteInfo #(type t, type r_t) deriving (FShow, Bits);
instance Has_routingField #(WithRouteInfo #(t, r_t), r_t);
  function routingField (x) = x.routeInfo;
endinstance
instance Has_isLast #(WithRouteInfo #(t, r_t)) provisos (Has_isLast #(t));
  function isLast (x) = isLast (x.payload);
endinstance

// The WithMetaInfo type wraps a type with meta information and uses the
// wrapped type's implementation of "routingField" and "isLast"
typedef struct {
  t   payload;
  m_t metaInfo;
} WithMetaInfo #(type t, type m_t) deriving (FShow, Bits);
instance Has_routingField #(WithMetaInfo #(t, m_t), r_t)
  provisos (Has_routingField #(t, r_t));
  function routingField (x) = routingField (x.payload);
endinstance
instance Has_isLast #(WithMetaInfo #(t, m_t)) provisos (Has_isLast #(t));
  function isLast (x) = isLast (x.payload);
endinstance

// Routing function from index to one hot vector
// XXX Note: special case for idx type of Bit #(0) as it does not seam to yield
// the naively expected behaviour of a singleton vector with True in it
function Vector #(n, Bool) indexToOneHot (Bit #(TLog #(n)) idx) =
  (valueOf (n) == 1) ? replicate (True) : unpack (1 << idx);

// Range type to help represent memory ranges and describe a memory map that
// can be used to help derive a routing function. The Range type consists of
// a base and a size and function to queries those as well as the range top,
// and whether an address is in the range or not
typedef struct {
  Bit #(n) base;
  Bit #(n) size;
} Range #(numeric type n) deriving (Bits);
function Bit #(n) rangeBase (Range #(n) rg) = rg.base;
function Bit #(n) rangeSize (Range #(n) rg) = rg.size;
function Bit #(n) rangeTop  (Range #(n) rg) = rg.base + rg.size;
function Bool inRange (Range #(n) rg, Bit #(n) addr) =
  (addr >= rangeBase (rg) && (addr - rangeBase (rg)) < rangeSize (rg));

// A mapping table is a collection of ranges. The routeFromMappingTable
// function takes a mapping table and return a function from address to one hot
// vector that can be used as a routing function for an interconnect.
typedef Vector #(n, Range #(a)) MappingTable #(numeric type n, numeric type a);
function Vector #(n, Bool) routeFromMappingTable ( MappingTable #(n, a) mt
                                                 , Bit #(a) addr);
  function pred = flip (inRange);
  let route = replicate (False);
  let mIdx = findIndex (pred (addr), mt);
  if (isValid (mIdx)) route[mIdx.Valid] = True;
  return route;
endfunction

endpackage
