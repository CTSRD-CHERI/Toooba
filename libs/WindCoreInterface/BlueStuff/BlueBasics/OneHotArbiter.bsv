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

package OneHotArbiter;

import FIFOF :: *;
import Printf :: *;

import List :: *;
import ListExtra :: *;
import SourceSink :: *;

// Arbitrable typeclass and instances

typeclass Arbitrable#(type a);
  function Bool isRequesting(a x);
endtypeclass

instance Arbitrable#(Bool);
  function isRequesting(x) = x;
endinstance

instance Arbitrable#(FIFOF#(t));
  function isRequesting(x) = x.notEmpty;
endinstance

instance Arbitrable#(Source#(t));
  function isRequesting(x) = x.canPeek;
endinstance

// Arbiter interface

interface OneHotArbiter;
  method ActionValue#(List#(Bool)) next();
endinterface

// Arbiter module

module mkFairOneHotArbiter#(List#(t) xs) (OneHotArbiter) provisos (Arbitrable#(t));
  // assertion
  Integer n = length(xs);
  if (n < 1)
    error(sprintf("mkFairOneHotArbiter can't arbitrate less than 1 participant (%0d given)", n));
  // internal state
  //////////////////////////////////////////////////////////////////////////////
  Reg#(Bool)          firstHot <- mkReg(True);
  List#(Reg#(Bool)) lastSelect <- replicateM(n-1, mkReg(False));
  lastSelect = append(lastSelect, cons(firstHot, Nil));
  // arbitration
  //////////////////////////////////////////////////////////////////////////////
  List#(Bool) pending = map(isRequesting, xs);
  method next if (\or (pending)) = actionvalue
    // get lastSel as a List#(Bool)
    List#(Bool) lastSel = map(readReg, lastSelect);
    // rotate the list of participants to put last elected to the end
    List#(Bool) searchList = oneHotRotateBy(lastSel, pending);
    // elect the next participant
    List#(Bool) newSel = lastSel;
    Maybe#(List#(Bool)) elected = firstHotToOneHot(searchList);
    if (isValid(elected)) newSel = oneHotRotateRBy(lastSel, elected.Valid);
    else begin // This should never happen
      $display("mkFairOneHotArbiter: next method should not be run with no pending request");
      $finish(0);
    end
    // update lastSel
    function Action updtReg(Reg#(Bool) r, Bool v) = action r <= v; endaction;
    List#(Action) updts = zipWith(updtReg, lastSelect, newSel);
    for (Integer i = 0; i < length(updts); i = i + 1) updts[i];
    // return new elected participant
    return newSel;
  endactionvalue;
endmodule

module mkStaticOneHotArbiter#(List#(t) xs) (OneHotArbiter) provisos (Arbitrable#(t));
  Integer n = length(xs);
  if (n < 1)
    error(sprintf("mkStaticOneHotArbiter can't arbitrate less than 1 participant (%0d given)", n));
  List#(Bool) pending = map(isRequesting, xs);
  method next if (\or (pending)) = actionvalue
    Bool found = False;
    List#(Bool) newSel = replicate (n, False);
    for (Integer i = 0; i < n; i = i + 1) if (pending[i] && !found) begin
      newSel[i] = True;
      found = True;
    end
    if (!found) begin
      $display("mkStaticOneHotArbiter: next method should not be run with no pending request");
      $finish(0);
    end
    return newSel;
  endactionvalue;
endmodule

endpackage
