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

package Primitives;

import Vector :: *;
import FIFOF :: *;

import Virtualizable :: *;

// un-inhabited type for the purpose of passing type information
////////////////////////////////////////////////////////////////////////////////
typedef struct {} Proxy #(type t);
typedef struct {} NumProxy #(numeric type n);

// haskell monad's return
// (called idM because return is already a keyword)
// (Monad return from Prelude.bs is not accessible?... only on Modules...)
////////////////////////////////////////////////////////////////////////////////
module idM #(t x) (t); return x; endmodule

// cycle counter
////////////////////////////////////////////////////////////////////////////////

module mkCycleCount (ReadOnly #(UInt #(n)));
  // keep track of time
  Reg #(UInt #(n)) cycle <- mkReg (0);
  (* no_implicit_conditions, fire_when_enabled *)
  rule tick; cycle <= cycle + 1; endrule
  return regToReadOnly (cycle);
endmodule

// merge two data chunks according to a mask
////////////////////////////////////////////////////////////////////////////////

function t mergeWithMask (t mask, t x0, t x1) provisos (Bits #(t, t_sz)) =
  unpack ((pack (x0) & ~pack (mask)) | (pack (x1) & pack (mask)));

// merge two data chunks with byte enable
////////////////////////////////////////////////////////////////////////////////

function t mergeWithBE (t_be be, t oldData, t newData)
  provisos ( Bits #(t, t_sz), Bits #(t_be, t_be_sz)
           , Bits #(Vector #(t_be_sz, Bit #(8)), t_sz) );
  Vector #(t_be_sz, Bit #(8)) oldVec = unpack (pack (oldData));
  Vector #(t_be_sz, Bit #(8)) newVec = unpack (pack (newData));
  Vector #(t_be_sz, Bit #(1))  beVec = unpack (pack (be));
  function mux2 (sel, a, b) = (sel == 0) ? a : b;
  return unpack (pack (zipWith3 (mux2, beVec, oldVec, newVec)));
endfunction

// set of integers
////////////////////////////////////////////////////////////////////////////////

interface IntSet #(numeric type memberSz);
  method Action insert (Bit #(memberSz) x);
  method Action delete (Bit #(memberSz) x);
  method Bool member (Bit #(memberSz) x);
  method Bool full;
  method Maybe #(Bit #(memberSz)) findFirstFree;
endinterface

module mkIntSet (IntSet #(memberSz));
  // local definition
  Reg #(Vector #(TExp #(memberSz), Bool)) set <- mkReg (replicate (False));
  Vector #(TExp #(memberSz), PulseWire) insertWire <- replicateM (mkPulseWire);
  Vector #(TExp #(memberSz), PulseWire) deleteWire <- replicateM (mkPulseWire);

  // update rule
  (* fire_when_enabled, no_implicit_conditions *)
  rule update;
    function Bool readPulseWire (PulseWire pw) = pw._read;
    function readVPulseWire (vPulseWire) = map (readPulseWire, vPulseWire);
    function f (old, doIns, doDel) = (doIns == doDel) ? old : doIns;
    set <= zipWith3 ( f, set
                    , readVPulseWire (insertWire)
                    , readVPulseWire (deleteWire) );
  endrule

  function isFalse (x) = x == False;
  // interface
  method insert (x) = insertWire[x].send;
  method delete (x) = deleteWire[x].send;
  method member (x) = set[x];
  method full = \and (set);
  method findFirstFree = fmap (pack, findIndex (isFalse, set));
endmodule

// table of registrations
////////////////////////////////////////////////////////////////////////////////

interface RegistrationTable #(type data_t, type key_t);
  method ActionValue #(Maybe #(key_t)) registerData (data_t d);
  method ActionValue #(Maybe #(data_t)) deRegisterKey (key_t t);
  method Maybe #(data_t) dataLookup (key_t t);
  method Maybe #(key_t) keyLookup (data_t d);
endinterface

instance Virtualizable #(RegistrationTable #(data_t, key_t));
  module virtualize #(RegistrationTable #(data_t, key_t) x, Integer n)
                      (Array #(RegistrationTable #(data_t, key_t)));
    RegistrationTable #(data_t, key_t) ifc[n];

    for (Integer i = 0; i < n; i = i + 1) begin
      ifc[i] = interface RegistrationTable #(data_t, key_t);
        method registerData = x.registerData;
        method deRegisterKey = x.deRegisterKey;
        method dataLookup = x.dataLookup;
        method keyLookup = x.keyLookup;
      endinterface;
    end

    return ifc;
  endmodule
endinstance

module mkFullRegistrationTable
  // received parameter
  #(parameter NumProxy #(maxCnt) proxyMaxCnt)
  // returned interface
  (RegistrationTable #(data_t, key_t))
  // type constraints
  provisos ( // usage contraints
             Bits #(key_t, key_sz)
           , Add #(_, TLog #(TExp #(key_sz)), key_sz) // really...
           , Bits #(data_t, data_sz)
           , Eq #(data_t)
            // local aliases
           , Alias #(idx_t, UInt #(TLog #(nbEntries)))
           );
  NumProxy #(TExp #(key_sz)) proxyNbEntries = ?;
  let ifc <- mkRegistrationTable (proxyNbEntries, proxyMaxCnt);
  return ifc;
endmodule

module mkRegistrationTable
  // received parameter
  #( parameter NumProxy #(nbEntries) _proxy0
   , parameter NumProxy #(maxCnt) _proxy1 )
  // returned interface
  (RegistrationTable #(data_t, key_t))
  // type constraints
  provisos ( // usage contraints
             Bits #(key_t, key_sz)
           , Add#(_, TLog #(nbEntries), key_sz)
           , Bits #(data_t, data_sz)
           , Eq #(data_t)
            // local aliases
           , Alias #(idx_t, UInt #(TLog #(nbEntries)))
           );

  // Local definitions
  ////////////////////

  // vector of registration entries
  // (Note: an entry with a count of 0 is an available entry)
  Vector #(nbEntries, Reg #(data_t)) entries <- replicateM (mkRegU);
  Reg #(Vector #(nbEntries, Bool)) allocated[2] <- mkCReg(2, replicate(False));
  Vector #(nbEntries, data_t) entriesRead = readVReg (entries);
  Vector #(nbEntries, FIFOF #(Bit #(0)))
    counters <- replicateM (mkUGSizedFIFOF (valueOf (maxCnt)));

  function idx_t key2idx (key_t k) = unpack (truncate (pack (k)));
  function key_t idx2key (idx_t i) = unpack (zeroExtend (pack (i)));
  function dLookup (k) =
    (counters[key2idx (k)].notEmpty) ? tagged Valid entriesRead[key2idx (k)]
                                     : Invalid;

  // Rules
  ////////
  (* fire_when_enabled *)
  rule garbageCollect (\and (allocated[0]));
    function notEmpty (ff) = ff.notEmpty;
    allocated[0] <= map (notEmpty, counters);
  endrule

  // Interface
  ////////////

  // To create a new registration for a given piece of data:
  // - we establish if it is already associated with existing registrations
  //   * if it is, and if there is room for another registration in the already
  //     allocated entry, we increment the count of the entry
  //   * if the data is not already associated with an existing registration, if
  //     there is an available entry, we claim the entry for our data and return
  //     its index as a key
  // On successful registration, we return a Valid result containing the key
  // associated with the registration
  // An Invalid return value signifies that no action took place
  method registerData (d) = actionvalue
    let mKey = Invalid; // prepare an Invalid return value by default
    let mIdx = findElem (d, entriesRead);
    case (mIdx) matches
      // We matched an existing registration (or, we might have matched an
      // empty/available registration slot with the same old data, which is in
      // fact ok to use)
      tagged Valid .idx: begin
        // for not already full entries only
        if (counters[idx].notFull) begin
          // update the existing entry
          counters[idx].enq (?);
          // return the registration index as the key
          mKey = tagged Valid idx2key (idx);
        end
      end
      // There is no existing matching registration, look for an available entry
      default: begin
        function isAvailable (args);
          match {.ff, .alloc} = args;
          return !ff.notEmpty && !alloc;
        endfunction
        case (findIndex (isAvailable, zip (counters, allocated[1]))) matches
          tagged Valid .idx: begin
            // allocate the new registration by updating the selected entry
            entries[idx] <= d;
            allocated[1][idx] <= True;
            counters[idx].enq (?);
            mKey = tagged Valid idx2key (idx); // return the new key
          end
        endcase
      end
    endcase
    $display("RegistrationTable: 0x%x -> %b 0x%x", d, isValid(mKey), mKey.Valid);
    return mKey;
  endactionvalue;
  // To record a de-registration on a given key:
  // - we look for an existing entry for the given key
  // - we update the entry decrementing its counter
  // On successful de-registration, we return a Valid result containing the data
  // associated with the registration being removed
  // An Invalid return value signifies that no action took place
  method deRegisterKey (k) = actionvalue
    if (counters[key2idx (k)].notEmpty) counters[key2idx (k)].deq;
    return dLookup (k);
  endactionvalue;
  // lookup the data associated with a key
  method dataLookup = dLookup;
  // lookup the key associated with a piece of data
  method keyLookup (d);
    if (findElem (d, entriesRead) matches tagged Valid .i)
      return tagged Valid idx2key (i);
    else return Invalid;
  endmethod

endmodule

endpackage
