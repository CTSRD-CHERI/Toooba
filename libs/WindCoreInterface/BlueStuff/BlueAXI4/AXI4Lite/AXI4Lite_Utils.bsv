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

// AXI imports
import AXI4Lite_Types :: *;
import AXI4Lite_AW_Utils :: *;
import AXI4Lite_W_Utils :: *;
import AXI4Lite_B_Utils :: *;
import AXI4Lite_AR_Utils :: *;
import AXI4Lite_R_Utils :: *;

// BlueStuff import
import Routable :: *;
// BlueBasics import
import SourceSink :: *;
import MasterSlave :: *;

// Standard
import FIFOF :: *;
import SpecialFIFOs :: *;
import ConfigReg :: *;

///////////////////////////////
// AXI Write channel helpers //
////////////////////////////////////////////////////////////////////////////////

function Source#(AXI4Lite_WriteFlit#(addr_, data_, awu_, wu_)) mergeLiteWrite(
  Source#(AXI4Lite_AWFlit#(addr_, awu_)) aw,
  Source#(AXI4Lite_WFlit#(data_, wu_)) w) = interface Source;
    method canPeek = aw.canPeek && w.canPeek;
    method peek    = AXI4Lite_WriteFlit { aw: aw.peek, w: w.peek };
    method drop    = action aw.drop; w.drop; endaction;
  endinterface;

function Sink#(AXI4Lite_WriteFlit#(addr_, data_, awu_, wu_)) splitLiteWrite(
  Sink#(AXI4Lite_AWFlit#(addr_, awu_)) aw,
  Sink#(AXI4Lite_WFlit#(data_, wu_)) w) = interface Sink;
    method canPut = aw.canPut && w.canPut;
    method put(x) = action
      aw.put(x.aw);
      w.put(x.w);
    endaction;
  endinterface;

////////////////////////////
// AXI4Lite map utilities //
////////////////////////////////////////////////////////////////////////////////

function AXI4Lite_Master #(addr_out, b, c, d, e, f, g)
  mapAXI4Lite_Master_addr ( function Bit #(addr_out) fun (Bit #(addr_in) x)
                          , AXI4Lite_Master #(addr_in, b, c, d, e, f, g)  m) =
  interface AXI4Lite_Master;
    interface aw = mapSource (mapAXI4Lite_AWFlit_awaddr (fun), m.aw);
    interface  w = m.w;
    interface  b = m.b;
    interface ar = mapSource (mapAXI4Lite_ARFlit_araddr (fun), m.ar);
    interface  r = m.r;
  endinterface;

function AXI4Lite_Master #(a, b, c_, d_, e_, f_, g_)
  mapAXI4Lite_Master_user ( function Bit #(c_) fAW (Bit #(c)  x)
                          , function Bit #(d_) fW  (Bit #(d)  x)
                          , function Bit #(e)  fB  (Bit #(e_) x)
                          , function Bit #(f_) fAR (Bit #(f)  x)
                          , function Bit #(g)  fR  (Bit #(g_) x)
                          , AXI4Lite_Master #(a, b, c, d, e, f, g) m) =
  interface AXI4Lite_Master;
    interface aw = mapSource (mapAXI4Lite_AWFlit_awuser (fAW), m.aw);
    interface  w = mapSource (mapAXI4Lite_WFlit_wuser   (fW), m.w);
    interface  b = mapSink   (mapAXI4Lite_BFlit_buser   (fB), m.b);
    interface ar = mapSource (mapAXI4Lite_ARFlit_aruser (fAR), m.ar);
    interface  r = mapSink   (mapAXI4Lite_RFlit_ruser   (fR), m.r);
  endinterface;

//------------------------------------------------------------------------------

function AXI4Lite_Slave #(addr_b, b, c, d, e, f, g)
  mapAXI4Lite_Slave_addr ( function Bit #(addr_a) fun (Bit #(addr_b) x)
                         , AXI4Lite_Slave #(addr_a, b, c, d, e, f, g) s) =
  interface AXI4Lite_Slave;
    interface aw = mapSink (mapAXI4Lite_AWFlit_awaddr (fun), s.aw);
    interface  w = s.w;
    interface  b = s.b;
    interface ar = mapSink (mapAXI4Lite_ARFlit_araddr (fun), s.ar);
    interface  r = s.r;
  endinterface;

function AXI4Lite_Slave #(a, b, c_, d_, e_, f_, g_)
  mapAXI4Lite_Slave_user ( function Bit #(c)  fAW (Bit #(c_) x)
                         , function Bit #(d)  fW  (Bit #(d_) x)
                         , function Bit #(e_) fB  (Bit #(e)  x)
                         , function Bit #(f)  fAR (Bit #(f_) x)
                         , function Bit #(g_) fR  (Bit #(g)  x)
                         , AXI4Lite_Slave #(a, b, c, d, e, f, g) s) =
  interface AXI4Lite_Slave;
    interface aw = mapSink   (mapAXI4Lite_AWFlit_awuser (fAW), s.aw);
    interface  w = mapSink   (mapAXI4Lite_WFlit_wuser   (fW), s.w);
    interface  b = mapSource (mapAXI4Lite_BFlit_buser   (fB), s.b);
    interface ar = mapSink   (mapAXI4Lite_ARFlit_aruser (fAR), s.ar);
    interface  r = mapSource (mapAXI4Lite_RFlit_ruser   (fR), s.r);
  endinterface;

///////////////////////////////////////////////
// AXI4Lite map-based higher level utilities //
////////////////////////////////////////////////////////////////////////////////

function AXI4Lite_Master #(addr_out, b, c, d, e, f, g)
  truncate_AXI4Lite_Master_addr (AXI4Lite_Master #(addr_in, b, c, d, e, f, g) m)
  provisos (Add #(_a, addr_out, addr_in)) // addr_in >= addr_out
  = mapAXI4Lite_Master_addr (truncate, m);

function AXI4Lite_Master #(addr_b, b, c, d, e, f, g)
  prepend_AXI4Lite_Master_addr ( Bit #(TSub #(addr_b, addr_a)) upperBits
                               , AXI4Lite_Master #(addr_a, b, c, d, e, f, g) m)
  provisos (Add #(_a, addr_a, addr_b)); // addr_b >= addr_a
  function f (x) = {upperBits, x};
  return mapAXI4Lite_Master_addr (f, m);
endfunction

function AXI4Lite_Master #(a, b, c_, d_, e_, f_, g_)
  zero_AXI4Lite_Master_user (AXI4Lite_Master #(a, b, c, d, e, f, g) m) =
  mapAXI4Lite_Master_user
    (constFn (0), constFn (0), constFn (0), constFn (0), constFn (0), m);

//------------------------------------------------------------------------------

function AXI4Lite_Slave #(addr_out, b, c, d, e, f, g)
  truncate_AXI4Lite_Slave_addr (AXI4Lite_Slave #(addr_in, b, c, d, e, f, g) s)
  provisos (Add #(_a, addr_in, addr_out)) // addr_out >= addr_in
  = mapAXI4Lite_Slave_addr (truncate, s);

function AXI4Lite_Slave #(addr_a, b, c, d, e, f, g)
  prepend_AXI4Lite_Slave_addr ( Bit #(TSub #(addr_b, addr_a)) upperBits
                              , AXI4Lite_Slave #(addr_b, b, c, d, e, f, g) s)
  provisos (Add #(_a, addr_a, addr_b)); // addr_b >= addr_b
  function f (x) = {upperBits, x};
  return mapAXI4Lite_Slave_addr (f, s);
endfunction

function AXI4Lite_Slave #(a, b, c, d, e, f, g)
  mask_AXI4Lite_Slave_addr ( Bit #(a) mask
                           , AXI4Lite_Slave #(a, b, c, d, e, f, g) s);
  function f (x) = x & mask;
  return mapAXI4Lite_Slave_addr (f, s);
endfunction

function AXI4Lite_Slave #(a, b, c, d, e, f, g)
  offset_AXI4Lite_Slave_addr ( Int #(a) offset
                             , AXI4Lite_Slave #(a, b, c, d, e, f, g) s);
  function f (x) = pack (unpack (x) + offset);
  return mapAXI4Lite_Slave_addr (f, s);
endfunction

function AXI4Lite_Slave #(a, b, c_, d_, e_, f_, g_)
  zero_AXI4Lite_Slave_user (AXI4Lite_Slave #(a, b, c, d, e, f, g) m) =
  mapAXI4Lite_Slave_user
    (constFn (0), constFn (0), constFn (0), constFn (0), constFn (0), m);

///////////////////////////////
// AXI Shim Master <-> Slave //
////////////////////////////////////////////////////////////////////////////////

// XXX
// Macro to work around the fact that we cannot pass FIFOF module constructor
// and use it for different channels with different types (need Rank2Types)...?
`define defAXI4LiteShimFIFOF (name, mkFF)\
module mkAXI4LiteShim``name (AXI4Lite_Shim#(a, b, c, d, e, f, g));\
  let awff <- mkFF;\
  let  wff <- mkFF;\
  let  bff <- mkFF;\
  let arff <- mkFF;\
  let  rff <- mkFF;\
  method clear = action\
    awff.clear;\
    wff.clear;\
    bff.clear;\
    arff.clear;\
    rff.clear;\
  endaction;\
  interface master = interface AXI4Lite_Master;\
    interface aw = toSource(awff);\
    interface  w = toSource(wff);\
    interface  b = toSink(bff);\
    interface ar = toSource(arff);\
    interface  r = toSink(rff);\
  endinterface;\
  interface slave = interface AXI4Lite_Slave;\
    interface aw = toSink(awff);\
    interface  w = toSink(wff);\
    interface  b = toSource(bff);\
    interface ar = toSink(arff);\
    interface  r = toSource(rff);\
  endinterface;\
endmodule

`defAXI4LiteShimFIFOF(BypassFIFOF, mkBypassFIFOF)
`defAXI4LiteShimFIFOF(BypassFF1, mkSizedBypassFIFOF(1))
`defAXI4LiteShimFIFOF(FF1, mkFIFOF1)
`defAXI4LiteShimFIFOF(FF, mkFIFOF)
`defAXI4LiteShimFIFOF(SizedFIFOF4, mkSizedFIFOF(4))

module mkAXI4LiteShim (AXI4Lite_Shim#(a, b, c, d, e, f, g));
  AXI4Lite_Shim#(a, b, c, d, e, f, g) shim <- mkAXI4LiteShimBypassFIFOF;
  return shim;
endmodule

/////////////////////////
// Debug / Trace utils //
////////////////////////////////////////////////////////////////////////////////

function AXI4Lite_Master#(a,b,c,d,e,f,g)
         debugAXI4Lite_Master(AXI4Lite_Master#(a,b,c,d,e,f,g) m, Fmt msg) =
  interface AXI4Lite_Master;
    interface aw = debugSource(m.aw, $format(msg, " aw"));
    interface w  = debugSource( m.w, $format(msg, "  w"));
    interface b  = debugSink  ( m.b, $format(msg, "  b"));
    interface ar = debugSource(m.ar, $format(msg, " ar"));
    interface r  = debugSink  ( m.r, $format(msg, "  r"));
  endinterface;

function AXI4Lite_Slave#(a,b,c,d,e,f,g)
         debugAXI4Lite_Slave(AXI4Lite_Slave#(a,b,c,d,e,f,g) s, Fmt msg) =
  interface AXI4Lite_Slave;
    interface aw = debugSink  (s.aw, $format(msg, " aw"));
    interface w  = debugSink  ( s.w, $format(msg, "  w"));
    interface b  = debugSource( s.b, $format(msg, "  b"));
    interface ar = debugSink  (s.ar, $format(msg, " ar"));
    interface r  = debugSource( s.r, $format(msg, "  r"));
  endinterface;

module mkAXI4LiteDebugShim #(String debugTag) (AXI4Lite_Shim#(a,b,c,d,e,f,g));
  let shim <- mkAXI4LiteShim;
  interface  slave = shim.slave;
  interface master = debugAXI4Lite_Master(shim.master, $format(debugTag));
  interface  clear = shim.clear;
endmodule

module mkAXI4DebugShimSig #(String debugTag)
                           (AXI4Lite_Shim_Sig#(a,b,c,d,e,f,g));
  let shim <- mkAXI4LiteDebugShim(debugTag);
  let masterSig <- toAXI4Lite_Master_Sig(shim.master);
  let  slaveSig <- toAXI4Lite_Slave_Sig(shim.slave);
  interface master = masterSig;
  interface  slave = slaveSig;
  interface  clear = shim.clear;
endmodule


///////////////////////////////////
// to/from "Sig" interface utils //
////////////////////////////////////////////////////////////////////////////////

// AXI4Lite Master
module toAXI4Lite_Master_Sig #(AXI4Lite_Master#(a, b, c, d, e, f, g) master)
                              (AXI4Lite_Master_Sig#(a, b, c, d, e, f, g));
  let awSig <- toAXI4Lite_AW_Master_Sig(master.aw);
  let wSig  <- toAXI4Lite_W_Master_Sig(master.w);
  let bSig  <- toAXI4Lite_B_Master_Sig(master.b);
  let arSig <- toAXI4Lite_AR_Master_Sig(master.ar);
  let rSig  <- toAXI4Lite_R_Master_Sig(master.r);
  interface aw = awSig;
  interface w  = wSig;
  interface b  = bSig;
  interface ar = arSig;
  interface r  = rSig;
endmodule

module fromAXI4Lite_Master_Sig
  #(AXI4Lite_Master_Sig#(a, b, c, d, e, f, g) master)
   (AXI4Lite_Master#(a, b, c, d, e, f, g));
  let awNoSig <- fromAXI4Lite_AW_Master_Sig(master.aw);
  let wNoSig  <- fromAXI4Lite_W_Master_Sig(master.w);
  let bNoSig  <- fromAXI4Lite_B_Master_Sig(master.b);
  let arNoSig <- fromAXI4Lite_AR_Master_Sig(master.ar);
  let rNoSig  <- fromAXI4Lite_R_Master_Sig(master.r);
  interface aw = awNoSig;
  interface w  = wNoSig;
  interface b  = bNoSig;
  interface ar = arNoSig;
  interface r  = rNoSig;
endmodule

module liftAXI4Lite_Master_Sig
  #( function AXI4Lite_Master#(a, b, c, d, e, f, g)
     f (AXI4Lite_Master#(a1, b1, c1, d1, e1, f1, g1) x)
   , AXI4Lite_Master_Sig#(a1, b1, c1, d1, e1, f1, g1) m)
   (AXI4Lite_Master_Sig#(a, b, c, d, e, f, g));
  let mNoSig <- fromAXI4Lite_Master_Sig (m);
  let ret <- toAXI4Lite_Master_Sig (f (mNoSig));
  return ret;
endmodule

// AXI4Lite Slave
module toAXI4Lite_Slave_Sig #(AXI4Lite_Slave#(a, b, c, d, e, f, g) slave)
                             (AXI4Lite_Slave_Sig#(a, b, c, d, e, f, g));
  let awSig <- toAXI4Lite_AW_Slave_Sig(slave.aw);
  let wSig  <- toAXI4Lite_W_Slave_Sig(slave.w);
  let bSig  <- toAXI4Lite_B_Slave_Sig(slave.b);
  let arSig <- toAXI4Lite_AR_Slave_Sig(slave.ar);
  let rSig  <- toAXI4Lite_R_Slave_Sig(slave.r);
  interface aw = awSig;
  interface w  = wSig;
  interface b  = bSig;
  interface ar = arSig;
  interface r  = rSig;
endmodule

module fromAXI4Lite_Slave_Sig
  #(AXI4Lite_Slave_Sig#(a, b, c, d, e, f, g) slave)
   (AXI4Lite_Slave#(a, b, c, d, e, f, g));
  let awNoSig <- fromAXI4Lite_AW_Slave_Sig(slave.aw);
  let wNoSig  <- fromAXI4Lite_W_Slave_Sig(slave.w);
  let bNoSig  <- fromAXI4Lite_B_Slave_Sig(slave.b);
  let arNoSig <- fromAXI4Lite_AR_Slave_Sig(slave.ar);
  let rNoSig  <- fromAXI4Lite_R_Slave_Sig(slave.r);
  interface aw = awNoSig;
  interface w  = wNoSig;
  interface b  = bNoSig;
  interface ar = arNoSig;
  interface r  = rNoSig;
endmodule

module liftAXI4Lite_Slave_Sig
  #( function AXI4Lite_Slave#(a, b, c, d, e, f, g)
     f (AXI4Lite_Slave#(a1, b1, c1, d1, e1, f1, g1) x)
   , AXI4Lite_Slave_Sig#(a1, b1, c1, d1, e1, f1, g1) s)
   (AXI4Lite_Slave_Sig#(a, b, c, d, e, f, g));
  let sNoSig <- fromAXI4Lite_Slave_Sig (s);
  let ret <- toAXI4Lite_Slave_Sig (f (sNoSig));
  return ret;
endmodule

/////////////////////////////
// to unguarded interfaces //
////////////////////////////////////////////////////////////////////////////////

module toUnguarded_AXI4Lite_Master #(AXI4Lite_Master#(a, b, c, d, e, f, g) m)
                                    (AXI4Lite_Master#(a, b, c, d, e, f, g));
  let u_aw <- toUnguardedSource(m.aw, ?);
  let u_w  <- toUnguardedSource(m.w, ?);
  let u_b  <- toUnguardedSink(m.b);
  let u_ar <- toUnguardedSource(m.ar, ?);
  let u_r  <- toUnguardedSink(m.r);
  interface aw = u_aw;
  interface w  = u_w;
  interface b  = u_b;
  interface ar = u_ar;
  interface r  = u_r;
endmodule

module toUnguarded_AXI4Lite_Slave #(AXI4Lite_Slave#(a, b, c, d, e, f, g) s)
                                   (AXI4Lite_Slave#(a, b, c, d, e, f, g));
  let u_aw <- toUnguardedSink(s.aw);
  let u_w  <- toUnguardedSink(s.w);
  let u_b  <- toUnguardedSource(s.b, ?);
  let u_ar <- toUnguardedSink(s.ar);
  let u_r  <- toUnguardedSource(s.r, ?);
  interface aw = u_aw;
  interface w  = u_w;
  interface b  = u_b;
  interface ar = u_ar;
  interface r  = u_r;
endmodule

function AXI4Lite_Master#(a,b,c,d,e,f,g) guard_AXI4Lite_Master
        (AXI4Lite_Master#(a,b,c,d,e,f,g) raw, Bool block) =
  interface AXI4Lite_Master;
    interface aw = guardSource(raw.aw, block);
    interface w  = guardSource(raw.w, block);
    interface b  = guardSink(raw.b, block);
    interface ar = guardSource(raw.ar, block);
    interface r  = guardSink(raw.r, block);
  endinterface;

function AXI4Lite_Slave#(a,b,c,d,e,f,g) guard_AXI4Lite_Slave
        (AXI4Lite_Slave#(a,b,c,d,e,f,g) raw, Bool block) =
  interface AXI4Lite_Slave;
    interface aw = guardSink(raw.aw, block);
    interface w  = guardSink(raw.w, block);
    interface b  = guardSource(raw.b, block);
    interface ar = guardSink(raw.ar, block);
    interface r  = guardSource(raw.r, block);
  endinterface;
