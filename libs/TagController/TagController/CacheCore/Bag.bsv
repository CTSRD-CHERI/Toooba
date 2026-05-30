/*-
 * Copyright (c) 2014 Matthew Naylor
 * Copyright (c) 2016-2018 Jonathan Woodruff
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-10-C-0237
 * ("CTSRD"), as part of the DARPA CRASH research programme.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249
 * ("MRC2"), as part of the DARPA MRC research programme.
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

import Debug :: *;
import Vector :: *;
import VnD :: *;
import FF :: *;

typedef struct {
  keyType key;
  datType dat;
} Entry#(type keyType, type datType) deriving (Bits, Eq, Bounded, FShow);

interface Bag#(numeric type numElems, type keyType, type datType);
  method VnD#(datType)   isMember(keyType x);
  method Bool            dataMatch(datType x);
  method Action          insert(keyType x, datType d);
  method Action          update(keyType x, datType d);
  method Bool            full;
  method Bool            nextFull;
  method Bool            empty;
  method Action          remove(keyType x);
  method VnD#(keyType)   nextKey();
  method VnD#(datType)   nextData();
  method Action          iterateNext();
endinterface

module mkSmallBag (Bag#(numElems, keyType, datType))
  provisos ( Bits#(keyType, keyTypeSize)
           , Bits#(datType, datTypeSize)
           , Eq#(keyType)
           , Eq#(datType)
           , FShow#(VnD#(Bag::Entry#(keyType, datType))));

  // A small bag of elements, stored in registers
  Reg#(Vector#(numElems, VnD#(Entry#(keyType, datType)))) bag <-
    mkReg(replicate(VnD{v: False, d: ?}));

  // An item to be inserted
  Wire#(VnD#(Entry#(keyType, datType))) insertItem <- mkDWire(VnD{v: False, d: ?});

  // An item to be updated (ignore valid)
  Wire#(VnD#(Entry#(keyType, datType))) updateItem <- mkDWire(VnD{v: False, d: ?});

  // An item to be removed
  Wire#(VnD#(keyType)) removeItem <- mkDWire(VnD{v: False, d: ?});

  Reg#(Bit#(TLog#(numElems))) nextValidKeyReg <- mkRegU;
  Wire#(Bool) iterateNextKeyWire <- mkDWire(False);

  function Bool valid(VnD#(data_t) val) = val.v;
  function Bool notValid(VnD#(data_t) val) = !val.v;

  rule updateBag;
    Bool inserted = False;
    Integer insert = 0;
    Vector#(numElems, VnD#(Entry#(keyType, datType))) newBag = bag;
    for (Integer i = 0; i < valueOf(numElems); i=i+1) begin
      // Current behaviour is: remove item, and then insert.
      if (removeItem.v && bag[i].d.key == removeItem.d)
        newBag[i].v = False;
      if (updateItem.v && bag[i].d.key == updateItem.d.key)
        newBag[i].d.dat = updateItem.d.dat;
      if (insertItem.v && bag[i].d.key == insertItem.d.key) begin
        if (!inserted) newBag[i].v = True;
        newBag[i].d.dat = insertItem.d.dat;
        inserted = True;
      end
      // Make sure this check reflects a concurrant invalidate.
      if (!newBag[i].v) insert = i;
    end
    // If it hasn't been inserted, put it in an empty spot.
    // Trust that they didn't insert when full.
    if (insertItem.v && !inserted) newBag[insert] = insertItem;
    bag <= newBag;

    if (!newBag[nextValidKeyReg].v || iterateNextKeyWire) begin
      Bit#(TLog#(numElems)) key = 0;
      for (Integer i = 0; i < valueOf(numElems); i=i+1) begin
        Bit#(TLog#(numElems)) idx = nextValidKeyReg + fromInteger(i);
        if (newBag[idx].v) key = idx;
      end
      nextValidKeyReg <= key;
      if (!newBag[key].v && !all(notValid, newBag)) panic($display("Panic! Returning invalid element for next when not empty!"));
    end
  endrule

  method VnD#(datType) isMember(keyType x);
    VnD#(datType) ret = VnD{v: False, d: ?};
    for (Integer i = 0; i < valueOf(numElems); i=i+1) begin
      if (bag[i].v && bag[i].d.key == x)
        ret = VnD{v: True, d: bag[i].d.dat};
    end
    return ret;
  endmethod

  method Bool dataMatch(datType x);
    Bool ret = False;
    for (Integer i = 0; i < valueOf(numElems); i=i+1) begin
      if (bag[i].v && bag[i].d.dat == x)
        ret = True;
    end
    return ret;
  endmethod

  method Action insert(keyType x, datType d);
    insertItem <= VnD{v: True, d: Entry{key: x, dat: d}};
  endmethod

  method Action update(keyType x, datType d);
    updateItem <= VnD{v: True, d: Entry{key: x, dat: d}};
  endmethod

  method Bool full;
    return all(valid, bag);
  endmethod

  method Bool nextFull;
    return all(valid, bag) && !removeItem.v;
  endmethod

  method Bool empty;
    return all(notValid, bag);
  endmethod

  method Action remove(keyType x);
    removeItem <= VnD{v: True, d: x};
  endmethod

  method VnD#(keyType) nextKey() = VnD{v: bag[nextValidKeyReg].v, d: bag[nextValidKeyReg].d.key};
  method VnD#(datType) nextData() = VnD{v: bag[nextValidKeyReg].v, d: bag[nextValidKeyReg].d.dat};
  method Action iterateNext();
    iterateNextKeyWire <= True;
  endmethod

endmodule

interface FFBag#(numeric type numElems, type keyType, type datType, numeric type depth);
  method Action                         enq(keyType x, datType d);
  method VnD#(datType)                  first(keyType x);
  method Action                         deq(keyType x);
  method Bool                           full;
  method VnD#(Entry#(keyType, datType)) searchFirsts(function Bool p (datType x));
endinterface

module mkFFBag (FFBag#(numElems, keyType, datType, depth))
  provisos ( Bits#(keyType, keyTypeSize)
           , Bits#(datType, datTypeSize)
           , Eq#(keyType)
           , Eq#(datType)
           , FShow#(VnD#(Bag::Entry#(keyType, datType)))
           , Log#(numElems, indexSize));

  // A small bag of elements, stored in registers
  Vector#(numElems, FF#(Entry#(keyType, datType), depth))  fifos <- replicateM(mkUGFF());

  function Bool notEmpty(FF#(Entry#(keyType, datType), depth) f) = f.notEmpty;
  function Bool empty(FF#(Entry#(keyType, datType), depth) f) = !f.notEmpty;
  function Bool isFull(FF#(Entry#(keyType, datType), depth) f) = !f.notFull;

  Bool all_assigned = all(notEmpty, fifos);
  Maybe#(UInt#(TLog#(numElems))) nextEmpty = findIndex(empty, fifos);

  function VnD#(UInt#(indexSize)) matchIdx(keyType key);
    function Bool is_match(FF#(Entry#(keyType, datType), depth) f) = f.notEmpty && (f.first.key==key);
    Maybe#(UInt#(indexSize)) mIdx = findIndex(is_match, fifos);
    return VnD{v: isValid(mIdx), d: fromMaybe(?, mIdx)};
  endfunction

  method Action enq(keyType key, datType d);
    let vndIdx = matchIdx(key);
    if (vndIdx.v) begin
      fifos[vndIdx.d].enq(Entry{key: key, dat: d});
    end else if (nextEmpty matches tagged Valid .idx) begin
      fifos[idx].enq(Entry{key: key, dat: d});
    end else panic($display("Panic! Enqued new key with no empty FIFOs!"));
  endmethod

  method VnD#(datType) first(keyType key);
    let vndIdx = matchIdx(key);
    return VnD{v: vndIdx.v, d: fifos[vndIdx.d].first.dat};
  endmethod

  method Action deq(keyType key);
    let vndIdx = matchIdx(key);
    if (!vndIdx.v) panic($display("Panic!  Deq called on fifo ID that is not present"));
    fifos[vndIdx.d].deq;
  endmethod

  method VnD#(Entry#(keyType, datType)) searchFirsts(function Bool p (datType x));
    function VnD#(Entry#(keyType, datType)) fst (FF#(Entry#(keyType, datType), depth) f) = VnD{v: f.notEmpty, d: f.first};
    function pV (vnd) = vnd.v && p(vnd.d.dat);
    let res = find (pV, map(fst, fifos));
    return VnD {v: res matches tagged Valid ._ ? True : False, d: res.Valid.d};
  endmethod

  method Bool full = (any(isFull, fifos) || all_assigned);

endmodule
