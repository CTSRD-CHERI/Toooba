/*-
 * Copyright (c) 2018-2022 Alexandre Joannou
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

package ListExtra;

import Printf :: *;

import List :: *;

export list;
export MkList;
export splitAt;
export concatMap;
export rotateBy;
export rotateLBy;
export rotateRBy;
export bitToList;
export listToBit;
export oneHotList;
export oneHotRotateBy;
export oneHotRotateLBy;
export oneHotRotateRBy;
export firstHotToOneHot;
export findOneHotWith;

// Nice friendly list constructor lifted from Bluecheck's sources:
// https://github.com/CTSRD-CHERI/bluecheck.git
////////////////////////////////////////////////////////////////////////////////

typeclass MkList #(type a, type b) dependencies (a determines b);
  function a mkList (List #(b) acc);
endtypeclass

instance MkList #(List #(b), b);
  function List #(b) mkList (List #(b) acc) = List::reverse (acc);
endinstance

instance MkList #(function a f (b val), b) provisos (MkList #(a, b));
  function mkList (acc, val) = mkList (Cons (val, acc));
endinstance

function a list() provisos (MkList #(a, b));
  return mkList (Nil);
endfunction

// basic utility functions

function Tuple2 #(List #(a), List #(a)) splitAt (Integer n, List #(a) xs) =
  tuple2 (take (n, xs), drop (n, xs));

function List #(a) concatMap (function List #(a) f (a x), List #(a) xs) =
  concat (map (f, xs));

// Note: the rotate functions in this file follow the convention used by
// the BSV reference guide - that is, rotating "left" means rotating elements
// towards lower indices, and rotating "right" means rotating elements towards
// higher indices
function List #(a) rotateL (List #(a) xs) = rotate(xs);

//function List#(a) rotateLBy(Integer n, List#(a) xs) =
//  append(drop(n, xs), take(n, xs));
function List#(a) rotateLBy(Integer n, List#(a) xs);
  for (Integer i = 0; i < n; i = i + 1) xs = rotateL(xs);
  return xs;
endfunction

function List#(a) rotateBy(Integer n, List#(a) xs) = rotateLBy (n, xs);

function List#(a) rotateRBy(Integer n, List#(a) xs) =
  reverse(rotateLBy(n, reverse(xs)));

function List #(Bool) bitToList (Bit #(n) x);
  List #(Bool) outList = Nil;
  for (Integer i = 0; i < valueOf (n); i = i + 1)
    outList = cons (unpack (x[i]), outList);
  return reverse (outList);
endfunction

function Bit #(n) listToBit (List #(Bool) x);
  Bit #(n) outBit = 0;
  Integer len = length (x);
  for (Integer i = 0; i < len; i = i + 1) begin
    outBit[i] = pack (head (x));
    x = tail (x);
  end
  return outBit;
endfunction

function List #(Bool) oneHotList (Integer sz, Integer idx) =
  rotateRBy (idx, cons (True, replicate (sz - 1, False)));

//function List#(a) oneHotRotateLBy(List#(Bool) xs, List#(a) ys)
//  provisos (Bits#(a, a_sz));
//  Integer n = length(xs);
//  List#(a) outList = Nil;
//  for (Integer i = 0; i < n; i = i + 1) begin
//    xs = rotateR (xs);
//    outList = cons (oneHotSelect (xs, ys), outList);
//  end
//  return reverse (outList);
//endfunction

// There are two interpretations for this function:
//  * If xs is taken to be an integer which is encoded in a one-hot list (where
//    a True value in index 0 indicates an integer value of 1), this function
//    will rotate ys left by the integer xs.
//  * If xs is taken to be a simple one-hot List of Bools, this function will
//    rotate ys such that the last element of the returned List will be the one
//    which in the input has the same index as the True value in xs.
function List#(a) oneHotRotateLBy(List#(Bool) xs, List#(a) ys)
  provisos (Bits#(a, a_sz));
  Integer n = length(xs);
  Integer r = 0;
  for (Integer i = 0; i < n; i = i + 1) if (xs[i]) r = i + 1;
  return rotateLBy(r, ys);
endfunction

function List#(a) oneHotRotateBy(List#(Bool) xs, List#(a) ys)
  provisos (Bits#(a, a_sz)) = oneHotRotateLBy (xs, ys);

// The inverse of oneHotRotateLBy
// There are two interpretations for this function, as with oneHotRotateLBy:
//  * When xs encodes an integer, we rotate to the right by the input integer
//    xs
//  * When xs does not encode an integer, we rotate such that the element at
//    the end of ys is moved to have the same index as the True value in the
//    one-hot xs
function List#(a) oneHotRotateRBy(List#(Bool) xs, List#(a) ys)
  provisos (Bits#(a, a_sz)) = reverse(oneHotRotateLBy(xs, reverse(ys)));

function Maybe #(List #(Bool)) firstHotToOneHot (List #(Bool) xs);
  List #(Bool) outList = Nil;
  Bool found = False;
  Integer n = length (xs);
  for (Integer i = 0; i < n; i = i + 1) begin
    Bool elem = head (xs);
    xs = tail (xs);
    outList = cons ((!found) ? elem : False, outList);
    if (elem) found = True;
  end
  return (found) ? Valid (reverse (outList)) : Invalid;
endfunction

function Maybe #(List #(Bool)) findOneHotWith ( function Bool p (t x)
                                              , List #(t) xs) =
  firstHotToOneHot (map (p, xs));

endpackage
