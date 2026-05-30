/*-
 * Copyright (c) 2020 Jonas Fiala
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

package SpecialWires; 

export mkDCWire;
export mkCDWire;

export mkDWireOR;
export mkWireOP;

import List :: *;

// Default Concurent Wire, less logical name for CDWire
module mkDCWire #( Integer n
                 , a_bits init
  ) (Array #(Wire #(a_bits))) provisos (
    Bits #(a_bits, bit_size));

  let ifc <- mkCDWire (n, init);
  return ifc;
endmodule

// Concurent DWire, similar to CReg but for DWire
module mkCDWire #( Integer n
                 , a_bits init
  ) (Array #(Wire #(a_bits))) provisos (
    Bits #(a_bits, bit_size));

  if (n < 0) error (quote ("mkCDWire") + " cannot have a negative number of ports");

  Wire#(a_bits) ifc[n];
  List #(RWire #(a_bits)) newVal <- replicateM (n, mkRWire);
  List #(Wire #(a_bits)) prevVal <- replicateM (n, mkWire);
  if (n > 0) rule defVal; prevVal[0] <= init; endrule
  for (Integer i = 0; i < n; i = i + 1) begin
    a_bits readVal = fromMaybe (prevVal[i], newVal[i].wget);
    if (i < n-1) rule propagateVal; prevVal[i+1] <= readVal; endrule
    ifc[i] = interface Wire;
      method _write = newVal[i].wset;
      method _read  = readVal;
    endinterface;
  end
  return ifc;
endmodule

// DWire where all writes are OR'd together
// Useful when setting fields of a Struct in
// different rules
module mkDWireOR #( Integer n
                  , a_bits init
  ) (Array #(Wire #(a_bits))) provisos (
    Bits #(a_bits, bit_size));

  let ifc <- mkWireOP (n, mkDWire (init), \| );
  return ifc;
endmodule

// Use this for OPs on Bits
// Force the op to be on Bit #(w) so that when passing an op on Bits the compiler won't
// complain about the op being of ambiguous type
module mkWireOP #( Integer n
                 , function module #(Wire #(a_bits)) wire_module
                 , function Bit #(bit_size) op (Bit #(bit_size) arg1, Bit #(bit_size) arg2)
  ) (Array #(Wire #(a_bits))) provisos (
    Bits #(a_bits, bit_size));

    let ifc <- mkWireOP_Core (n, wire_module, op);
    return ifc;
endmodule

// NOTE: values are reduced in a binary tree-like structure
//       so beware if op is not associative or commutative
// Only useful in rare cases when using some strange 'op'
// Most generic version, does all of the work for the wrappers
// To use with a generic Bits op (eg \|), must define helper fn. Eg:
// function Bit #(n) or_fn (Bit #(n) arg1, Bit #(n) arg2) = arg1 | arg2;
module mkWireOP_Core #( Integer n
                      , function module #(Wire #(a_bits)) wire_module
                      , function b_bits op (c_bits arg1, d_bits arg2)
  ) (Array #(Wire #(a_bits))) provisos (
    Bits #(a_bits, bit_size)
  , Bits #(b_bits, bit_size)
  , Bits #(c_bits, bit_size)
  , Bits #(d_bits, bit_size));

  if (n < 0) error (quote ("mkWireOP") + " cannot have a negative number of ports");

  function Bit #(bit_size) op_b (Bit #(bit_size) arg1_b, Bit #(bit_size) arg2_b) =
    pack (op (unpack (arg1_b), unpack (arg2_b)));
  
  List #(Wire #(a_bits)) wires <- replicateM (n, wire_module);
  let bit_wires = map (compose (pack, readReg), wires);
  a_bits op_read = unpack (fold (op_b, bit_wires));

  Wire#(a_bits) ifc[n];
  for (Integer i = 0; i < n; i = i + 1) begin
    ifc[i] = interface Wire;
      method _read = op_read;
      method _write = writeReg (wires[i]);
    endinterface;
  end
  return ifc;
endmodule

endpackage
