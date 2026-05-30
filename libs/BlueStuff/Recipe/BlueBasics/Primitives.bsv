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

// un-inhabited type for the purpose of passing type information
////////////////////////////////////////////////////////////////////////////////
typedef struct {} Proxy #(type t);
typedef struct {} NumProxy #(numeric type n);

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

// TODO
// decouple state update from the methods to tackle potential method conflicts

module mkRegistrationTable
  // received parameter
  #( parameter NumProxy #(nbEntries) _proxy0
   , parameter NumProxy #(regsCntSz) _proxy1 )
  // returned interface
  (RegistrationTable #(data_t, key_t))
  // type constraints
  provisos ( // usage contraints
             Bits #(key_t, key_sz)
           , Bits #(data_t, data_sz)
           , Eq #(key_t)
           , Eq #(data_t)
             // local aliases
           , Alias #(cnt_t, Bit #(regsCntSz))
           , Alias #(entry_t, Tuple3 #(key_t, data_t, cnt_t)) );

  // Local definitions
  ////////////////////

  // vector of registration entries
  // (Note: an entry with a count of 0 is an available entry)
  Vector #(nbEntries, Reg #(entry_t))
    entries <- replicateM (mkReg (tuple3 (?, ?, 0)));
  Vector #(nbEntries, entry_t) entriesRead = readVReg (entries);

  // set of tracked keys
  IntSet #(key_sz) keySet <- mkIntSet;

  // entry querry functions
  function Bool matchKey   (key_t k, entry_t e) = tpl_1 (e) == k;
  function Bool matchData (data_t d, entry_t e) = tpl_2 (e) == d;
  function Bool matchCnt   (cnt_t c, entry_t e) = tpl_3 (e) == c;

  // Interface
  ////////////

  // To create a new registration for a given piece of data:
  // - we establish if it is already associated with existing registrations
  //   * if it is, and if there is room for another registration in the already
  //     allocated entry, we increment the count of the entry
  //   * if the data is not already associated with an existing registration, if
  //     there is an available entry and an available key, we claim the entry
  //     with the (data, key) pair and an initial count of 1, and we insert the
  //     key in the tracked key set
  // On successful registration, we return a Valid result containing the key
  // associated with the registration
  // An Invalid return value signifies that no action took place
  method registerData (d) = actionvalue
    let mKey = Invalid; // prepare an Invalid return value by default
    let mIdx = findIndex (matchData (d), entriesRead);
    case (mIdx) matches
      // (Note: could match an empty/available registration slot, which is OK)
      tagged Valid .idx: begin
        match {.eKey, .eData, .eCnt} = entriesRead[idx];
        // for not already full entries only
        if (eCnt != ~0) begin
          // update the existing entry
          entries[idx] <= tuple3 (eKey, eData, eCnt + 1);
          mKey = tagged Valid eKey; // return the existing key
        end
      end
      default: begin // there is no existing matching registration, look for an
                     // available empty entry
        case (findIndex (matchCnt (0), entriesRead)) matches
          tagged Valid .idx: begin
            case (keySet.findFirstFree) matches // look for an available key
              tagged Valid .rawKey: begin
                let key = unpack (rawKey);
                // allocate the new registration by updating the selected entry
                entries[idx] <= tuple3 (key, d, 1);
                keySet.insert (key); // insert the new key in the key set
                mKey = tagged Valid key; // return the new key
              end
            endcase
          end
        endcase
      end
    endcase
    return mKey;
  endactionvalue;
  // To record a de-registration on a given key:
  // - we look for an existing entry with the same key
  // - we update the entry decrementing its counter
  // - if it was the last registration in the entry, we delete the key from
  //   the tracked key set
  // On successful de-registration, we return a Valid result containing the data
  // associated with the registration being removed
  // An Invalid return value signifies that no action took place
  method deRegisterKey (k) = actionvalue
    let mData = Invalid; // prepare an Invalid return value by default
    let mIdx = findIndex (matchKey (k), entriesRead);
    case (mIdx) matches
      tagged Valid .idx: begin
        match {.eKey, .eData, .eCnt} = entriesRead[idx];
        if (eCnt > 0) begin // for non-empty entries only
          // update the existing entry
          entries[idx] <= tuple3 (eKey, eData, eCnt - 1);
          if (eCnt == 1) // for last de-registration
            keySet.delete (pack (eKey)); // delete from tracked key set
          mData = tagged Valid eData; // return the de-registered data
        end
      end
    endcase
    return mData;
  endactionvalue;
  // lookup the data associated with a key
  method dataLookup (k) = fmap (tpl_2, find (matchKey (k), entriesRead));
  // lookup the key associated with a piece of data
  method keyLookup (d) = fmap (tpl_1, find (matchData (d), entriesRead));

endmodule

endpackage
