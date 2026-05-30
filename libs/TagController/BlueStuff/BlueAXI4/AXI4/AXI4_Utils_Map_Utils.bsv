/*-
 * Copyright (c) 2018-2022 Alexandre Joannou
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

// AXI4 imports
import AXI4_Types :: *;
import AXI4_Channels_Utils :: *;

// BlueStuff import
import BlueBasics :: *;

////////////////////////
// AXI4 map utilities //
////////////////////////////////////////////////////////////////////////////////

function AXI4_Master #(id_out, b, c, d, e, f, g, h)
  mapAXI4_Master_id ( function Bit #(id_out) fReq (Bit #(id_in)  x)
                    , function Bit #(id_in)  fRsp (Bit #(id_out) x)
                    , AXI4_Master #(id_in, b, c, d, e, f, g, h) m) =
  interface AXI4_Master;
    interface aw = mapSource (mapAXI4_AWFlit_awid (fReq), m.aw);
    interface  w = m.w;
    interface  b = mapSink   (mapAXI4_BFlit_bid   (fRsp), m.b);
    interface ar = mapSource (mapAXI4_ARFlit_arid (fReq), m.ar);
    interface  r = mapSink   (mapAXI4_RFlit_rid   (fRsp), m.r);
  endinterface;

function AXI4_Master #(a, addr_out, c, d, e, f, g, h)
  mapAXI4_Master_addr ( function Bit #(addr_out) fun (Bit #(addr_in) x)
                      , AXI4_Master #(a, addr_in, c, d, e, f, g, h)  m) =
  interface AXI4_Master;
    interface aw = mapSource (mapAXI4_AWFlit_awaddr (fun), m.aw);
    interface  w = m.w;
    interface  b = m.b;
    interface ar = mapSource (mapAXI4_ARFlit_araddr (fun), m.ar);
    interface  r = m.r;
  endinterface;

function AXI4_Master #(a, b, c, d_, e_, f_, g_, h_)
  mapAXI4_Master_user ( function Bit #(d_) fAW (Bit #(d)  x)
                      , function Bit #(e_) fW  (Bit #(e)  x)
                      , function Bit #(f)  fB  (Bit #(f_) x)
                      , function Bit #(g_) fAR (Bit #(g)  x)
                      , function Bit #(h)  fR  (Bit #(h_) x)
                      , AXI4_Master #(a, b, c, d, e, f, g, h) m) =
  interface AXI4_Master;
    interface aw = mapSource (mapAXI4_AWFlit_awuser (fAW), m.aw);
    interface  w = mapSource (mapAXI4_WFlit_wuser   (fW), m.w);
    interface  b = mapSink   (mapAXI4_BFlit_buser   (fB), m.b);
    interface ar = mapSource (mapAXI4_ARFlit_aruser (fAR), m.ar);
    interface  r = mapSink   (mapAXI4_RFlit_ruser   (fR), m.r);
  endinterface;

//------------------------------------------------------------------------------

function AXI4_Slave #(id_in, b, c, d, e, f, g, h)
  mapAXI4_Slave_id ( function Bit #(id_out) fReq (Bit #(id_in)  x)
                   , function Bit #(id_in)  fRsp (Bit #(id_out) x)
                   , AXI4_Slave #(id_out, b, c, d, e, f, g, h) s) =
  interface AXI4_Slave;
    interface aw = mapSink   (mapAXI4_AWFlit_awid (fReq), s.aw);
    interface  w = s.w;
    interface  b = mapSource (mapAXI4_BFlit_bid   (fRsp), s.b);
    interface ar = mapSink   (mapAXI4_ARFlit_arid (fReq), s.ar);
    interface  r = mapSource (mapAXI4_RFlit_rid   (fRsp), s.r);
  endinterface;

function AXI4_Slave #(a, addr_in, c, d, e, f, g, h)
  mapAXI4_Slave_addr ( function Bit #(addr_out) fun (Bit #(addr_in) x)
                     , AXI4_Slave #(a, addr_out, c, d, e, f, g, h) s) =
  interface AXI4_Slave;
    interface aw = mapSink (mapAXI4_AWFlit_awaddr (fun), s.aw);
    interface  w = s.w;
    interface  b = s.b;
    interface ar = mapSink (mapAXI4_ARFlit_araddr (fun), s.ar);
    interface  r = s.r;
  endinterface;

function AXI4_Slave #(a, b, c, d_, e_, f_, g_, h_)
  mapAXI4_Slave_user ( function Bit #(d)  fAW (Bit #(d_) x)
                     , function Bit #(e)  fW  (Bit #(e_) x)
                     , function Bit #(f_) fB  (Bit #(f)  x)
                     , function Bit #(g)  fAR (Bit #(g_) x)
                     , function Bit #(h_) fR  (Bit #(h)  x)
                     , AXI4_Slave #(a, b, c, d, e, f, g, h) s) =
  interface AXI4_Slave;
    interface aw = mapSink   (mapAXI4_AWFlit_awuser (fAW), s.aw);
    interface  w = mapSink   (mapAXI4_WFlit_wuser   (fW), s.w);
    interface  b = mapSource (mapAXI4_BFlit_buser   (fB), s.b);
    interface ar = mapSink   (mapAXI4_ARFlit_aruser (fAR), s.ar);
    interface  r = mapSource (mapAXI4_RFlit_ruser   (fR), s.r);
  endinterface;

///////////////////////////////////////////
// AXI4 map-based higher level utilities //
////////////////////////////////////////////////////////////////////////////////

function AXI4_Master #(id_out, b, c, d, e, f, g, h)
  prepend_AXI4_Master_id ( Bit #(t_upper_sz) upperBits
                         , AXI4_Master #(id_in, b, c, d, e, f, g, h) m)
  provisos (Add #(t_upper_sz, id_in, id_out)); // id_out = t_upper_sz + id_in
  function fun (x) = {upperBits, x};
  return mapAXI4_Master_id (fun, truncate, m);
endfunction

function AXI4_Master #(a, addr_out, c, d, e, f, g, h)
  truncate_AXI4_Master_addr (AXI4_Master #(a, addr_in, c, d, e, f, g, h) m)
  provisos (Add #(_a, addr_out, addr_in)) // addr_in >= addr_out
  = mapAXI4_Master_addr (truncate, m);

function AXI4_Master #(a, addr_out, c, d, e, f, g, h)
  prepend_AXI4_Master_addr ( Bit #(t_upper_sz) upperBits
                          , AXI4_Master #(a, addr_in, c, d, e, f, g, h) m)
  provisos (Add #(t_upper_sz, addr_in, addr_out)); // addr_out = t_upper_sz
                                                   //            + addr_in
  function f (x) = {upperBits, x};
  return mapAXI4_Master_addr (f, m);
endfunction

function AXI4_Master #(a, b, c, d_, e_, f_, g_, h_)
  zero_AXI4_Master_user (AXI4_Master #(a, b, c, d, e, f, g, h) m) =
  mapAXI4_Master_user
    (constFn (0), constFn (0), constFn (0), constFn (0), constFn (0), m);

//------------------------------------------------------------------------------

function AXI4_Slave #(id_in, b, c, d, e, f, g, h)
  prepend_AXI4_Slave_id ( Bit #(t_upper_sz) upperBits
                        , AXI4_Slave #(id_out, b, c, d, e, f, g, h) s)
  provisos (Add #(t_upper_sz, id_in, id_out)); // id_out = t_upper_sz + id_in
  function fun (x) = {upperBits, x};
  return mapAXI4_Slave_id (fun, truncate, s);
endfunction

function AXI4_Slave #(a, addr_in, c, d, e, f, g, h)
  truncate_AXI4_Slave_addr (AXI4_Slave #(a, addr_out, c, d, e, f, g, h) s)
  provisos (Add #(_a, addr_out, addr_in)) // addr_in >= addr_out
  = mapAXI4_Slave_addr (truncate, s);

function AXI4_Slave #(a, addr_in, c, d, e, f, g, h)
  prepend_AXI4_Slave_addr ( Bit #(t_upper_sz) upperBits
                          , AXI4_Slave #(a, addr_out, c, d, e, f, g, h) s)
  provisos (Add #(t_upper_sz, addr_in, addr_out)); // addr_out = t_upper_sz
                                                   //            + addr_in
  function f (x) = {upperBits, x};
  return mapAXI4_Slave_addr (f, s);
endfunction

function AXI4_Slave #(a, b, c, d, e, f, g, h)
  mask_AXI4_Slave_addr ( Bit #(b) mask
                       , AXI4_Slave #(a, b, c, d, e, f, g, h) s);
  function f (x) = x & mask;
  return mapAXI4_Slave_addr (f, s);
endfunction

function AXI4_Slave #(a, b, c, d_, e_, f_, g_, h_)
  zero_AXI4_Slave_user (AXI4_Slave #(a, b, c, d, e, f, g, h) m) =
  mapAXI4_Slave_user
    (constFn (0), constFn (0), constFn (0), constFn (0), constFn (0), m);
