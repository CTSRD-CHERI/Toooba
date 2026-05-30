/*-
 * Copyright (c) 2018 Alexandre Joannou
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

package Dict;

// list of imported packages
import List :: *;
import Monoid :: *;

// list of exported indentifiers
export Dict;
export DictCons(..);
export keys;
export values;
export lookup;
export lookupWith;
export filter;
export insertWith;
export insertMappend;
export insert;
export mergeWith;
export concatWith;
//export collapseWith;

// Dict type
// XXX
// to make Bluespec's type system happy, wrap the following type in a struct...
// typedef List#(Tuple2#(key_t, value_t)) Dict#(type key_t, type value_t);
typedef struct {
  List#(Tuple2#(key_t, value_t)) d;
} Dict#(type key_t, type value_t);

`define DICT_T Dict#(key_t, value_t)
`define DICT_ELEM_T Tuple2#(key_t, value_t)

// dictionary constructor
typeclass DictCons#(type a); a dict; endtypeclass

instance DictCons#(function `DICT_T f(`DICT_ELEM_T e));
  function `DICT_T dict(`DICT_ELEM_T e) = Dict {d: cons(e, Nil)};
endinstance

instance DictCons#(function `DICT_T f(key_t k, value_t v));
  function `DICT_T dict(key_t k, value_t v) = Dict {d: cons(tuple2(k, v), Nil)};
endinstance

instance DictCons#(function `DICT_T f(List#(`DICT_ELEM_T) es));
  function `DICT_T dict(List#(`DICT_ELEM_T) es) = Dict {d: es};
endinstance

// Dictionary inspection
function List#(key_t) keys(`DICT_T d) = map(tpl_1, d.d);
function List#(value_t) values(`DICT_T d) = map(tpl_2, d.d);
function Maybe#(value_t) lookup(key_t k, `DICT_T d) provisos (Eq#(key_t)) =
  List::lookup(k, d.d);

function Maybe#(value_t) lookupWith(function Bool f(key_t k), `DICT_T d);
  function pred(x) = f(tpl_1(x));
  case (find(pred, d.d)) matches
    tagged Valid {.key, .val}: return Valid(val);
    tagged Invalid: return Invalid;
  endcase
endfunction

function `DICT_T filter (function Bool f(`DICT_ELEM_T e), `DICT_T d) =
  dict(List::filter(f, d.d));

// Dictionary insert
function `DICT_T insertWith_(
  function value_t merge(value_t x, value_t y),
  `DICT_T d,
  `DICT_ELEM_T e) provisos (Eq#(key_t)) =
  case (d.d) matches
    tagged Nil: dict(cons(e, d.d));
    .*: if (tpl_1(head(d.d)) == tpl_1(e))
      dict(cons(tuple2(tpl_1(e), merge(tpl_2(head(d.d)), tpl_2(e))), tail(d.d)));
      else dict(cons(head(d.d), insertWith_(merge, dict(tail(d.d)), e).d));
  endcase;

function `DICT_T insertWith(
  function value_t merge(value_t x, value_t y),
  `DICT_T d,
  key_t k,
  value_t v)
  provisos (Eq#(key_t)) = insertWith_(merge, d, tuple2(k, v));

function `DICT_T insertMappend(`DICT_T d, key_t k, value_t v)
  provisos (Eq#(key_t), Monoid#(value_t)) = insertWith(mappend, d, k, v);

function `DICT_T insert(`DICT_T d, key_t k, value_t v)
  provisos (Eq#(key_t)) = insertWith(flip(constFn), d, k, v);

// Dictionary merging
function `DICT_T mergeWith(
  function value_t merge(value_t a, value_t b),
  `DICT_T x,
  `DICT_T y) provisos (Eq#(key_t)) = foldl(insertWith_(merge), x, y.d);

// Dictionary concatenation
function `DICT_T concatWith(
  function value_t concat(value_t a, value_t b),
  List#(`DICT_T) xs) provisos (Eq#(key_t)) =
  foldl(mergeWith(concat), Dict {d: Nil}, xs);

// Dictionary collapsing
/*
function value_t collapseWith(
  function value_t collapse(value_t a, value_t b),
  `DICT_T x,
  value_t e) = foldl(collapse, e, values(x));
function value_t collapseWith(
  `DICT_T x,
  value_t e,
  function value_t collapse(value_t a, value_t b)) provisos (Ord#(key_t));
  function cmp(a, b) = compare(tpl_1(a), tpl_1(b));
  return foldl(collapse, e, map(tpl_2, sortBy(cmp, x.d)));
endfunction
*/

// Dictionary monoid instance
instance Monoid#(`DICT_T) provisos (Eq#(key_t), Monoid#(value_t));
  function mempty = Dict {d: Nil};
  function mappend(x, y) = mergeWith(mappend, x, y);
endinstance

`undef DICT_ELEM_T
`undef DICT_T

endpackage
