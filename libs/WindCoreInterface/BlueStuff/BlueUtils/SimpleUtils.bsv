/*-
 * Copyright (c) 2018-2021 Alexandre Joannou
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

import SpecialWires :: *;

import Vector :: *;
import ConfigReg :: *;
import Printf :: *;

// Architectural state helpers
////////////////////////////////////////////////////////////////////////////////

// Architectural register with a commit method separate from the write
interface ArchReg#(type t);
  method t _read;
  method Action _write (t x);
  interface WriteOnly#(t) early;
  interface Reg#(t) late;
  method Bool needCommit;
  method t commitVal;
  method Action commit;
endinterface
module mkArchReg#(t resetVal) (ArchReg#(t)) provisos (Bits#(t, n));
  Reg#(t)         arch   <- mkConfigReg(resetVal);
  Reg#(Maybe#(t)) tmp[4] <- mkConfigCReg(4, Invalid);
  method     _read = arch._read;
  method _write(x) = tmp[1]._write(Valid(x));
  interface WriteOnly early;
    method _write(x) = tmp[0]._write(Valid(x));
  endinterface
  interface Reg late;
    method     _read = isValid(tmp[2]._read) ? tmp[2]._read.Valid : arch._read;
    method _write(x) = tmp[2]._write(Valid(x));
  endinterface
  method needCommit = isValid(tmp[3]._read);
  method  commitVal = isValid(tmp[3]._read) ? tmp[3]._read.Valid : arch._read;
  method commit = action if (isValid(tmp[3]._read)) begin
    arch   <= tmp[3]._read.Valid;
    tmp[3] <= Invalid;
  end endaction;
endmodule
module mkROArchReg#(t resetVal) (ArchReg#(t)) provisos (Bits#(t, n));
  ArchReg#(t)     arch   <- mkArchReg(resetVal);
  method  _read = arch._read;
  method _write = arch._write;
  interface early = arch.early;
  interface  late = arch.late;
  method needCommit = arch.needCommit;
  method  commitVal = resetVal;
  method     commit = noAction;
endmodule

// Architectural register File
interface ArchRegFile#(numeric type n, type a);
  interface Vector#(n, ArchReg#(a)) r;
  method Action commit;
  //method Bit#(TLog#(n)) rs1_idx;
  //method Bit#(TLog#(n)) rs2_idx;
  method Bit#(TLog#(n)) rd_idx;
  //method a rs1_old_val;
  //method a rs2_old_val;
  method a rd_old_val;
  method a rd_new_val;
endinterface
// Register file with read-only 0 register
module mkRegFileInitZ#(a zeroVal, a initVal)(ArchRegFile#(n, a)) provisos (
    Bits#(a, a_sz)
  );
  // the register file
  ArchReg#(a) r0 <- mkROArchReg(zeroVal);
  Vector#(TSub#(n, 1), ArchReg#(a)) rx <- replicateM(mkArchReg(initVal));
  Vector#(n, ArchReg#(a)) rf = cons(r0, rx);
  // reporting behaviour
  Wire#(Bit#(TLog#(n))) rd_idx_w <- mkWire;
  rule find_rd;
    Integer tmp = 0;
    for (Integer i = 0; i < valueOf(n); i = i + 1)
      if (rf[i].needCommit) tmp = i;
    rd_idx_w <= fromInteger(tmp);
  endrule
  // interface
  interface r = rf;
  method commit = action for (Integer i = 0; i < valueOf(n); i = i + 1)
    rf[i].commit;
  endaction;
  method rd_idx = rd_idx_w;
  method rd_old_val = rf[rd_idx_w]._read;
  method rd_new_val = rf[rd_idx_w].commitVal;
endmodule
module mkRegFileZ (ArchRegFile#(n, a)) provisos (Bits#(a, a_sz), Literal#(a));
  let rf <- mkRegFileInitZ(0,0);
  return rf;
endmodule

// Read-only register
module mkROReg#(parameter a v) (Reg#(a));
  method Action _write (a _) = action endaction;
  method a _read() = v;
endmodule

// Bypassable Register
module mkBypassReg#(parameter a v) (Reg#(a)) provisos(Bits#(a, a_sz));
  Reg#(a) r[2] <- mkCReg(2, v);
  method Action _write(a x) = action r[0] <= x; endaction;
  method a _read() = r[1];
endmodule

module mkBypassRegU (Reg#(a)) provisos(Bits#(a, a_sz));
  Reg#(a) r[2] <- mkCRegU(2);
  method Action _write(a x) = action r[0] <= x; endaction;
  method a _read() = r[1];
endmodule

// make an undefined register yeild compile time errors on reads and writes
module mkRegUndef#(String name) (Reg#(a));
  method a _read() =
    error(sprintf("%s register read but not initialised", name));
  method Action _write(a val) =
    error(sprintf("%s register written but not initialised", name));
endmodule

// CReg with a ConfigReg at its core
module mkConfigCReg#(Integer n, t dflt) (Array#(Reg#(t))) provisos (Bits#(t, tw));
  Reg#(t)     r <- mkConfigReg(dflt);
  Wire#(t) w[n] <- mkDCWire(n, r._read);
  if (n > 0) rule update_reg; r._write(w[n-1]); endrule
  Reg#(t) ifc[n];
  for (Integer i = 0; i < n; i = i + 1) begin
    ifc[i] = interface Reg#(t);
      method _write = w[i]._write;
      method  _read = (i > 0) ? w[i-1]._read : r._read;
    endinterface;
  end
  return ifc;
endmodule

// Combinational primitives
////////////////////////////////////////////////////////////////////////////////

// signed comparison functions
function Bool signedLT (Bit#(n) a, Bit#(n) b);
  Int#(n) sa = unpack(a);
  Int#(n) sb = unpack(b);
  return sa < sb;
endfunction
function Bool signedGT (Bit#(n) a, Bit#(n) b);
  Int#(n) sa = unpack(a);
  Int#(n) sb = unpack(b);
  return sa > sb;
endfunction
function Bool signedGE (Bit#(n) a, Bit#(n) b);
  Int#(n) sa = unpack(a);
  Int#(n) sb = unpack(b);
  return sa >= sb;
endfunction

// arithmetic right shift
function Bit#(n) arithRightShift (Bit#(n) a, Bit#(m) b);
  Int#(n) sa = unpack(a);
  return pack(sa >> b);
endfunction

// "unsafe" resize
////////////////////////////////////////////////////////////////////////////////
function Bit #(m) resize (Bit #(n) x);
  Vector #(m, Bit #(1)) newVec = replicate (0);
  for (Integer i = 0; i < valueOf (n); i = i + 1)
    newVec[i] = x[i];
  return pack (newVec);
endfunction
