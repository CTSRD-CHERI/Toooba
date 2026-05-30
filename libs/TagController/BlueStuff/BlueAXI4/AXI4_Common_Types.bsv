/*-
 * Copyright (c) 2018-2021 Alexandre Joannou
 * Copyright (c) 2021 Ivan Ribeiro
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

// Based on AXI4 specification from:
//
// AMBA AXI and ACE Protocol Specification
// AXI3, AXI4, AXI5, ACE and ACE5
// ARM IHI 0022F.b (ID122117)
// https://developer.arm.com/documentation/ihi0022/fb

package AXI4_Common_Types;

import Printf :: *;

//////////////////////
// Common AXI types //
//////////////////////

// AXI4 burst length (A3-48)
////////////////////////////////////////////////////////////////////////////////
typedef Bit#(8) AXI4_Len;

// AXI4 burst size (A3-49)
////////////////////////////////////////////////////////////////////////////////
// 2^axisize = number of bytes in a transfer
// ==> 3-bit AXI4_Size means from 1 (b000, 2^0) to 128 (b111, 2^7) bytes
typedef struct {
  Bit #(3) val;
} AXI4_Size deriving (Bits, Bitwise, Arith, Ord, Eq, FShow);
function Integer bytesFromAXI4_Size (AXI4_Size x) = case (x.val)
  3'b000: 1;
  3'b001: 2;
  3'b010: 4;
  3'b011: 8;
  3'b100: 16;
  3'b101: 32;
  3'b110: 64;
  3'b111: 128;
endcase;
function Fmt showAXI4_Size (AXI4_Size x) =
  $format (" %0d (0b%03b)", bytesFromAXI4_Size (x), x.val);
instance Literal #(AXI4_Size);
  function fromInteger (x) = case (x)
    1:       return AXI4_Size { val: 3'b000 };
    2:       return AXI4_Size { val: 3'b001 };
    4:       return AXI4_Size { val: 3'b010 };
    8:       return AXI4_Size { val: 3'b011 };
    16:      return AXI4_Size { val: 3'b100 };
    32:      return AXI4_Size { val: 3'b101 };
    64:      return AXI4_Size { val: 3'b110 };
    128:     return AXI4_Size { val: 3'b111 };
    default: return error (sprintf (
        "Unsupported AXI4_Size %0d. "
      + "Supported AXI4_Size values are {1, 2, 4, 8, 16, 32, 64, 128}."
      , x ));
  endcase;
  function inLiteralRange (_, x) = case (x)
    1, 2, 4, 8, 16, 32, 64, 128: return True;
    default: return False;
  endcase;
endinstance
instance PrimIndex #(AXI4_Size, SizeOf #(AXI4_Size));
  function isStaticIndex (_) = False;
  function toStaticIndex =
    error ("toStaticIndex should not be called on AXI4_Size");
  function toDynamicIndex = pack;
endinstance
instance PrimShiftIndex #(AXI4_Size, SizeOf #(AXI4_Size)); endinstance

function Bit #(TExp#(SizeOf#(AXI4_Size))) fromAXI4_Size (AXI4_Size sz) =
  1 << pack(sz);

function Maybe #(AXI4_Size) toAXI4_Size (Bit #(TExp#(SizeOf#(AXI4_Size))) sz);
  case (sz)
    1: return Valid(1);
    2: return Valid(2);
    4: return Valid(4);
    8: return Valid(8);
    16: return Valid(16);
    32: return Valid(32);
    64: return Valid(64);
    128: return Valid(128);
    default: return Invalid;
  endcase
endfunction

/*
instance Arith#(AXI4_Size);
  function   \+ (x, y) = unpack(\+ (pack(x), pack(y)));
  function   \- (x, y) = unpack(\- (pack(x), pack(y)));
  function  negate (x) = unpack(negate (pack(x)));
  function   \* (x, y) = unpack(\* (pack(x), pack(y)));
  function   \/ (x, y) = unpack(\/ (pack(x), pack(y)));
  function   \% (x, y) = unpack(\% (pack(x), pack(y)));
  function     abs (x) = unpack(abs (pack(x)));
  function  signum (x) = unpack(signum(pack(x)));
  function  \** (x, y) = unpack(\** (pack(x), pack(y)));
  function   exp_e (x) = unpack(exp_e (pack(x)));
  function     log (x) = unpack(log (pack(x)));
  function logb (b, x) = unpack(logb (pack(b), pack(x)));
  function    log2 (x) = unpack(log2 (pack(x)));
  function   log10 (x) = unpack(log10 (pack(x)));
endinstance
instance Bitwise#(AXI4_Size);
  function  \& (x1, x2) = unpack(\& (pack(x1), pack(x2)));
  function  \| (x1, x2) = unpack(\| (pack(x1), pack(x2)));
  function  \^ (x1, x2) = unpack(\^ (pack(x1), pack(x2)));
  function \~^ (x1, x2) = unpack(\~^ (pack(x1), pack(x2)));
  function \^~ (x1, x2) = unpack(\^~ (pack(x1), pack(x2)));
  function  invert (x1) = unpack(invert (pack(x1)));
  function \<< (x1, x2) = unpack(\<< (pack(x1), x2));
  function \>> (x1, x2) = unpack(\>> (pack(x1), x2));
  function      msb (x) = msb(pack(x));
  function      lsb (x) = lsb(pack(x));
endinstance
*/

// AXI4 burst type (A3-49)
////////////////////////////////////////////////////////////////////////////////
typedef enum {
  FIXED = 2'b00, INCR = 2'b01, WRAP = 2'b10, Res = 2'b11
} AXI4_Burst deriving (Bits, Eq, FShow);

// AXI4 locked accesses (A7-101)
////////////////////////////////////////////////////////////////////////////////
typedef enum {
  NORMAL = 1'b0, EXCLUSIVE = 1'b1
} AXI4_Lock deriving (Bits, Eq, FShow);

// AXI4 memory types (A4-69)
////////////////////////////////////////////////////////////////////////////////
typedef Bit #(4)  AXI4_Cache;

AXI4_Cache  arcache_dev_nonbuf           = 4'b0000;
AXI4_Cache  arcache_dev_buf              = 4'b0001;
AXI4_Cache  arcache_norm_noncache_nonbuf = 4'b0010;
AXI4_Cache  arcache_norm_noncache_buf    = 4'b0011;
AXI4_Cache  arcache_wthru_no_alloc       = 4'b1010;
AXI4_Cache  arcache_wthru_r_alloc        = 4'b1110;
AXI4_Cache  arcache_wthru_w_alloc        = 4'b1010;
AXI4_Cache  arcache_wthru_r_w_alloc      = 4'b1110;
AXI4_Cache  arcache_wback_no_alloc       = 4'b1011;
AXI4_Cache  arcache_wback_r_alloc        = 4'b1111;
AXI4_Cache  arcache_wback_w_alloc        = 4'b1011;
AXI4_Cache  arcache_wback_r_w_alloc      = 4'b1111;

AXI4_Cache  awcache_dev_nonbuf           = 4'b0000;
AXI4_Cache  awcache_dev_buf              = 4'b0001;
AXI4_Cache  awcache_norm_noncache_nonbuf = 4'b0010;
AXI4_Cache  awcache_norm_noncache_buf    = 4'b0011;
AXI4_Cache  awcache_wthru_no_alloc       = 4'b0110;
AXI4_Cache  awcache_wthru_r_alloc        = 4'b0110;
AXI4_Cache  awcache_wthru_w_alloc        = 4'b1110;
AXI4_Cache  awcache_wthru_r_w_alloc      = 4'b1110;
AXI4_Cache  awcache_wback_no_alloc       = 4'b0111;
AXI4_Cache  awcache_wback_r_alloc        = 4'b0111;
AXI4_Cache  awcache_wback_w_alloc        = 4'b1111;
AXI4_Cache  awcache_wback_r_w_alloc      = 4'b1111;

// AXI4 access permissions (A4-75)
////////////////////////////////////////////////////////////////////////////////
typedef enum {
  DATA = 1'b0, INST = 1'b1
} AXI4_Prot_2 deriving (Bits, Eq, FShow);
typedef enum {
  SECURE = 1'b0, NONSECURE = 1'b1
} AXI4_Prot_1 deriving (Bits, Eq, FShow);
typedef enum {
  UNPRIV = 1'b0, PRIV = 1'b1
} AXI4_Prot_0 deriving (Bits, Eq, FShow);
typedef Bit#(3) AXI4_Prot;
function AXI4_Prot axi4Prot(AXI4_Prot_2 x, AXI4_Prot_1 y, AXI4_Prot_0 z) =
  unpack({pack(x), pack(y), pack(z)});

// AXI4 QoS signaling (A8-104)
////////////////////////////////////////////////////////////////////////////////
typedef Bit#(4) AXI4_QoS;

// AXI4 multiple region signaling (A8-105)
////////////////////////////////////////////////////////////////////////////////
typedef Bit#(4) AXI4_Region;

// AXI4 read and write response structure (A3-59)
////////////////////////////////////////////////////////////////////////////////
typedef enum {
  OKAY = 2'b00, EXOKAY = 2'b01, SLVERR = 2'b10, DECERR = 2'b11
} AXI4_Resp deriving (Bits, Eq, FShow);

// CulDeSac interface, acting as a dead end
////////////////////////////////////////////////////////////////////////////////
typeclass CulDeSac#(type t);
  function t culDeSac;
endtypeclass

endpackage
