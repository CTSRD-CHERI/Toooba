/*-
 * Copyright (c) 2018-2023 Alexandre Joannou
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

import BlueBasics :: *;
import BlueAXI4   :: *;
import BlueAvalon :: *;

import Printf :: *;

///////////////////////
// Bit Plus One type //
////////////////////////////////////////////////////////////////////////////////

// Type to hold an n-bit value initialized by a literal starting
// at 1 and up to 2^n rather than 0 to 2^n-1
typedef struct {
  Bit #(n) val;
} BitPO #(numeric type n) deriving (Bits);

function t fromBitPO (BitPO #(TSub #(n, 1)) x) provisos (Bits #(t, n));
  if (x.val == 0) return unpack ({1'b1, 0});
  else return unpack ({1'b0, x.val});
endfunction

function Maybe #(BitPO #(TSub #(n, 1))) toBitPO (t x)
  provisos (Bits #(t, n), Add #(_a, 1, n));
  if (pack (x) > {1'b1, 0}) return Nothing;
  else if (pack (x) == {1'b1, 0}) return Just (BitPO { val: 0 });
  else return Just (BitPO { val: truncate (pack (x)) });
endfunction
// unsafeToBitPO unwraps the Maybe received on a toBitPO call and errors out in
// case of Invalid value
function BitPO #(TSub #(n, 1)) unsafeToBitPO (t x)
  provisos (Bits #(t, n), Add #(_a, 1, n)) =
  fromMaybe ( error (sprintf ( "unsafeToBitPO: 0x%0x cannot be held in a "
                             + "BitPO #(%0d)"
                             , pack (x), valueOf (TSub #(n, 1)) ))
            , toBitPO (x) );

function Bit #(TAdd #(n, 1)) readBitPO (BitPO #(n) x) =
  (x.val == 0) ? fromInteger (valueOf (TExp #(n))) : zeroExtend (x.val);

instance Literal #(BitPO #(n));
  function BitPO #(n) fromInteger (Integer x);
    if (x > 0 && x < valueOf (TExp #(n))) return BitPO { val: fromInteger (x) };
    else if (x == valueOf (TExp #(n))) return BitPO { val: 0 };
    else return error (sprintf ( "Trying to initialize a BitPO#(%0d) with "
                               + "literal %0d. The range of valid values is "
                               + "%0d to %0d."
                               , valueOf (n), x, 1, valueOf (TExp #(n))));
  endfunction
  function Bool inLiteralRange (BitPO #(n) _, Integer x) =
    (x > 0 && x <= valueOf (TExp #(n)));
endinstance

instance FShow #(BitPO #(n));
  function Fmt fshow (BitPO #(n) x) = $format ("%0d", readBitPO (x));
endinstance

//////////////////////
// memory interface //
////////////////////////////////////////////////////////////////////////////////

// Mem request
////////////////////////////////////////////////////////////////////////////////

typedef union tagged {
  // Mem read request
  struct {
    // the memory address to read
    addr_t addr;
    // the number of bytes to read
    // (encoded as a power of 2, i.e. a value of 0 means 2^0 = 1 byte
    //                                           1 means 2^1 = 2 bytes
    //                                           2 means 2^2 = 4 bytes
    //                                           ...
    Bit #(TMax #(1, TLog #(TAdd #(1, TLog #(TDiv #(SizeOf #(data_t), 8))))))
      numBytes;
  } ReadReq;
  // Mem write request
  struct {
    // the memory address to write
    addr_t addr;
    // the bytes from the provided data to actually write or not
    Bit #(TDiv #(SizeOf #(data_t), 8)) byteEnable;
    // the data to write
    data_t data;
  } WriteReq;
} MemReq #(type addr_t, type data_t) deriving (Bits, FShow);

function MemReq #(addr_t, data_t) offsetMemReq ( MemReq #(addr_t, data_t) r
                                               , Int #(addr_sz) o )
  provisos (Bits #(addr_t, addr_sz), Bits#(data_t, data_sz)) =
  case (r) matches
    tagged ReadReq .rr:
      tagged ReadReq { addr: unpack (pack (unpack (pack (rr.addr)) + o))
                     , numBytes: rr.numBytes };
    tagged WriteReq .wr:
      tagged WriteReq { addr: unpack (pack (unpack (pack (wr.addr)) + o))
                      , byteEnable: wr.byteEnable
                      , data: wr.data };
  endcase;

instance NeedRsp #(MemReq #(a, b));
  function needRsp (r);
    if (r matches tagged ReadReq .*) return True; else return False;
  endfunction
endinstance

instance ToAXI4Lite_AWFlit #(MemReq #(addr_t, data_t), addr_sz, user_sz)
  provisos (Bits #(addr_t, addr_sz));
  function toAXI4Lite_AWFlit (x) =
    AXI4Lite_AWFlit { awaddr: pack(x.WriteReq.addr)
                    , awprot: 0
                    , awuser: 0 };
endinstance

instance ToAXI4Lite_WFlit #(MemReq #(addr_t, data_t), data_sz, user_sz)
  provisos (Bits #(data_t, data_sz));
  function toAXI4Lite_WFlit (x) = AXI4Lite_WFlit { wdata: pack(x.WriteReq.data)
                                                 , wstrb: x.WriteReq.byteEnable
                                                 , wuser: 0 };
endinstance

instance ToAXI4Lite_ARFlit #(MemReq #(addr_t, data_t), addr_sz, user_sz)
  provisos (Bits #(addr_t, addr_sz));
  function toAXI4Lite_ARFlit (x) =
    AXI4Lite_ARFlit { araddr: pack(x.ReadReq.addr)
                    , arprot: 0
                    , aruser: 0 };
endinstance

function MemReq #(addr_t, data_t) avalonMMReqToMemReq
  (AvalonMMRequest #(addr_sz, data_sz) r)
  provisos ( Bits #(addr_t, addr_sz)
           , Bits #(data_t, data_sz)
           , NumAlias #(be_sz, TDiv #(data_sz, 8))
           , Add #(_a, TMax #(1, TLog #(TAdd #(1, TLog #(be_sz))))
                     , TLog #(TAdd #(1, be_sz))) );
  Bit #(addr_sz) mask = ~0 << valueOf (TLog #(be_sz));
  Bit #(addr_sz) addr = r.address & mask;
  return case (r.operation) matches
    tagged Read: tagged ReadReq {
        addr: unpack (addr)
      , numBytes: fromInteger (valueOf (TLog #(be_sz)))
    };
    tagged Write .wdata: tagged WriteReq { addr: unpack (addr)
                                         , byteEnable: r.byteenable
                                         , data: unpack (wdata) };
  endcase;
endfunction

// Mem response
////////////////////////////////////////////////////////////////////////////////

typedef union tagged {
  // Mem read response with the read data
  data_t ReadRsp;
  // Mem write response
  void WriteRsp;
  // Mem error response
  void ErrorRsp;
} MemRsp #(type data_t) deriving (Bits, FShow);

instance FromAXI4Lite_RFlit #(MemRsp #(data_t), data_sz, user_sz)
  provisos (Bits #(data_t, data_sz));
  function fromAXI4Lite_RFlit (x) = case (x.rresp)
    OKAY: ReadRsp (unpack (x.rdata));
    default: ErrorRsp;
  endcase;
endinstance

instance FromAXI4Lite_BFlit #(MemRsp #(data_t), user_sz);
  function fromAXI4Lite_BFlit (x) = case (x.bresp)
    OKAY: WriteRsp;
    default: ErrorRsp;
  endcase;
endinstance

function AvalonMMResponse #(data_sz) memRspToAvalonMMRsp
  (MemRsp #(data_t) r) provisos (Bits #(data_t, data_sz)) = case (r) matches
    tagged ReadRsp .rdata: AvalonMMResponse {
        response: 2'b00 // OKAY
      , operation: tagged Read pack (rdata)
    };
    tagged WriteRsp: AvalonMMResponse { response: 2'b00 // OKAY
                                      , operation: tagged Write };
    tagged ErrorRsp: AvalonMMResponse { response: 2'b10 // SLVERR
                                      , operation: ? };
  endcase;

// Mem interface
////////////////////////////////////////////////////////////////////////////////

typedef Slave #(MemReq #(addr_t, data_t), MemRsp #(data_t))
  Mem #(type addr_t, type data_t);
