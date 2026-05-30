/*-
 * Copyright (c) 2018-2022 Alexandre Joannou
 * Copyright (c) 2019 Peter Rugg
 * Copyright (c) 2019 Jonathan Woodruff
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

package SourceSink;

import Vector :: *;
import FIFOF :: *;
import SpecialFIFOs :: *;
import GetPut :: *;
import Connectable :: *;

//////////////////////////////
// Source / Sink interfaces //
////////////////////////////////////////////////////////////////////////////////

interface Source #(type t);
  (* always_ready *) method Bool canPeek;
  method t peek;
  method Action drop;
endinterface

interface Sink #(type t);
  (* always_ready *) method Bool canPut;
  method Action put (t val);
endinterface

interface SourceSink #(type t);
  interface Source #(t) source;
  interface Sink   #(t) sink;
endinterface

//////////////////////
// HasGet typeclass //
////////////////////////////////////////////////////////////////////////////////

typeclass HasGet #(type a, type b);
  function ActionValue #(b) get (a gettable);
endtypeclass

instance HasGet #(a, b) provisos (ToGet #(a, b));
  function get (x) = toGet(x).get;
endinstance

///////////////////////////////////
// ToSource / ToSink typeclasses //
////////////////////////////////////////////////////////////////////////////////

// ToSource

typeclass ToSource #(type a, type b) dependencies (a determines b);
  function Source #(b) toSource (a val);
endtypeclass

instance ToSource #(Source #(t), t);
  function toSource = id;
endinstance

instance ToSource #(FIFOF #(t), t);
  function toSource (ff) = interface Source #(t);
    method canPeek = ff.notEmpty;
    method peek    = ff.first;
    method drop    = ff.deq;
  endinterface;
endinstance

// ToSink

typeclass ToSink #(type a, type b) dependencies (a determines b);
  function Sink #(b) toSink (a val);
endtypeclass

instance ToSink #(Sink #(t), t);
  function toSink = id;
endinstance

instance ToSink #(FIFOF #(t), t);
  function toSink (ff) = interface Sink;
    method canPut = ff.notFull;
    method put    = ff.enq;
  endinterface;
endinstance

/////////////////////////
// mapSource / mapSink //
////////////////////////////////////////////////////////////////////////////////

function Source #(b) mapSource ( function b f (a x)
                               , Source #(a) src) = interface Source;
  method canPeek = src.canPeek;
  method peek    = f (src.peek);
  method drop    = src.drop;
endinterface;

function Sink #(b) mapSink ( function a f (b x)
                           , Sink #(a) snk) = interface Sink;
  method canPut  = snk.canPut;
  method put (x) = snk.put (f (x));
endinterface;

/////////////////////////////
// ToGet / ToPut instances //
////////////////////////////////////////////////////////////////////////////////

// ToGet
instance ToGet #(Source #(t), t);
  function toGet (s) = interface Get;
    method get if (s.canPeek) = actionvalue
      s.drop;
      return s.peek;
    endactionvalue;
  endinterface;
endinstance

/* XXX this can't be defined...
instance ToGet #(src_t, t) provisos (ToSource #(src_t, t));
  function toGet (s) = toGet (toSource (s));
endinstance
*/

//ToPut
instance ToPut #(Sink #(t), t);
  function toPut (s) = interface Put;
    method put if (s.canPut) = s.put;
  endinterface;
endinstance

/* XXX this yields a warning...
instance ToPut #(snk_t, t) provisos (ToSink #(snk_t, t));
  function toPut (s) = toPut (toSink (s));
endinstance
*/

///////////////////////////
// Connectable instances //
////////////////////////////////////////////////////////////////////////////////

instance Connectable #(Source #(t), Sink #(t)) provisos (Bits #(t, t_sz));
  module mkConnection #(Source #(t) src, Sink #(t) snk) (Empty);
    let ug_src <- toUnguardedSource (src, ?);
    let ug_snk <- toUnguardedSink (snk);
    rule connect (ug_src.canPeek && ug_snk.canPut);
      ug_snk.put (ug_src.peek);
      ug_src.drop;
    endrule
  endmodule
endinstance

instance Connectable #(Sink #(t), Source #(t)) provisos (Bits #(t, t_sz));
  module mkConnection #(Sink #(t) snk, Source #(t) src) (Empty);
    mkConnection (src, snk);
  endmodule
endinstance

/*
instance Connectable #(Source #(t), Put #(t));
  module mkConnection #(Source #(t) src, Put #(t) put) (Empty);
    mkConnection (toGet (src), put);
  endmodule
endinstance

instance Connectable #(Put #(t), Source #(t));
  module mkConnection #(Put #(t) put, Source #(t) src) (Empty);
    mkConnection (toGet (src), put);
  endmodule
endinstance

instance Connectable #(Sink #(t), Get #(t));
  module mkConnection #(Sink #(t) snk, Get #(t) get) (Empty);
    mkConnection (get, toPut (snk));
  endmodule
endinstance

instance Connectable #(Get #(t), Sink #(t));
  module mkConnection #(Get #(t) get, Sink #(t) snk) (Empty);
    mkConnection (get, toPut (snk));
  endmodule
endinstance
*/

////////////////////////////////////
// toUnguardedSource/Sink modules //
////////////////////////////////////////////////////////////////////////////////

(* always_ready = "canPeek, peek, drop" *)
module toUnguardedSource #(src_t s, t dflt) (Source #(t))
  provisos (ToSource #(src_t, t), Bits #(t, _));
  let src = toSource (s);
  let canPeekWire <- mkDWire (False);
  let peekWire <- mkDWire (dflt);
  let dropWire <- mkPulseWire;
  rule setCanPeek; canPeekWire <= src.canPeek; endrule
  rule setPeek; peekWire <= src.peek; endrule
  rule warnDoDrop (dropWire && !canPeekWire);
    $display("WARNING: %m - dropping from Source that can't be dropped from");
    //$finish (0);
  endrule
  rule doDrop (dropWire && canPeekWire);
    //$display ("ALLGOOD: dropping from Source");
    src.drop;
  endrule
  return interface Source;
    method canPeek = canPeekWire;
    method peek    = peekWire;
    method drop    = dropWire.send;
  endinterface;
endmodule

(* always_ready = "canPut, put" *)
module toUnguardedSink #(snk_t s) (Sink #(t))
  provisos (ToSink #(snk_t, t), Bits #(t, _));
  let snk = toSink (s);
  let canPutWire <- mkDWire (False);
  let putWire <- mkRWire;
  rule setCanPut; canPutWire <= snk.canPut; endrule
  rule warnDoPut (isValid (putWire.wget) && !snk.canPut);
    $display ("WARNING: %m - putting into a Sink that can't be put into");
    //$finish (0);
  endrule
  rule doPut (isValid (putWire.wget));
    //$display ("ALLGOOD: putting in a Sink");
    snk.put (putWire.wget.Valid);
  endrule
  return interface Sink;
    method canPut = canPutWire;
    method put    = putWire.wset;
  endinterface;
endmodule

////////////////////////////////////
// toGuardedSource/Sink functions //
////////////////////////////////////////////////////////////////////////////////

function Source #(t) toGuardedSource (src_t s) provisos (ToSource #(src_t, t));
  let src = toSource (s);
  return guardSource (src, !src.canPeek);
endfunction

function Sink #(t) toGuardedSink (snk_t s) provisos (ToSink #(snk_t, t));
  let snk = toSink (s);
  return guardSink (snk, !snk.canPut);
endfunction

///////////
// Shims //
////////////////////////////////////////////////////////////////////////////////

module mkPutToSink #(Put #(t) put) (Sink #(t)) provisos (Bits #(t, t_sz));
  FIFOF #(t) ff <- mkBypassFIFOF;
  mkConnection (toGet(ff), put);
  return toSink (ff);
endmodule

module mkGetToSource #(Get #(t) get) (Source #(t)) provisos (Bits #(t, t_sz));
  FIFOF #(t) ff <- mkBypassFIFOF;
  mkConnection (get, toPut (ff));
  return toSource (ff);
endmodule

////////////////////////////////////////
// augment source/sink with an action //
////////////////////////////////////////////////////////////////////////////////

function Source #(t) onDrop (function Action f (t x), src_t s)
  provisos (ToSource #(src_t, t));
  let src = toSource (s);
  return interface Source;
    method canPeek = src.canPeek;
    method peek = src.peek;
    method drop = action src.drop; f (src.peek); endaction;
  endinterface;
endfunction

// Note: if a simple action with no argument is desired, consider using a
//       partially applied call to constFn as the first argument to onPut
function Sink #(t) onPut (function Action f (t x), snk_t s)
  provisos (ToSink #(snk_t, t));
  let snk = toSink (s);
  return interface Sink;
    method canPut = snk.canPut;
    method put (x) = action snk.put (x); f (x); endaction;
  endinterface;
endfunction

/////////////////////////////
// helpers and other utils //
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

// constant source
function Source #(t) constSource (t x) = interface Source;
  method canPeek = True;
  method peek if (True) = x;
  method drop if (True) = noAction;
endinterface;

// null sources / sinks
function Source #(t) nullSource = interface Source;
  method canPeek = False;
  method peek if (False) = ?;
  method drop if (False) = noAction;
endinterface;

function Sink #(t) nullSink = interface Sink;
  method canPut = True;
  method put (x) = noAction;
endinterface;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// Source and Sink merging/spliting API
//
// We aim to provide a set of functions (or modules) to help merging several
// sources or sinks into one, or split one source or sink into several
// individual ones.
//
// When merging / splitting, it is generally necessary to provide a merging /
// splitting behaviour to transform from / into multiple elements (those of each
// initial source / sink) into / from a single element (that of the target
// source / sink). For the functions provided here, there can be a built in
// behaviour, or a parametric behaviour can be expressed as a first order
// function argument.
//
// One can be dealing with multiple data elements of the same type or of
// different types. It is easier to generalise on collections of elements of
// the same uniform type. Here we provide a set of functions dealing with
// homogeneous sources / sinks (that is, where all elements are of the same
// type), as well as a few helpers for heterogeneous sources / sinks. The
// homogeneous helpers use Vectors, and are generally of the rough form:
// Vector #(n, {Source, Sink} #(a)) <-> {Source, Sink} #(Vector #(n, b))
// The heterogeneous helpers focus on pairs, using Tuple2s, and are generally of
// the form:
// Tuple2 #({Source, Sink} #(a), {Source, Sink} #(b))
//   <-> {Source, Sink} #(Tuple2 #(a, b))
//
// When merging multiple sources, the situation can arise where some initiating
// sources have data available, and some others do not. It is possible to
// either take a blocking approach and wait for all initiating sources to have
// data available before propagating a composite data as the target source. An
// alternative is a non-blocking approach, where having data available in any
// initiating source is considered enough to forward data in the target source.
// Note that the composite type of the target source and the merge behaviour
// may need to preserve information about which initiating source contributed
// data if such information is of interest to the target source's consumer.
// Similarly, a blocking or non-blocking approach may be considered for
// source splitting, sink merging and sink splitting.
//
// This API aims to eventually provide helpers for the combinations of:
// * Split / Merge
// * All (blocking) / Any (non-blocking)
// * Homogeneous (uniform type) / Heterogeneous (non-uniform types)
// * Source / Sink
//
// a.k.a.:
//
// splitAllHomogeneousSource
// splitAllHomogeneousSink
// splitAllHeterogeneousSource
// splitAllHeterogeneousSink
// splitAnyHomogeneousSource
// splitAnyHomogeneousSink
// splitAnyHeterogeneousSource
// splitAnyHeterogeneousSink
// mergeAllHomogeneousSource
// mergeAllHomogeneousSink
// mergeAllHeterogeneousSource
// mergeAllHeterogeneousSink
// mergeAnyHomogeneousSource
// mergeAnyHomogeneousSink
// mergeAnyHeterogeneousSource
// mergeAnyHeterogeneousSink
//

// splitAllHomogeneousSource
////////////////////////////////////////////////////////////////////////////////
// XXX TODO XXX
module splitAllHomogeneousSource #( function b f (a x)
                                  , Source #(Vector #(n, a)) src )
                                  (Vector #(n, Source #(b)));
  return error ("splitAllHomogeneousSource not implemented");
endmodule

// splitAllHomogeneousSink
////////////////////////////////////////////////////////////////////////////////
// XXX TODO XXX
module splitAllHomogeneousSink #( function a f (b x)
                                , Sink #(Vector #(n, a)) snk )
                                (Vector #(n, Sink #(b)));
  return error ("splitAllHomogeneousSink not implemented");
endmodule

// splitAllHeterogeneousSource
////////////////////////////////////////////////////////////////////////////////
// XXX TODO XXX
module splitAllHeterogeneousSource #( function a fa (c x)
                                    , function b fb (c x)
                                    , Source #(c) src )
                                    (Tuple2 #(Source #(a), Source #(b)));
  return error ("splitAllHeterogeneousSource not implemented");
endmodule

// splitAllHeterogeneousSink
////////////////////////////////////////////////////////////////////////////////
// XXX TODO XXX
module splitAllHeterogeneousSink #( function c f (a x, b y)
                                  , Sink #(c) snk )
                                  (Tuple2 #(Sink #(a), Sink #(b)));
  return error ("splitAllHeterogeneousSink not implemented");
endmodule

// splitAnyHomogeneousSource
////////////////////////////////////////////////////////////////////////////////
// XXX TODO XXX
module splitAnyHomogeneousSource #( // split transformation
                                    function Maybe #(b) f (a x)
                                    // source to split
                                  , Source #(Vector #(n, a)) src )
  // returned vector of sources
  (Vector #(n, Source #(b)))
  // constraints
  provisos (Bits #(a, a_sz), Bits #(b, b_sz));
  // ressources declaration
  Vector #(n, FIFOF #(b)) ffs <- replicateM (mkBypassFIFOF);
  Vector #(n, Array #(Reg #(Bool))) produced <- replicateM (mkCReg (2, False));
  Source #(Vector #(n, a)) ugSrc <- toUnguardedSource (src, ?);
  // helper functions
  function Bool rIfc1 (Array #(Reg #(Bool)) ifcs) = ifcs[1]._read;
  function Action wIfc1 (Bool x, Array #(Reg #(Bool)) ifcs) =
    ifcs[1]._write (x);
  // derived signals
  Vector #(n, Maybe #(b)) mbs = map (f, ugSrc.peek);
  function fNeedProduce (x) = ugSrc.canPeek && isValid (x);
  Vector #(n, Bool) needProcude = map (fNeedProduce, mbs);
  // individual production rules
  for (Integer i = 0; i < valueOf (n); i = i + 1) begin
    (* fire_when_enabled *)
    rule produce (!produced[i][0] && needProcude[i] && ffs[i].notFull);
      ffs[i].enq (fromMaybe (?, mbs[i]));
      produced[i][0] <= True;
    endrule
  end
  // overall input consumption rule
  function fDropOk (needProd, hasProd) = !needProd || hasProd;
  (* fire_when_enabled *)
  rule dropInput (ugSrc.canPeek && \and (zipWith ( fDropOk
                                                 , needProcude
                                                 , map (rIfc1, produced ))));
    ugSrc.drop;
    mapM_ (wIfc1 (False), produced);
  endrule
  // return interfaces
  return map (toSource, ffs);
endmodule

// splitAnyHomogeneousSink
////////////////////////////////////////////////////////////////////////////////
// XXX TODO XXX
module splitAnyHomogeneousSink #( function b f (Maybe #(a) x)
                                , Sink #(Vector #(n, b)) snk )
                                (Vector #(n, Sink #(a)));
  return error ("splitAnyHomogeneousSink not implemented");
endmodule

// splitAnyHeterogeneousSource
////////////////////////////////////////////////////////////////////////////////
// XXX TODO XXX
module splitAnyHeterogeneousSource #( // splitting transformation for 1st type
                                      function Maybe #(a) fa (c x)
                                      // splitting transformation for 2nd type
                                    , function Maybe #(b) fb (c x)
                                      // source to split
                                    , Source #(c) src )
  // returned sources
  (Tuple2 #(Source #(a), Source #(b)))
  // constraints
  provisos (Bits #(a, a_sz), Bits #(b, b_sz));

  module prepFromSrc #(function Maybe #(t) f (c x))
    (Tuple3 #(Bool, Action, Source #(t))) provisos (Bits #(t, t_sz));
    let ff <- mkBypassFIFOF;
    Reg #(Bool) hasProduced [2] <- mkCReg (2, False);
    let needProcude = src.canPeek && isValid (f (src.peek));
    (* fire_when_enabled *)
    rule produce (!hasProduced[0] && needProcude && ff.notFull);
      ff.enq (fromMaybe (?, f (src.peek)));
      hasProduced[0] <= True;
    endrule
    return tuple3 ( !needProcude || hasProduced[1]
                  , action hasProduced[1] <= False; endaction
                  , toSource (ff) );
  endmodule

  match {.aDropGuard, .aProdAck, .aSrc} <- prepFromSrc (fa);
  match {.bDropGuard, .bProdAck, .bSrc} <- prepFromSrc (fb);

  (* fire_when_enabled *)
  rule dropInput (aDropGuard && bDropGuard);
    src.drop; aProdAck; bProdAck;
  endrule
  return tuple2 (aSrc, bSrc);
endmodule

// splitAnyHeterogeneousSink
////////////////////////////////////////////////////////////////////////////////
// XXX TODO XXX
module splitAnyHeterogeneousSink #( function c f (Maybe #(a) x, Maybe #(b) y)
                                  , Sink #(c) snk )
                                  (Tuple2 #(Sink #(a), Sink #(b)));
  return error ("splitAnyHeterogeneousSink not implemented");
endmodule

// mergeAllHomogeneousSources
////////////////////////////////////////////////////////////////////////////////
// XXX TODO XXX
module mergeAllHomogeneousSources #( function b f (a x)
                                   , Vector #(n, Source #(a)) srcs )
                                   (Source #(Vector #(n, b)));
  return error ("mergeAllHomogeneousSources not implemented");
endmodule

// mergeAllHomogeneousSinks
////////////////////////////////////////////////////////////////////////////////
// XXX TODO XXX
module mergeAllHomogeneousSinks #( function a f (b x)
                                 , Vector #(n, Sink #(a)) snks )
                                 (Sink #(Vector #(n, b)));
  return error ("mergeAllHomogeneousSinks not implemented");
endmodule

// mergeAllHeterogeneousSources
////////////////////////////////////////////////////////////////////////////////
// XXX TODO XXX
function Source #(c) mergeAllHeterogeneousSources ( function c f (a x, b y)
                                                  , Source #(a) aSrc
                                                  , Source #(b) bSrc );
  let newGuard = aSrc.canPeek && bSrc.canPeek;
  return interface Source;
    method canPeek = newGuard;
    method peek if (newGuard) = f (aSrc.peek, bSrc.peek);
    method drop if (newGuard) = action
      aSrc.drop;
      bSrc.drop;
    endaction;
  endinterface;
endfunction

// mergeAllHeterogeneousSinks
////////////////////////////////////////////////////////////////////////////////
// XXX TODO XXX
module mergeAllHeterogeneousSinks #( function a fa (c x)
                                   , function b fb (c x)
                                   , Sink #(a) aSnk
                                   , Sink #(b) bSnk )
                                   (Sink #(c));
  return error ("mergeAllHeterogeneousSinks not implemented");
endmodule

// mergeAnyHomogeneousSources
////////////////////////////////////////////////////////////////////////////////
// Merges a vector of multiple sources of a given type into a single source of
// a vector of a result type. The provided transformation f takes a value of
// Maybe of the initial type (the data produced by an initial source if
// available), and should return a value of the result type (the data to be
// produced in the matching slot of the vector produced by the target source).
// The transformation f is continuously applied to each initial source and is
// passed a Valid element when the source has one available, or Invalid
// otherwise. When any valid element is present, the target source can be
// dropped, and if so, the corresponding initial source(s) is(are) also dropped.
module mergeAnyHomogeneousSources #( // merging transformation
                                     function b f (Maybe #(a) x)
                                     // sources to merge
                                   , Vector #(n, Source #(a)) srcs )
  // returned source
  (Source #(Vector #(n, b)))
  // constraints
  provisos (Bits #(a, a_sz));
  let doDrop <- mkPulseWire;
  let wires <- replicateM (mkDWire (Invalid));
  for (Integer i = 0; i < valueOf (n); i = i + 1) begin
    (* fire_when_enabled *)
    rule wireWrite (srcs[i].canPeek); wires[i] <= Valid (srcs[i].peek); endrule
    (* fire_when_enabled *)
    rule sDrop (doDrop && srcs[i].canPeek); srcs[i].drop; endrule
  end
  function applyCanPeek (x) = x.canPeek;
  let newGuard = \or (map (applyCanPeek, srcs));
  return interface Source;
    method canPeek = newGuard;
    method peek if (newGuard) = map (f, readVReg (wires));
    method drop if (newGuard) = doDrop.send;
  endinterface;
endmodule

// mergeAnyHomogeneousSinks
////////////////////////////////////////////////////////////////////////////////
// XXX TODO XXX
module mergeAnyHomogeneousSinks #( function a f (Maybe #(b) x)
                                 , Vector #(n, Sink #(a)) snks )
                                 (Sink #(Vector #(n, b)));
  return error ("mergeAnyHomogeneousSinks not implemented");
endmodule

// mergeAnyHeterogeneousSources
////////////////////////////////////////////////////////////////////////////////
// Merges two sources of arbitrary types into a single source of a result type.
// The provided transformation f takes a value of Maybe of each of the initial
// types (the data produced by each initial source if available), and should
// return a value of the result type (the data to be produced by the target
// source). The transformation f is continuously applied to the initial sources
// and is passed a Valid element when the matching source has one available, or
// Invalid otherwise. When any valid element is present, the target source can
// be dropped, and if so, the corresponding initial source(s) is(are) also
// dropped.
module mergeAnyHeterogeneousSources #( // merging transformation
                                       function c f (Maybe #(a) x, Maybe #(b) y)
                                       // sources to merge
                                     , Source #(a) aSrc
                                     , Source #(b) bSrc )
  // returned source
  (Source #(c))
  // constraints
  provisos (Bits #(a, a_sz), Bits #(b, b_sz));
  let doDrop <- mkPulseWire;
  module wrapSrc #(Bool dropSrc, Source #(t) src) (Wire #(Maybe #(t)))
    provisos (Bits #(t, t_sz));
    let mWire <- mkDWire (Invalid);
    (* fire_when_enabled *)
    rule mWireWrite (src.canPeek); mWire <= Valid (src.peek); endrule
    (* fire_when_enabled *)
    rule doSrcDrop (dropSrc && src.canPeek); src.drop; endrule
    return mWire;
  endmodule
  let aWire <- wrapSrc (doDrop, aSrc);
  let bWire <- wrapSrc (doDrop, bSrc);
  let newGuard = isValid (aWire) || isValid (bWire);
  return interface Source;
    method canPeek = newGuard;
    method peek if (newGuard) = f (aWire, bWire);
    method drop if (newGuard) = doDrop.send;
  endinterface;
endmodule

// mergeAnyHeterogeneousSinks
////////////////////////////////////////////////////////////////////////////////
// XXX TODO XXX
module mergeAnyHeterogeneousSinks #( function a fa (Maybe #(c) x)
                                   , function b fb (Maybe #(c) x)
                                   , Sink #(a) aSnk
                                   , Sink #(b) bSnk )
                                   (Sink #(c));
  return error ("mergeAnyHeterogeneousSinks not implemented");
endmodule


// Source utilities
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

// Source merge utilities (non-blocking and blocking)
//
// A "non-blocking" merge merges several sources into one even if all argument
// sources do not have data to provide at the same time. The resulting source
// produces data which will contain useful information from *at least one* of
// the initial sources, possibly more.
//
// A "blocking" merge will wait for all initial sources to have available data
// before producing data, and will atomically consume from all initial sources.
// The resulting source will produce data containing information from *all* of
// the initial sources.
////////////////////////////////////////////////////////////////////////////////

module mergeSourcesNonBlocking #(Source #(a) sa, Source #(b) sb)
  (Source #(Tuple2 #(Maybe #(a), Maybe #(b))))
  provisos (Bits #(a, a_sz), Bits #(b, b_sz));
  let src <- mergeAnyHeterogeneousSources (tuple2, sa, sb);
  return src;
endmodule

function Source #(Tuple2 #(a, b)) mergeSourcesBlocking ( Source #(a) sa
                                                       , Source #(b) sb ) =
  mergeAllHeterogeneousSources (tuple2, sa, sb);

function Source #(Tuple2 #(a, b)) mergeSources ( Source #(a) sa
                                               , Source #(b) sb ) =
  mergeSourcesBlocking (sa, sb);

// Source split utilities (non-blocking and blocking)
// On source splits, "non-blocking" is used to refer to the productions of data
// in the returned sources happening as early as possible. The dropping of the
// initial input itself still only happens once all possible productions have
// been resolved.
// A "blocking" source split refers to the productions of data in the returned
// sources happening only when all the returned sources can handle a production
// at once, atomically consuming the incoming data.
////////////////////////////////////////////////////////////////////////////////

module splitSourceBlockingWith #( function a fa (c x)
                                , function b fb (c x)
                                , Source #(c) s )
  (Tuple2 #(Source #(a), Source #(b)))
  provisos (Bits #(a, a_sz), Bits #(b, b_sz));
  let ffa <- mkBypassFIFOF;
  let ffb <- mkBypassFIFOF;
  rule forwardData (s.canPeek && ffa.notFull && ffb.notFull);
    let x <- get (s);
    ffa.enq (fa (x));
    ffb.enq (fb (x));
  endrule
  return tuple2 (toSource (ffa), toSource (ffb));
endmodule

module splitSourceBlocking #(Source #(Tuple2 #(a, b)) s)
                            (Tuple2 #(Source #(a), Source #(b)))
  provisos (Bits #(a, a_sz), Bits #(b, b_sz));
  let res <- splitSourceBlockingWith (tpl_1, tpl_2, s);
  return res;
endmodule

module splitSource #(Source #(Tuple2 #(a, b)) s)
                    (Tuple2 #(Source #(a), Source #(b)))
  provisos (Bits #(a, a_sz), Bits #(b, b_sz));
  let res <- splitSourceBlocking (s);
  return res;
endmodule

// Sink split / merge utilities
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

function Sink #(c) mergeSinksWith ( function a fa (c x)
                                  , function b fb (c x)
                                  , Sink #(a) sa
                                  , Sink #(b) sb );
  let newGuard = sa.canPut && sb.canPut;
  return interface Sink;
    method canPut = newGuard;
    method put (x) if (newGuard) = action
      sa.put(fa (x));
      sb.put(fb (x));
    endaction;
  endinterface;
endfunction

function Sink #(Tuple2 #(a, b)) mergeSinks (Sink #(a) sa, Sink #(b) sb) =
  mergeSinksWith (tpl_1, tpl_2, sa, sb);

module splitSinkWith #(function c f (a x, b y), Sink #(c) s)
                      (Tuple2 #(Sink #(a), Sink #(b)))
  provisos (Bits #(a, a_sz), Bits #(b, b_sz));
  let ffa <- mkBypassFIFOF;
  let ffb <- mkBypassFIFOF;
  rule forwardData;
    s.put (f (ffa.first, ffb.first));
    ffa.deq;
    ffb.deq;
  endrule
  return tuple2 (toSink (ffa), toSink (ffb));
endmodule

module splitSink #(Sink #(Tuple2 #(a, b)) s)
                  (Tuple2 #(Sink #(a), Sink #(b)))
  provisos (Bits #(a, a_sz), Bits #(b, b_sz));
  let res <- splitSinkWith (tuple2, s);
  return res;
endmodule

// Req / Rsp utilities
////////////////////////////////////////////////////////////////////////////////

module mkReqRspPre #( function module #(FIFOF #(rspT)) mkFF
                    , function rspT f (reqT req) )
                    (Tuple2 #(Sink #(reqT), Source #(rspT)));
  let ff <- mkFF;
  return tuple2 (mapSink (f, toSink (ff)), toSource (ff));
endmodule

module mkReqRspPost #( function module #(FIFOF #(reqT)) mkFF
                     , function rspT f (reqT req) )
                     (Tuple2 #(Sink #(reqT), Source #(rspT)));
  let ff <- mkFF;
  return tuple2 (toSink (ff), mapSource (f, toSource (ff)));
endmodule

// debug wrapping
////////////////////////////////////////////////////////////////////////////////
function Source #(t) debugSource (Source #(t) src, Fmt msg)
  provisos (FShow #(t)) =
  onDrop( constFn ($display ( msg
                            , " - Source drop method called - "
                            , fshow (src.peek)))
        , src );

function Sink #(t) debugSink (Sink #(t) snk, Fmt msg) provisos (FShow #(t));
  function f (x) = action
    $display( msg, " - Sink put method called - ", fshow (x));
  endaction;
  return onPut (f, snk);
endfunction

// add a Boolean guard to a Source
////////////////////////////////////////////////////////////////////////////////
function Source #(t) guardSource (Source #(t) raw, Bool block) =
  interface Source;
    method canPeek = raw.canPeek && !block;
    method peek if (!block) = raw.peek;
    method drop if (!block) = raw.drop;
  endinterface;

function Sink #(t) guardSink (Sink #(t) raw, Bool block) = interface Sink;
  method canPut = raw.canPut && !block;
  method put if (!block) = raw.put;
endinterface;

endpackage
