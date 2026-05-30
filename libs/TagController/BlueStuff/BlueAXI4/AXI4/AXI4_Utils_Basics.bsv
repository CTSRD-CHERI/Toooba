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
import AXI4_Common_Types :: *;
import AXI4_Channels_Utils :: *;

// BlueBasics import
import BlueBasics :: *;

// Standard
import FIFOF :: *;
import SpecialFIFOs :: *;

////////////////////////////////
// AXI4 Shim Master <-> Slave //
////////////////////////////////////////////////////////////////////////////////

module mkAXI4Shim_core #(
    function module #(FIFOF #(AXI4_AWFlit #(a, b, d))) mkAWFF ()
  , function module #(FIFOF #(AXI4_WFlit #(c, e))) mkWFF ()
  , function module #(FIFOF #(AXI4_BFlit #(a, f))) mkBFF ()
  , function module #(FIFOF #(AXI4_ARFlit #(a, b, g))) mkARFF ()
  , function module #(FIFOF #(AXI4_RFlit #(a, c, h))) mkRFF () )
  (AXI4_Shim#(a, b, c, d, e, f, g, h));
  let awff <- mkAWFF;
  let  wff <- mkWFF;
  let  bff <- mkBFF;
  let arff <- mkARFF;
  let  rff <- mkRFF;
  method clear = action
    awff.clear;
    wff.clear;
    bff.clear;
    arff.clear;
    rff.clear;
  endaction;
  interface master = interface AXI4_Master;
    interface aw = toSource(awff);
    interface  w = toSource(wff);
    interface  b = toSink(bff);
    interface ar = toSource(arff);
    interface  r = toSink(rff);
  endinterface;
  interface slave = interface AXI4_Slave;
    interface aw = toSink(awff);
    interface  w = toSink(wff);
    interface  b = toSource(bff);
    interface ar = toSink(arff);
    interface  r = toSource(rff);
  endinterface;
endmodule

`define defAXI4ShimFIFOFs (name, mkAWFF, mkWFF, mkBFF, mkARFF, mkRFF)\
module mkAXI4Shim``name (AXI4_Shim#(a, b, c, d, e, f, g, h));\
  let shim <- mkAXI4Shim_core (mkAWFF, mkWFF, mkBFF, mkARFF, mkRFF);\
  return shim;\
endmodule

`define defAXI4ShimFIFOF (name, mkFF)\
`defAXI4ShimFIFOFs(name, mkFF, mkFF, mkFF, mkFF, mkFF)

`defAXI4ShimFIFOF(BypassFIFOF, mkBypassFIFOF)
`defAXI4ShimFIFOF(BypassFF1, mkSizedBypassFIFOF(1))
`defAXI4ShimFIFOF(FF1, mkFIFOF1)
`defAXI4ShimFIFOF(FF, mkFIFOF)
`defAXI4ShimFIFOF(SizedFIFOF4, mkSizedFIFOF(4))
`defAXI4ShimFIFOF(SizedFIFOF32, mkSizedFIFOF(32))
`defAXI4ShimFIFOF(UGSizedFIFOF32, mkUGSizedFIFOF(32))
`defAXI4ShimFIFOF(UGSizedFIFOF4, mkUGSizedFIFOF(4))
`defAXI4ShimFIFOF(UGFF, mkUGFIFOF)

module mkAXI4Shim (AXI4_Shim#(a, b, c, d, e, f, g, h));
  AXI4_Shim#(a, b, c, d, e, f, g, h) shim <- mkAXI4ShimBypassFIFOF;
  return shim;
endmodule

module toAXI4_Shim_Sig #(AXI4_Shim#(a, b, c, d, e, f, g, h) shim)
                        (AXI4_Shim_Sig#(a, b, c, d, e, f, g, h));
  let masterSig <- toAXI4_Master_Sig(shim.master);
  let  slaveSig <- toAXI4_Slave_Sig(shim.slave);
  interface master = masterSig;
  interface  slave = slaveSig;
  interface  clear = shim.clear;
endmodule

//////////////////////////////
// AXI4 Debug / Trace utils //
////////////////////////////////////////////////////////////////////////////////

function AXI4_Master#(a,b,c,d,e,f,g,h)
         debugAXI4_Master(AXI4_Master#(a,b,c,d,e,f,g,h) m, Fmt msg) =
  interface AXI4_Master;
    interface aw = debugSource(m.aw, $format(msg, " aw"));
    interface w  = debugSource( m.w, $format(msg, " w"));
    interface b  = debugSink  ( m.b, $format(msg, " b"));
    interface ar = debugSource(m.ar, $format(msg, " ar"));
    interface r  = debugSink  ( m.r, $format(msg, " r"));
  endinterface;

function AXI4_Slave#(a,b,c,d,e,f,g,h)
         debugAXI4_Slave(AXI4_Slave#(a,b,c,d,e,f,g,h) s, Fmt msg) =
  interface AXI4_Slave;
    interface aw = debugSink  (s.aw, $format(msg, " aw"));
    interface w  = debugSink  ( s.w, $format(msg, " w"));
    interface b  = debugSource( s.b, $format(msg, " b"));
    interface ar = debugSink  (s.ar, $format(msg, " ar"));
    interface r  = debugSource( s.r, $format(msg, " r"));
  endinterface;

module mkAXI4DebugShim #(String debugTag) (AXI4_Shim#(a,b,c,d,e,f,g,h));
  let shim <- mkAXI4Shim;
  interface  slave = shim.slave;
  interface master = debugAXI4_Master(shim.master, $format(debugTag));
  interface  clear = shim.clear;
endmodule

module mkAXI4DebugShimSig #(String debugTag) (AXI4_Shim_Sig#(a,b,c,d,e,f,g,h));
  let shim <- mkAXI4DebugShim(debugTag);
  let masterSig <- toAXI4_Master_Sig(shim.master);
  let  slaveSig <- toAXI4_Slave_Sig(shim.slave);
  interface master = masterSig;
  interface  slave = slaveSig;
  interface  clear = shim.clear;
endmodule

///////////////////////////
// AXI4 monitoring utils //
////////////////////////////////////////////////////////////////////////////////

module monitorAXI4_Shim #(AXI4_Shim#(a, b, c, d, e, f, g, h) shim)
                         (Monitored#( AXI4_Shim#(a, b, c, d, e, f, g, h)
                                    , Tuple2#(AXI4_Events, AXI4_Events)));
  let masterMonitor <- monitorAXI4_Master(shim.master);
  let  slaveMonitor <- monitorAXI4_Slave(shim.slave);
  interface ifc = interface AXI4_Shim;
    interface  clear = shim.clear;
    interface master = masterMonitor.ifc;
    interface  slave = slaveMonitor.ifc;
  endinterface;
  interface events = interface ReadOnly;
    method _read = tuple2(masterMonitor.events, slaveMonitor.events);
  endinterface;
endmodule

module monitorAXI4_Master #(AXI4_Master#(a, b, c, d, e, f, g, h) master)
                           (Monitored#( AXI4_Master#(a, b, c, d, e, f, g, h)
                                      , AXI4_Events));
  function f (x) = tuple2(True, isLast(x));
  let awMonitor <- monitorSource(master.aw);
  let  wMonitor <- monitorSourceWith(master.w, f);
  let  bMonitor <- monitorSink(master.b);
  let arMonitor <- monitorSource(master.ar);
  let  rMonitor <- monitorSinkWith(master.r, f);
  interface ifc = interface AXI4_Master;
    interface aw = awMonitor.ifc;
    interface  w = wMonitor.ifc;
    interface  b = bMonitor.ifc;
    interface ar = arMonitor.ifc;
    interface  r = rMonitor.ifc;
  endinterface;
  interface events = interface ReadOnly;
    method _read = AXI4_Events { evt_AW_FLIT:      awMonitor.events
                               , evt_W_FLIT:       tpl_1(wMonitor.events)
                               , evt_W_FLIT_FINAL: tpl_2(wMonitor.events)
                               , evt_B_FLIT:       bMonitor.events
                               , evt_AR_FLIT:      arMonitor.events
                               , evt_R_FLIT:       tpl_1(rMonitor.events)
                               , evt_R_FLIT_FINAL: tpl_2(rMonitor.events) };
  endinterface;
endmodule

module monitorAXI4_Slave #(AXI4_Slave#(a, b, c, d, e, f, g, h) slave)
                          (Monitored#( AXI4_Slave#(a, b, c, d, e, f, g, h)
                                     , AXI4_Events));
  function f (x) = tuple2(True, isLast(x));
  let awMonitor <- monitorSink(slave.aw);
  let  wMonitor <- monitorSinkWith(slave.w, f);
  let  bMonitor <- monitorSource(slave.b);
  let arMonitor <- monitorSink(slave.ar);
  let  rMonitor <- monitorSourceWith(slave.r, f);
  interface ifc = interface AXI4_Slave;
    interface aw = awMonitor.ifc;
    interface  w = wMonitor.ifc;
    interface  b = bMonitor.ifc;
    interface ar = arMonitor.ifc;
    interface  r = rMonitor.ifc;
  endinterface;
  interface events = interface ReadOnly;
    method _read = AXI4_Events { evt_AW_FLIT:      awMonitor.events
                               , evt_W_FLIT:       tpl_1(wMonitor.events)
                               , evt_W_FLIT_FINAL: tpl_2(wMonitor.events)
                               , evt_B_FLIT:       bMonitor.events
                               , evt_AR_FLIT:      arMonitor.events
                               , evt_R_FLIT:       tpl_1(rMonitor.events)
                               , evt_R_FLIT_FINAL: tpl_2(rMonitor.events) };
  endinterface;
endmodule

////////////////////////
// AXI4 probing utils //
////////////////////////////////////////////////////////////////////////////////

module probeAXI4_Master #(AXI4_Master #(a, b, c, d, e, f, g, h) master)
                         (AXI4_Master #(a, b, c, d, e, f, g, h));
  let aw <- probeAXI4_AWFlit_Source (master.aw);
  let  w <- probeAXI4_WFlit_Source  (master.w);
  let  b <- probeAXI4_BFlit_Sink    (master.b);
  let ar <- probeAXI4_ARFlit_Source (master.ar);
  let  r <- probeAXI4_RFlit_Sink    (master.r);
  return interface AXI4_Master;
    interface aw = aw;
    interface  w =  w;
    interface  b =  b;
    interface ar = ar;
    interface  r =  r;
  endinterface;
endmodule

module probeAXI4_Slave #(AXI4_Slave #(a, b, c, d, e, f, g, h) slave)
                        (AXI4_Slave #(a, b, c, d, e, f, g, h));
  let aw <- probeAXI4_AWFlit_Sink  (slave.aw);
  let  w <- probeAXI4_WFlit_Sink   (slave.w);
  let  b <- probeAXI4_BFlit_Source (slave.b);
  let ar <- probeAXI4_ARFlit_Sink  (slave.ar);
  let  r <- probeAXI4_RFlit_Source (slave.r);
  return interface AXI4_Slave;
    interface aw = aw;
    interface  w =  w;
    interface  b =  b;
    interface ar = ar;
    interface  r =  r;
  endinterface;
endmodule

///////////////////////////////////
// to/from "Sig" interface utils //
////////////////////////////////////////////////////////////////////////////////

// AXI4 Master
module toAXI4_Master_Sig #(AXI4_Master#(a, b, c, d, e, f, g, h) master)
                          (AXI4_Master_Sig#(a, b, c, d, e, f, g, h));
  let awSig <- toAXI4_AW_Master_Sig(master.aw);
  let wSig  <- toAXI4_W_Master_Sig(master.w);
  let bSig  <- toAXI4_B_Master_Sig(master.b);
  let arSig <- toAXI4_AR_Master_Sig(master.ar);
  let rSig  <- toAXI4_R_Master_Sig(master.r);
  interface aw = awSig;
  interface w  = wSig;
  interface b  = bSig;
  interface ar = arSig;
  interface r  = rSig;
endmodule

module fromAXI4_Master_Sig #(AXI4_Master_Sig#(a, b, c, d, e, f, g, h) master)
                            (AXI4_Master#(a, b, c, d, e, f, g, h));
  let awNoSig <- fromAXI4_AW_Master_Sig(master.aw);
  let wNoSig  <- fromAXI4_W_Master_Sig(master.w);
  let bNoSig  <- fromAXI4_B_Master_Sig(master.b);
  let arNoSig <- fromAXI4_AR_Master_Sig(master.ar);
  let rNoSig  <- fromAXI4_R_Master_Sig(master.r);
  interface aw = awNoSig;
  interface w  = wNoSig;
  interface b  = bNoSig;
  interface ar = arNoSig;
  interface r  = rNoSig;
endmodule

module liftAXI4_Master_Sig
  #( function AXI4_Master#(a, b, c, d, e, f, g, h)
     f (AXI4_Master#(a1, b1, c1, d1, e1, f1, g1, h1) x)
   , AXI4_Master_Sig#(a1, b1, c1, d1, e1, f1, g1, h1) m)
   (AXI4_Master_Sig#(a, b, c, d, e, f, g, h));
  let mNoSig <- fromAXI4_Master_Sig (m);
  let ret <- toAXI4_Master_Sig (f (mNoSig));
  return ret;
endmodule

// AXI4 Slave
module toAXI4_Slave_Sig #(AXI4_Slave#(a, b, c, d, e, f, g, h) slave)
                         (AXI4_Slave_Sig#(a, b, c, d, e, f, g, h));
  let awSig <- toAXI4_AW_Slave_Sig(slave.aw);
  let wSig  <- toAXI4_W_Slave_Sig(slave.w);
  let bSig  <- toAXI4_B_Slave_Sig(slave.b);
  let arSig <- toAXI4_AR_Slave_Sig(slave.ar);
  let rSig  <- toAXI4_R_Slave_Sig(slave.r);
  interface aw = awSig;
  interface w  = wSig;
  interface b  = bSig;
  interface ar = arSig;
  interface r  = rSig;
endmodule

module fromAXI4_Slave_Sig #(AXI4_Slave_Sig#(a, b, c, d, e, f, g, h) slave)
                           (AXI4_Slave#(a, b, c, d, e, f, g, h));
  let awNoSig <- fromAXI4_AW_Slave_Sig(slave.aw);
  let wNoSig  <- fromAXI4_W_Slave_Sig(slave.w);
  let bNoSig  <- fromAXI4_B_Slave_Sig(slave.b);
  let arNoSig <- fromAXI4_AR_Slave_Sig(slave.ar);
  let rNoSig  <- fromAXI4_R_Slave_Sig(slave.r);
  interface aw = awNoSig;
  interface w  = wNoSig;
  interface b  = bNoSig;
  interface ar = arNoSig;
  interface r  = rNoSig;
endmodule

module liftAXI4_Slave_Sig
  #( function AXI4_Slave#(a, b, c, d, e, f, g, h)
     f (AXI4_Slave#(a1, b1, c1, d1, e1, f1, g1, h1) x)
   , AXI4_Slave_Sig#(a1, b1, c1, d1, e1, f1, g1, h1) s)
   (AXI4_Slave_Sig#(a, b, c, d, e, f, g, h));
  let sNoSig <- fromAXI4_Slave_Sig (s);
  let ret <- toAXI4_Slave_Sig (f (sNoSig));
  return ret;
endmodule

/////////////////////////////////////
// to guarded/unguarded interfaces //
////////////////////////////////////////////////////////////////////////////////

module toUnguarded_AXI4_Master#(AXI4_Master#(a, b, c, d, e, f, g, h) m)
  (AXI4_Master#(a, b, c, d, e, f, g, h));
  let u_aw <- toUnguardedSource(m.aw, ?);
  let u_w  <- toUnguardedSource(m.w, ?);
  let u_b  <- toUnguardedSink(m.b);
  let u_ar <- toUnguardedSource(m.ar, ?);
  let u_r  <- toUnguardedSink(m.r);
  return interface AXI4_Master;
    interface aw = u_aw;
    interface w  = u_w;
    interface b  = u_b;
    interface ar = u_ar;
    interface r  = u_r;
  endinterface;
endmodule

module toUnguarded_AXI4_Slave#(AXI4_Slave#(a, b, c, d, e, f, g, h) s)
  (AXI4_Slave#(a, b, c, d, e, f, g, h));
  let u_aw <- toUnguardedSink(s.aw);
  let u_w  <- toUnguardedSink(s.w);
  let u_b  <- toUnguardedSource(s.b, ?);
  let u_ar <- toUnguardedSink(s.ar);
  let u_r  <- toUnguardedSource(s.r, ?);
  return interface AXI4_Slave;
    interface aw = u_aw;
    interface w  = u_w;
    interface b  = u_b;
    interface ar = u_ar;
    interface r  = u_r;
  endinterface;
endmodule

function AXI4_Master#(a,b,c,d,e,f,g,h) toGuarded_AXI4_Master
        (AXI4_Master#(a,b,c,d,e,f,g,h) m) =
  interface AXI4_Master;
    interface aw = toGuardedSource(m.aw);
    interface w  = toGuardedSource(m.w);
    interface b  = toGuardedSink(m.b);
    interface ar = toGuardedSource(m.ar);
    interface r  = toGuardedSink(m.r);
  endinterface;

function AXI4_Slave#(a,b,c,d,e,f,g,h) toGuarded_AXI4_Slave
      (AXI4_Slave#(a,b,c,d,e,f,g,h) s) =
  interface AXI4_Slave;
    interface aw = toGuardedSink(s.aw);
    interface w  = toGuardedSink(s.w);
    interface b  = toGuardedSource(s.b);
    interface ar = toGuardedSink(s.ar);
    interface r  = toGuardedSource(s.r);
  endinterface;

function AXI4_Master#(a,b,c,d,e,f,g,h) guard_AXI4_Master
        (AXI4_Master#(a,b,c,d,e,f,g,h) raw, Bool block) =
  interface AXI4_Master;
    interface aw = guardSource(raw.aw, block);
    interface w  = guardSource(raw.w, block);
    interface b  = guardSink(raw.b, block);
    interface ar = guardSource(raw.ar, block);
    interface r  = guardSink(raw.r, block);
  endinterface;

function AXI4_Slave#(a,b,c,d,e,f,g,h) guard_AXI4_Slave
        (AXI4_Slave#(a,b,c,d,e,f,g,h) raw, Bool block) =
  interface AXI4_Slave;
    interface aw = guardSink(raw.aw, block);
    interface w  = guardSink(raw.w, block);
    interface b  = guardSource(raw.b, block);
    interface ar = guardSink(raw.ar, block);
    interface r  = guardSource(raw.r, block);
  endinterface;

/////////////////////////
// AXI4 "dummy" Slaves //
////////////////////////////////////////////////////////////////////////////////

module mkPerpetualValueAXI4Slave #(parameter Integer thatOneValue)
                                  (AXI4_Slave#(a, b, c, d, e, f, g, h));
  let inShim <- mkAXI4ShimFF;
  let m = inShim.master;
  let arFlitFF <- mkSizedBypassFIFOF(1);
  let arFlitCnt <- mkReg(0);
  // ignore writes, provide an OK response
  rule drainNonLastW (m.w.canPeek && !m.w.peek.wlast); m.w.drop; endrule
  rule genBFlits (m.w.canPeek && m.w.peek.wlast && m.aw.canPeek && m.b.canPut);
    m.aw.drop;
    m.w.drop;
    m.b.put(AXI4_BFlit { bid: m.aw.peek.awid
                       , bresp: OKAY
                       , buser: ? });
  endrule
  // on read, always return the appropriate number of flits with
  // the perpetual value
  rule grabARFlit (m.ar.canPeek && arFlitFF.notFull);
    let arFlit <- get(m.ar);
    arFlitFF.enq(arFlit);
  endrule
  rule genRFlits (arFlitFF.notEmpty && m.r.canPut);
    // XXX TODO XXX
    // not currently shifting the value in place within the flit:
    // consider arsize together with arFlitCnt current value and arburst
    let arFlit = arFlitFF.first;
    let isLast = False;
    if (arFlitCnt >= {1'b0, arFlit.arlen}) begin
      arFlitFF.deq;
      arFlitCnt <= 0;
      isLast = True;
    end else arFlitCnt <= arFlitCnt + 1;
    m.r.put(AXI4_RFlit { rid: arFlit.arid
                       , rdata: fromInteger(thatOneValue)
                       , rresp: OKAY
                       , rlast: isLast
                       , ruser: ? });
  endrule
  return inShim.slave;
endmodule

module mkPerpetualZeroAXI4Slave (AXI4_Slave#(a, b, c, d, e, f, g, h));
  let ifc <- mkPerpetualValueAXI4Slave (0);
  return ifc;
endmodule
