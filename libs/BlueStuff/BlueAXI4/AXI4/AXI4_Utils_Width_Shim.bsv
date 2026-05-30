/*-
 * Copyright (c) 2018-2022 Alexandre Joannou
 * All rights reserved.
 *
 * This hardware design was developed by the University of Cambridge Computer
 * Laboratory (Department of Computer Science and Technology) under EPSRC award
 * EP/S030867/1 ("SIPP"); and by SRI International and the University of
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

package AXI4_Utils_Width_Shim;

import Vector :: *;
import FIFOF :: *;
import SpecialFIFOs :: *;
import Connectable :: *;
import Assert :: *; // must build with the "-check-assert" flag to enable
import Real :: *; // just to test if an Integer is a power of 2

import BlueBasics :: *;

import AXI4_Types :: *;
import AXI4_Common_Types :: *;

// exported utilities

export mkAXI4DataWidthShim_WideToNarrow;
export mkAXI4DataWidthShim_NarrowToWide;

// debug helpers

Integer verbosity_level = 0;
function Action vPrint (Integer lvl, Fmt fmt) =
  action if (verbosity_level >= lvl) $display ("%0t - ", $time, fmt); endaction;

function Action die (Fmt fmt) = action
  $display ("%0t - ", $time, fmt);
  $finish;
endaction;

//////////////////////
// exposed wrappers //
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

// AXI4 wide to narrow data shim
////////////////////////////////////////////////////////////////////////////////

module mkAXI4DataWidthShim_WideToNarrow
  // received parameters
  #( parameter NumProxy #(buffInDepth)  proxyBuffInDepth
   , parameter NumProxy #(buffOutDepth) proxyBuffOutDepth )
  // returned interface
  (Tuple2 #( AXI4_Slave  #( id_, addr_, in_bit_t
                          , awuser_, wuser_, buser_, aruser_, ruser_ )
           , AXI4_Master #( id_, addr_, out_bit_t
                          , awuser_, wuser_, buser_, aruser_, ruser_ )))
  provisos ( NumAlias #(out_byte_t, TDiv #(out_bit_t, 8))
           , NumAlias #(out_bit_idx_t, TLog #(out_bit_t))
           , NumAlias #(out_byte_idx_t, TLog #(out_byte_t))
           , NumAlias #(in_byte_t, TDiv #(in_bit_t, 8))
           , NumAlias #(in_bit_idx_t, TLog #(in_bit_t))
           , NumAlias #(in_byte_idx_t, TLog #(in_byte_t))
           , Mul #(in_byte_t, 8, in_bit_t)
           , Add #(_a, out_bit_t, in_bit_t)
           , Add #(_b, out_byte_t, in_byte_t)
           , Add #(_c, out_byte_idx_t, out_bit_idx_t)
           , Add #(_d, out_byte_idx_t, addr_)
           , Add #(_e, out_byte_idx_t, MaxBytesSz)
           , Add #(_f, SizeOf #(AXI4_Len), TSub #(MaxBytesSz, out_byte_idx_t))
           , Add #(_g, in_byte_idx_t, MaxBytesSz)
           , Add #(_h, out_byte_idx_t, in_byte_idx_t)
           , Add #(_i, out_bit_idx_t, in_bit_idx_t)
           , Add #(_j, in_byte_idx_t, in_bit_idx_t)
           , Add #(_k, in_byte_idx_t, addr_)
           );
  match {.aw_X, .w_X, .b_X, .aw_Y, .w_Y, .b_Y}
    <- mkAXI4WritesWideToNarrow (proxyBuffInDepth, proxyBuffOutDepth);
  match {.ar_X, .r_X, .ar_Y, .r_Y}
    <- mkAXI4ReadsWideToNarrow (proxyBuffInDepth, proxyBuffOutDepth);
  return tuple2 (
    interface AXI4_Slave;
      interface aw = aw_X;
      interface  w = w_X;
      interface  b = b_X;
      interface ar = ar_X;
      interface  r = r_X;
    endinterface
  , interface AXI4_Master;
      interface aw = aw_Y;
      interface  w = w_Y;
      interface  b = b_Y;
      interface ar = ar_Y;
      interface  r = r_Y;
    endinterface );
endmodule

// AXI4 narrow to wide data shim
////////////////////////////////////////////////////////////////////////////////

module mkAXI4DataWidthShim_NarrowToWide
  // received parameters
  #( parameter NumProxy #(buffInDepth)  proxyBuffInDepth
   , parameter NumProxy #(buffOutDepth) proxyBuffOutDepth )
  // returned interface
  (Tuple2 #( AXI4_Slave  #( id_, addr_, in_bit_t
                          , awuser_, wuser_, buser_, aruser_, ruser_ )
           , AXI4_Master #( id_, addr_, out_bit_t
                          , awuser_, wuser_, buser_, aruser_, ruser_ )))
  provisos ( NumAlias #(out_byte_t, TDiv #(out_bit_t, 8))
           , NumAlias #(out_bit_idx_t, TLog #(out_bit_t))
           , NumAlias #(out_byte_idx_t, TLog #(out_byte_t))
           , NumAlias #(in_byte_t, TDiv #(in_bit_t, 8))
           , NumAlias #(in_bit_idx_t, TLog #(in_bit_t))
           , NumAlias #(in_byte_idx_t, TLog #(in_byte_t))
           , Mul #(out_byte_t, 8, out_bit_t)
           , Add #(_a, in_bit_t, out_bit_t)
           , Add #(_b, in_byte_t, out_byte_t)
           , Add #(_c, in_byte_idx_t, out_byte_idx_t)
           , Add #(_d, in_byte_idx_t, in_bit_idx_t)
           , Add #(_e, out_byte_idx_t, out_bit_idx_t)
           , Add #(_f, out_byte_idx_t, addr_)
           , Add #(_g, in_bit_idx_t, out_bit_idx_t)
           , Add #(_h, out_byte_idx_t, MaxBytesSz)
           , Add #(_i, SizeOf #(AXI4_Len), TSub #(MaxBytesSz, out_byte_idx_t))
           );
  match {.aw_X, .w_X, .b_X, .aw_Y, .w_Y, .b_Y}
    <- mkAXI4WritesNarrowToWide (proxyBuffInDepth, proxyBuffOutDepth);
  match {.ar_X, .r_X, .ar_Y, .r_Y}
    <- mkAXI4ReadsNarrowToWide (proxyBuffInDepth, proxyBuffOutDepth);
  return tuple2 (
    interface AXI4_Slave;
      interface aw = aw_X;
      interface  w = w_X;
      interface  b = b_X;
      interface ar = ar_X;
      interface  r = r_X;
    endinterface
  , interface AXI4_Master;
      interface aw = aw_Y;
      interface  w = w_Y;
      interface  b = b_Y;
      interface ar = ar_Y;
      interface  r = r_Y;
    endinterface );
endmodule

/////////////////////
// implementations //
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

// common helpers
////////////////////////////////////////////////////////////////////////////////

// numeric type:
// number of bits required to hold the max number of bytes in a transfer
typedef TAdd #( // AXI4 len width + 1 because of representation is -1
                TAdd #(SizeOf #(AXI4_Len), 1)
                // (2^(AXI4 size width))-1 maximum shift amount
              , TSub #(TExp #(SizeOf #(AXI4_Size)), 1) ) MaxBytesSz;

// check if a known static integer is a power of 2
function Bool isPowerOf2 (Integer x);
  Real realX = fromInteger (x);
  Real log2X = log2 (realX);
  return log2X == fromInteger (ceil (log2X));
endfunction

// derive new AXI4 len and size (and total bytes accessed)
typedef Tuple3 #(
           Bit #(MaxBytesSz) // total number of bytes of the access
         , AXI4_Len               // AXI4 len for the desired new bus width
         , AXI4_Size              // AXI4 size for the desired new bus width
         ) AccessParams;
function ActionValue #(AccessParams)
  deriveAccessParams ( NumProxy #(newBusByteW) proxy // new bus width in bytes
                     , AXI4_Len lenIn // original AXI4 len
                     , AXI4_Size sizeIn // original AXI4 size
                     )
  provisos ( NumAlias #(busOffset_t, TLog #(newBusByteW))
           , NumAlias #(flitIdx_t, TSub #(MaxBytesSz, busOffset_t))
           , Add #(_a, busOffset_t, MaxBytesSz)
           , Add #(_b, SizeOf #(AXI4_Len), TSub #(MaxBytesSz, busOffset_t))
           ) = actionvalue

  // compute number of bytes in the access and derived values
  ///////////////////////////////////////////////////////////
  Bit #(MaxBytesSz) nBytes = (zeroExtend (lenIn) + 1) << pack (sizeIn);
  Bit #(busOffset_t) overflow = truncate (nBytes);
  Bit #(flitIdx_t) nFlits = truncateLSB (nBytes);
  Bool fitsInNewBus = nBytes <= fromInteger (valueOf (newBusByteW));
  vPrint (4, $format ("%m.deriveAccessParams - nBytes: %0d", nBytes));
  vPrint (4, $format ("%m.deriveAccessParams - overflow: %0d", overflow));
  vPrint (4, $format ("%m.deriveAccessParams - nFlits: %0d", nFlits));
  vPrint (4, $format ( "%m.deriveAccessParams - fitsInNewBus: "
                     , fshow (fitsInNewBus) ));
  // derive new AXI4 len and size
  ///////////////////////////////
  AXI4_Len lenOut = fitsInNewBus ? 0 : truncate (nFlits - 1);
  AXI4_Size sizeOut = ?;
  case (toAXI4_Size (truncate (nBytes))) matches
    tagged Valid .x &&& fitsInNewBus: sizeOut = x;
    .* &&& (overflow != 0): begin
      sizeOut = sizeIn;
      lenOut = lenIn;
    end
    .* &&& (!fitsInNewBus):
      sizeOut = toAXI4_Size (fromInteger (valueOf (newBusByteW))).Valid;
    default: die ($format ("error: unsupported AXI4 size encountered"));
  endcase
  vPrint (4, $format ("%m.deriveAccessParams - lenOut: %0d", lenOut));
  vPrint (4, $format ("%m.deriveAccessParams - sizeOut: %0d", sizeOut));

  // a few assertions
  ///////////////////
  if (overflow == 0 && nFlits == 0)
    die ($format ("error: encountered AXI4 transfer with 0 flits"));
  if ((overflow != 0 && nFlits > 255) || nFlits > 256)
    die ($format ("error: too long AXI4 transfer (>256 flits) encountered"));
  if (!isPowerOf2 (valueOf (newBusByteW)))
    die ($format ("desired bus width should be a power of 2"));

  // return results
  /////////////////
  return tuple3 (nBytes, lenOut, sizeOut);

endactionvalue;

// Convert wide writes to narrow writes
////////////////////////////////////////////////////////////////////////////////

// XXX TODO: for the time being, this module does not break atomicity of
// transactions and limits itself to one request in the destination AXI4 domain
// per incoming request. Since the incoming requests are on a wider bus, it may
// be impossible to fit the total requested amount of bytes in a single request
// of the destination AXI4 domain. Such a request is explicitly not supported.
// (undefined behaviour in hardware, assertion in simulation)
module mkAXI4WritesWideToNarrow
  // received parameters
  #( parameter NumProxy #(buffInDepth)  proxyBuffInDepth
   , parameter NumProxy #(buffOutDepth) proxyBuffOutDepth)
  // returned interface
  (Tuple6 #( Sink #(AXI4_AWFlit #(id_, addr_, awuser_))
           , Sink #(AXI4_WFlit #(in_bit_t, wuser_))
           , Source #(AXI4_BFlit #(id_, buser_))
           , Source #(AXI4_AWFlit #(id_, addr_, awuser_))
           , Source #(AXI4_WFlit #(out_bit_t, wuser_))
           , Sink #(AXI4_BFlit #(id_, buser_)) ))
  provisos ( NumAlias #(in_byte_t, TDiv #(in_bit_t, 8))
           , NumAlias #(in_bit_idx_t, TLog #(in_bit_t))
           , NumAlias #(in_byte_idx_t, TLog #(in_byte_t))
           , NumAlias #(out_byte_t, TDiv #(out_bit_t, 8))
           , NumAlias #(out_bit_idx_t, TLog #(out_bit_t))
           , NumAlias #(out_byte_idx_t, TLog #(out_byte_t))
           , Add #(_a, out_bit_t, in_bit_t)
           , Add #(_b, out_bit_idx_t, in_bit_idx_t)
           , Add #(_c, out_byte_t, in_byte_t)
           , Add #(_d, out_byte_idx_t, in_byte_idx_t)
           , Add #(_e, in_byte_idx_t, in_bit_idx_t)
           , Add #(_f, out_byte_idx_t, MaxBytesSz)
           , Add #(_g, in_byte_idx_t, MaxBytesSz)
           , Add #(_h, in_byte_idx_t, addr_)
           , Add #(_i, SizeOf #(AXI4_Len), TSub #(MaxBytesSz, out_byte_idx_t))
           );

  // local declarations
  //////////////////////////////////////////////////////////////////////////////
  // interfaces //
  ////////////////
  // Address request channel, altered to account for burst size changes
  FIFOF #(AXI4_AWFlit #(id_, addr_, awuser_)) awffIn <- mkFIFOF;
  FIFOF #(AXI4_AWFlit #(id_, addr_, awuser_)) awffOut <- mkFIFOF;
  // Data request channel
  FIFOF #(AXI4_WFlit #(in_bit_t, wuser_))
    wffIn <- mkSizedFIFOF (valueOf (buffInDepth));
  FIFOF #(AXI4_WFlit #(out_bit_t, wuser_))
    wffOut <- mkSizedFIFOF (valueOf (buffOutDepth));
  // Response channel, single flit, passed straight through
  let bff <- mkFIFOF;
  ////////////
  // others //
  ////////////
  // local communication
  let reqff <- mkBypassFIFOF;

  // handle address channel
  //////////////////////////////////////////////////////////////////////////////
  rule aw_send;
    vPrint (1, $format ("%m.mkAXI4WritesWideToNarrow.aw_send"));
    // read and consume the incoming address request
    AXI4_AWFlit #(id_, addr_, awuser_) awflitIn <- get (awffIn);
    vPrint (2, $format ( "%m.mkAXI4WritesWideToNarrow.aw_send, "
                       , "awflitIn ", fshow (awflitIn) ));
    // derive the new outgoing address request
    NumProxy #(out_byte_t) proxyBusW = ?;
    match {.nBytes, .awlenOut, .awsizeOut} <-
      deriveAccessParams (proxyBusW, awflitIn.awlen, awflitIn.awsize);
    let awflitOut = AXI4_AWFlit { awid: awflitIn.awid
                                , awaddr: awflitIn.awaddr
                                , awlen: awlenOut
                                , awsize: awsizeOut
                                , awburst: INCR
                                , awlock: awflitIn.awlock
                                , awcache: awflitIn.awcache
                                , awprot: awflitIn.awprot
                                , awqos: awflitIn.awqos
                                , awregion: awflitIn.awregion
                                , awuser: awflitIn.awuser };
    // send the outgoing address request
    awffOut.enq (awflitOut);
    vPrint (2, $format ( "%m.mkAXI4WritesWideToNarrow.aw_send, "
                       , "awflitOut ", fshow (awflitOut) ));
    // pass local information to the data channel handling rule
    let reqffpayload = tuple4 ( awflitIn.awaddr
                              , nBytes
                              , awlenOut
                              , awsizeOut );
    reqff.enq (reqffpayload);
    vPrint (3, $format ( "%m.mkAXI4WritesWideToNarrow.aw_send, "
                       , "reqffpayload ", fshow (reqffpayload) ));
  endrule

  // handle data channel
  //////////////////////////////////////////////////////////////////////////////
  Reg #(Bit #(MaxBytesSz)) cnt <- mkReg (0);
  rule w_send;
    vPrint (1, $format ("%m.mkAXI4WritesWideToNarrow.w_send"));
    // read current local information
    let reqffpayload = reqff.first;
    vPrint (3, $format ( "%m.mkAXI4WritesWideToNarrow.w_send, "
                       , "reqffpayload ", fshow (reqffpayload) ));
    match {.addr, .nBytes, .lenOut, .sizeOut} = reqffpayload;
    // read current incoming data flit
    let wflitIn = wffIn.first;
    vPrint (2, $format ( "%m.mkAXI4WritesWideToNarrow.w_send, "
                       , "wflitIn ", fshow (wflitIn) ));
    // derive the new outgoing data flit
    Bit #(in_byte_idx_t) width = 1 << pack (sizeOut);
    Bit #(in_byte_idx_t) loOut = truncate (addr) + truncate (cnt);
    Bit #(out_byte_idx_t) loIn = truncate (loOut);
    Bit #(in_bit_idx_t) loOutBit = zeroExtend (loOut) << 3;
    Bit #(out_bit_idx_t) loInBit = truncate (loOutBit);
    Bit #(MaxBytesSz) newCnt = cnt + zeroExtend (width);
    //reqDataOut = wffIn.wdata[hiOutBit:loOutBit];
    Bit #(out_bit_t) reqDataOut = truncate (wflitIn.wdata >> loOutBit);
    Bit #(out_byte_t) reqStrbOut = truncate (wflitIn.wstrb >> loOut);
    // did we reach the last flit
    Bool isLast = newCnt >= nBytes;
    AXI4_WFlit #(out_bit_t, wuser_) wflitOut = AXI4_WFlit {
        wdata: reqDataOut << loInBit
      , wstrb: reqStrbOut << loIn
      , wlast: isLast
      , wuser: wflitIn.wuser };
    // send the outgoing data flit
    wffOut.enq (wflitOut);
    vPrint (2, $format ( "%m.mkAXI4WritesWideToNarrow.w_send, "
                       , "wflitOut ", fshow (wflitOut) ));
    // when the whole request is handled, consume local information and reset
    // byte counter
    Bool requestHandled = isLast;
    if (requestHandled) begin
      reqff.deq;
      vPrint (3, $format ( "%m.mkAXI4WritesWideToNarrow.w_send, "
                         , "whole request handled" ));
    end
    // when the incoming flit is fully utilized (and on end of request),
    // consume it
    Bit #(in_byte_idx_t) cntOffset = truncate (newCnt);
    Bool flitUtilized = cntOffset == 0;
    if (requestHandled || flitUtilized) begin
      wffIn.deq;
      vPrint (3, $format ( "%m.mkAXI4WritesWideToNarrow.w_send, "
                         , "wflitIn fully utilized, consuming it" ));
    end
    cnt <= (isLast) ? 0 : newCnt;
  endrule

  // return channels as interface
  //////////////////////////////////////////////////////////////////////////////
  return tuple6 ( toSink (awffIn), toSink (wffIn), toSource (bff)
                , toSource (awffOut), toSource(wffOut), toSink (bff) );

endmodule

// Convert wide reads to narrow reads
////////////////////////////////////////////////////////////////////////////////

// XXX TODO: for the time being, this module does not break atomicity of
// transactions and limits itself to one request in the destination AXI4 domain
// per incoming request. Since the incoming requests are on a wider bus, it may
// be impossible to fit the total requested amount of bytes in a single request
// of the destination AXI4 domain. Such a request is explicitly not supported.
// (undefined behaviour in hardware, assertion in simulation)
module mkAXI4ReadsWideToNarrow
  // received parameters
  #( parameter NumProxy #(buffInDepth)  proxyBuffInDepth
   , parameter NumProxy #(buffOutDepth) proxyBuffOutDepth)
  // returned interface
  (Tuple4 #( Sink #(AXI4_ARFlit #(id_, addr_, aruser_))
           , Source #(AXI4_RFlit #(id_, in_bit_t, ruser_))
           , Source #(AXI4_ARFlit #(id_, addr_, aruser_))
           , Sink #(AXI4_RFlit #(id_, out_bit_t, ruser_)) ))
  provisos ( NumAlias #(in_byte_t, TDiv #(in_bit_t, 8))
           , NumAlias #(in_bit_idx_t, TLog #(in_bit_t))
           , NumAlias #(in_byte_idx_t, TLog #(in_byte_t))
           , NumAlias #(out_byte_t, TDiv #(out_bit_t, 8))
           , NumAlias #(out_bit_idx_t, TLog #(out_bit_t))
           , NumAlias #(out_byte_idx_t, TLog #(out_byte_t))
           , Alias #(t_local, Tuple3 #( Bit #(addr_)
                                      , Bit #(MaxBytesSz)
                                      , AXI4_Size ))
           , Mul #(in_byte_t, 8, in_bit_t)
           , Add #(_a, out_bit_t, in_bit_t)
           , Add #(_b, out_byte_idx_t, in_byte_idx_t)
           , Add #(_c, out_bit_idx_t, in_bit_idx_t)
           , Add #(_d, in_byte_idx_t, in_bit_idx_t)
           , Add #(_e, in_byte_idx_t, MaxBytesSz)
           , Add #(_f, in_byte_idx_t, addr_)
           , Add #(_g, out_byte_idx_t, MaxBytesSz)
           , Add #(_h, SizeOf #(AXI4_Len), TSub #(MaxBytesSz, out_byte_idx_t))
           );

  // local declarations
  //////////////////////////////////////////////////////////////////////////////
  // interfaces //
  ////////////////
  // Request channel, single flit
  FIFOF #(AXI4_ARFlit #(id_, addr_, aruser_)) arffIn <- mkFIFOF;
  FIFOF #(AXI4_ARFlit #(id_, addr_, aruser_)) arffOut <- mkFIFOF;
  // Data response channel
  FIFOF #(AXI4_RFlit #(id_, in_bit_t, ruser_))
    rffIn <- mkSizedFIFOF (valueOf (buffInDepth));
  FIFOF #(AXI4_RFlit #(id_, out_bit_t, ruser_))
    rffOut <- mkSizedFIFOF (valueOf (buffOutDepth));
  ////////////
  // others //
  ////////////
  // local state to remember addresses
  Vector #(TExp #(id_), FIFOF #(t_local)) localff <- replicateM (mkUGFIFOF);

  // handle address channel
  //////////////////////////////////////////////////////////////////////////////
  let arflitIn = arffIn.first;
  rule ar_send (localff[arflitIn.arid].notFull);
    vPrint (1, $format ("%m.mkAXI4ReadsWideToNarrow.ar_send"));
    // consume the incoming address request
    arffIn.deq;
    vPrint (2, $format ( "%m.mkAXI4ReadsWideToNarrow.ar_send, "
                       , "arflitIn ", fshow (arflitIn) ));
    // derive the new outgoing address request
    NumProxy #(out_byte_t) proxyBusW = ?;
    match {.nBytes, .arlenOut, .arsizeOut} <-
      deriveAccessParams (proxyBusW, arflitIn.arlen, arflitIn.arsize);
    let arflitOut = AXI4_ARFlit { arid: arflitIn.arid
                                , araddr: arflitIn.araddr
                                , arlen: arlenOut
                                , arsize: arsizeOut
                                , arburst: INCR
                                , arlock: arflitIn.arlock
                                , arcache: arflitIn.arcache
                                , arprot: arflitIn.arprot
                                , arqos: arflitIn.arqos
                                , arregion: arflitIn.arregion
                                , aruser: arflitIn.aruser };
    // send the outgoing address request
    arffOut.enq (arflitOut);
    vPrint (2, $format ( "%m.mkAXI4ReadsWideToNarrow.ar_send, "
                       , "arflitOut ", fshow (arflitOut) ));
    // pass local information to the data channel handling rule
    t_local localpayload = tuple3 (arflitIn.araddr, nBytes, arsizeOut);
    localff[arflitIn.arid].enq (localpayload);
    vPrint (3, $format ( "%m.mkAXI4ReadsWideToNarrow.ar_send, "
                       , "localpayload ", fshow (localpayload) ));
  endrule

  // handle data response channel
  //////////////////////////////////////////////////////////////////////////////
  Reg #(Bit #(MaxBytesSz)) cnt <- mkReg (0);
  Reg #(Bit #(in_bit_t)) data <- mkRegU;
  let rflitOut = rffOut.first;
  rule r_accumulate_send (localff[rflitOut.rid].notEmpty);
    vPrint (1, $format ("%m.mkAXI4ReadsWideToNarrow.r_accumulate_send"));
    // read current local information
    vPrint (3, $format ( "%m.mkAXI4ReadsWideToNarrow.r_accumulate_send, "
                       , "localff[rflitOut.rid].first "
                       , fshow (localff[rflitOut.rid].first) ));
    match {.addr, .nBytes, .sizeOut} = localff[rflitOut.rid].first;
    // read and consume incoming data response flit
    rffOut.deq;
    vPrint (2, $format ( "%m.mkAXI4ReadsWideToNarrow.r_accumulate_send, "
                       , "rflitOut ", fshow (rflitOut) ));
    // accumulate the data and book-keep
    Bit #(in_byte_idx_t)     width = 1 << pack (sizeOut);
    Bit #(in_byte_idx_t)      loIn = truncate (addr) + truncate (cnt);
    Bit #(out_byte_idx_t)    loOut = truncate (loIn);
    Bit #(in_bit_idx_t)    loInBit = zeroExtend (loIn) << 3;
    Bit #(out_bit_idx_t)  loOutBit = truncate (loInBit);
    Bit #(MaxBytesSz) newCnt = cnt + zeroExtend (width);
    //tmpData[hiInBit:loInBit] = rflitOut.rdata[hiOutBit:loOutBit];
    Bit #(in_byte_t) msk = ~(~0 << width) << loIn;
    Bit #(out_bit_t) tmpDataOut = rflitOut.rdata >> loOutBit;
    Bit #(in_bit_t) tmpDataIn = zeroExtend (tmpDataOut) << loInBit;
    Bit #(in_bit_t) newData = mergeWithBE (msk, data, tmpDataIn);
    // when the burst is finished, consume local information
    let burstFinished = newCnt == nBytes;
    if (burstFinished) begin
      localff[rflitOut.rid].deq;
      vPrint (3, $format ( "%m.mkAXI4ReadsWideToNarrow.r_accumulate_send, "
                         , "consume localff[rflitOut.rid]" ));
    end
    // when a whole flit is ready, send it over and reset flit count
    Bit #(in_byte_idx_t) cntOffset = truncate (newCnt);
    let flitReady = cntOffset == 0;
    if (burstFinished || flitReady) begin
      AXI4_RFlit #(id_, in_bit_t, ruser_) rflitIn = AXI4_RFlit {
          rid: rflitOut.rid
        , rdata: newData
        , rresp: rflitOut.rresp
        , rlast: burstFinished
        // XXX better thing to do here?
        , ruser: rflitOut.ruser };
      rffIn.enq (rflitIn);
      if (burstFinished) newCnt = 0;
      vPrint (2, $format ( "%m.mkAXI4ReadsWideToNarrow.r_accumulate_send, "
                         , "rflitIn ", fshow (rflitIn) ));
    end
    // accumulate state
    cnt <= newCnt;
    data <= newData;
    vPrint (2, $format ( "%m.mkAXI4ReadsWideToNarrow.r_accumulate_send, "
                       , "cnt (", fshow (cnt)
                       , ") <= newCnt (", fshow (newCnt), ")" ));
    vPrint (2, $format ( "%m.mkAXI4ReadsWideToNarrow.r_accumulate_send, "
                       , "data (", fshow (data)
                       , ") <= newData (", fshow (newData), ")" ));
  endrule

  // return channels as interface
  //////////////////////////////////////////////////////////////////////////////
  return tuple4 ( toSink (arffIn), toSource (rffIn)
                , toSource (arffOut), toSink (rffOut) );
endmodule

// Convert narrow writes to wide writes
////////////////////////////////////////////////////////////////////////////////

// XXX TODO: currently supports awburst == INCR
//           undefined behaviour for WRAP and FIXED (in practice same as INCR)

module mkAXI4WritesNarrowToWide
  // received parameters
  #( parameter NumProxy #(buffInDepth)  proxyBuffInDepth
   , parameter NumProxy #(buffOutDepth) proxyBuffOutDepth)
  // returned interface
  (Tuple6 #( Sink #(AXI4_AWFlit #(id_, addr_, awuser_))
           , Sink #(AXI4_WFlit #(in_bit_t, wuser_))
           , Source #(AXI4_BFlit #(id_, buser_))
           , Source #(AXI4_AWFlit #(id_, addr_, awuser_))
           , Source #(AXI4_WFlit #(out_bit_t, wuser_))
           , Sink #(AXI4_BFlit #(id_, buser_)) ))
  provisos ( NumAlias #(in_bit_idx_t, TLog #(in_bit_t))
           , NumAlias #(in_byte_idx_t, TLog #(TDiv #(in_bit_t, 8)))
           , NumAlias #(out_byte_t, TDiv #(out_bit_t, 8))
           , NumAlias #(out_bit_idx_t, TLog #(out_bit_t))
           , NumAlias #(out_byte_idx_t, TLog #(out_byte_t))
           , Mul #(TDiv#(out_bit_t, 8), 8, out_bit_t)
           , Div #(in_bit_t, 8, in_byte_t)
           , Add #(_a, in_bit_t, out_bit_t)
           , Add #(_b, TDiv#(in_bit_t, 8), TDiv#(out_bit_t, 8))
           , Add #(_c, out_byte_idx_t, MaxBytesSz)
           , Add #(_d, in_byte_t, out_byte_t)
           , Add #(_e, in_byte_idx_t, in_bit_idx_t)
           , Add #(_f, out_byte_idx_t, out_bit_idx_t)
           , Add #(_g, in_byte_idx_t, out_byte_idx_t)
           , Add #(_h, in_bit_idx_t, out_bit_idx_t)
           , Add #(_i, out_byte_idx_t, addr_)
           , Add #(_j, out_byte_idx_t, MaxBytesSz)
           , Add #(_k, SizeOf #(AXI4_Len), TSub #(MaxBytesSz, out_byte_idx_t))
           );

  // local declarations
  //////////////////////////////////////////////////////////////////////////////
  // interfaces //
  ////////////////
  // Address request channel, altered to account for burst size changes
  FIFOF #(AXI4_AWFlit #(id_, addr_, awuser_)) awffIn <- mkFIFOF;
  FIFOF #(AXI4_AWFlit #(id_, addr_, awuser_)) awffOut <- mkFIFOF;
  // Data request channel
  FIFOF #(AXI4_WFlit #(in_bit_t, wuser_))
    wffIn <- mkSizedFIFOF (valueOf (buffInDepth));
  FIFOF #(AXI4_WFlit #(out_bit_t, wuser_))
    wffOut <- mkSizedFIFOF (valueOf (buffOutDepth));
  // Response channel, single flit, passed straight through
  let bff <- mkFIFOF;
  ////////////
  // others //
  ////////////
  // local communication
  let reqff <- mkBypassFIFOF;

  // handle address channel
  //////////////////////////////////////////////////////////////////////////////
  rule aw_send;
    vPrint (1, $format ("%m.mkAXI4WritesNarrowToWide.aw_send"));
    // read and consume the incoming address request
    AXI4_AWFlit #(id_, addr_, awuser_) awflitIn <- get (awffIn);
    vPrint (2, $format ( "%m.mkAXI4WritesNarrowToWide.aw_send, "
                       , "awflitIn ", fshow (awflitIn) ));
    // derive the new outgoing address request
    NumProxy #(out_byte_t) proxyBusW = ?;
    match {.nBytes, .awlenOut, .awsizeOut} <-
      deriveAccessParams (proxyBusW, awflitIn.awlen, awflitIn.awsize);
    let awflitOut = AXI4_AWFlit { awid: awflitIn.awid
                                , awaddr: awflitIn.awaddr
                                , awlen: awlenOut
                                , awsize: awsizeOut
                                , awburst: awflitIn.awburst
                                , awlock: awflitIn.awlock
                                , awcache: awflitIn.awcache
                                , awprot: awflitIn.awprot
                                , awqos: awflitIn.awqos
                                , awregion: awflitIn.awregion
                                , awuser: awflitIn.awuser };
    // send the outgoing address request
    awffOut.enq (awflitOut);
    vPrint (2, $format ( "%m.mkAXI4WritesNarrowToWide.aw_send, "
                       , "awflitOut ", fshow (awflitOut) ));
    // pass local information to the data channel handling rule
    let reqffpayload = tuple6 ( nBytes, awflitIn.awaddr
                              , awflitIn.awsize, awflitIn.awlen
                              , awsizeOut, awlenOut );
    reqff.enq (reqffpayload);
    vPrint (3, $format ( "%m.mkAXI4WritesNarrowToWide.aw_send, "
                       , "reqffpayload ", fshow (reqffpayload) ));
  endrule

  // handle data channel
  //////////////////////////////////////////////////////////////////////////////
  //local state
  Reg #(Bit #(MaxBytesSz)) cnt <- mkReg (0);
  Reg #(Bit #(out_byte_t)) strb <- mkReg (0);
  Reg #(Bit #(out_bit_t)) data <- mkRegU;
  rule w_accumulate_send;
    vPrint (1, $format ("%m.mkAXI4WritesNarrowToWide.w_accumulate_send"));
    // read current local information
    vPrint (3, $format ( "%m.mkAXI4WritesNarrowToWide.w_accumulate_send, "
                       , "reqff.first ", fshow (reqff.first) ));
    match {.nBytes, .addr, .awsizeIn, .awlenIn, .awsizeOut, .awlenOut} =
      reqff.first;
    // consume incoming data flit
    let wflitIn <- get (wffIn);
    vPrint (2, $format ( "%m.mkAXI4WritesNarrowToWide.w_accumulate_send, "
                       , "wflitIn ", fshow (wflitIn) ));
    // derive the relevant data indices
    Bit #(out_byte_idx_t) width = 1 << pack (awsizeIn);
    Bit #(out_byte_idx_t) loOut = truncate (addr) + truncate (cnt);
    Bit #(in_byte_idx_t) loIn = truncate (loOut);
    Bit #(out_bit_idx_t) loOutBit = zeroExtend (loOut) << 3;
    Bit #(in_bit_idx_t) loInBit = truncate (loOutBit);
    // accumulate the data and book-keep
    Bit #(MaxBytesSz) newCnt = cnt + zeroExtend (width);
    //tmpStrb[hiOut:loOut] = wflitIn.wstrb[hiIn:loIn];
    //tmpData[hiOutBit:loOutBit] = wflitIn.wdata[hiInBit:loInBit];
    Bit #(out_byte_t) msk = ~(~0 << width) << loOut;
    Bit #(in_byte_t) tmpStrbIn = wflitIn.wstrb >> loIn;
    Bit #(out_byte_t) tmpStrbOut = zeroExtend (tmpStrbIn) << loOut;
    Bit #(out_byte_t) newStrb = mergeWithMask (msk, strb, tmpStrbOut);
    Bit #(in_bit_t) tmpDataIn = wflitIn.wdata >> loInBit;
    Bit #(out_bit_t) tmpDataOut = zeroExtend (tmpDataIn) << loOutBit;
    Bit #(out_bit_t) newData = mergeWithBE (msk, data, tmpDataOut);
    // did we reach the last flit
    Bool isLast = newCnt == nBytes;
    vPrint (3, $format ( "%m.mkAXI4WritesNarrowToWide.w_accumulate_send, "
                       , "newCnt ", fshow (newCnt) ));
    vPrint (3, $format ( "%m.mkAXI4WritesNarrowToWide.w_accumulate_send, "
                       , "nBytes ", fshow (nBytes) ));
    vPrint (3, $format ( "%m.mkAXI4WritesNarrowToWide.w_accumulate_send, "
                       , "isLast ", fshow (isLast) ));
    // full flit ready
    Bit #(out_byte_idx_t) cntOffset = truncate (newCnt);
    Bit #(out_byte_idx_t) cntMask = ~(~0 << pack (awsizeOut));
    vPrint (3, $format ( "%m.mkAXI4WritesNarrowToWide.w_accumulate_send, "
                       , "cntOffset ", fshow (cntOffset) ));
    if (isLast || (cntOffset & cntMask) == 0) begin
      let wflitOut =  AXI4_WFlit { wdata: newData
                                 , wstrb: newStrb
                                 , wlast: isLast
                                   // XXX better thing to do here?
                                 , wuser: wflitIn.wuser
                                 };
      wffOut.enq (wflitOut);
      vPrint (2, $format ( "%m.mkAXI4WritesNarrowToWide.w_accumulate_send, "
                         , "wflitOut ", fshow (wflitOut) ));
      newData = 0;
      newStrb = 0;
    end
    // finished the burst
    if (isLast) begin
      vPrint (2, $format ( "%m.mkAXI4WritesNarrowToWide.w_accumulate_send, "
                         , "burst finished"));
      // assertions
      // must build with the "-check-assert" flag to enable
      dynamicAssert (wflitIn.wlast, "should line up with last w flit");
      // consume local information
      reqff.deq;
      newCnt = 0;
    end
    // accumulate state
    cnt <= newCnt;
    data <= newData;
    strb <= newStrb;
    vPrint (2, $format ( "%m.mkAXI4WritesNarrowToWide.w_accumulate_send, "
                       , "cnt (", fshow (cnt)
                       , ") <= newCnt (", fshow (newCnt), ")" ));
    vPrint (2, $format ( "%m.mkAXI4WritesNarrowToWide.w_accumulate_send, "
                       , "data (", fshow (data)
                       , ") <= newData (", fshow (newData), ")" ));
    vPrint (2, $format ( "%m.mkAXI4WritesNarrowToWide.w_accumulate_send, "
                       , "strb (", fshow (strb)
                       , ") <= newStrb (", fshow (newStrb), ")" ));
  endrule

  // return channels as interface
  //////////////////////////////////////////////////////////////////////////////
  return tuple6 ( toSink (awffIn), toSink (wffIn), toSource (bff)
                , toSource (awffOut), toSource(wffOut), toSink (bff) );

endmodule

// Convert narrow reads to wide reads
////////////////////////////////////////////////////////////////////////////////

// XXX TODO: currently supports awburst == INCR
//           undefined behaviour for WRAP and FIXED (in practice same as INCR)

module mkAXI4ReadsNarrowToWide
  // received parameters
  #( parameter NumProxy #(buffInDepth)  proxyBuffInDepth
   , parameter NumProxy #(buffOutDepth) proxyBuffOutDepth)
  // returned interface
  (Tuple4 #( Sink #(AXI4_ARFlit #(id_, addr_, aruser_))
           , Source #(AXI4_RFlit #(id_, in_bit_t, ruser_))
           , Source #(AXI4_ARFlit #(id_, addr_, aruser_))
           , Sink #(AXI4_RFlit #(id_, out_bit_t, ruser_)) ))
  provisos ( NumAlias #(in_bit_idx_t, TLog #(in_bit_t))
           , NumAlias #(in_byte_idx_t, TLog #(TDiv #(in_bit_t, 8)))
           , NumAlias #(out_byte_t, TDiv #(out_bit_t, 8))
           , NumAlias #(out_bit_idx_t, TLog #(out_bit_t))
           , NumAlias #(out_byte_idx_t, TLog #(out_byte_t))
           , Alias #(local_info, Tuple4 #( Bit #(MaxBytesSz)
                                         , Bit #(addr_)
                                         , AXI4_Size
                                         , AXI4_Len ))
           , Add #(_a, in_bit_t, out_bit_t)
           , Add #(_b, out_byte_idx_t, MaxBytesSz)
           , Add #(_c, in_byte_idx_t, in_bit_idx_t)
           , Add #(_d, out_byte_idx_t, out_bit_idx_t)
           , Add #(_e, in_byte_idx_t, out_byte_idx_t)
           , Add #(_f, in_bit_idx_t, out_bit_idx_t)
           , Add #(_g, out_byte_idx_t, addr_)
           , Add #(_h, out_byte_idx_t, MaxBytesSz)
           , Add #(_i, SizeOf #(AXI4_Len), TSub #(MaxBytesSz, out_byte_idx_t))
           );

  // local declarations
  //////////////////////////////////////////////////////////////////////////////
  // interfaces //
  ////////////////
  // Request channel, single flit
  FIFOF #(AXI4_ARFlit #(id_, addr_, aruser_)) arffIn <- mkFIFOF;
  FIFOF #(AXI4_ARFlit #(id_, addr_, aruser_)) arffOut <- mkFIFOF;
  // Data response channel
  FIFOF #(AXI4_RFlit #(id_, in_bit_t, ruser_))
    rffIn <- mkSizedFIFOF (valueOf (buffInDepth));
  FIFOF #(AXI4_RFlit #(id_, out_bit_t, ruser_))
    rffOut <- mkSizedFIFOF (valueOf (buffOutDepth));
  ////////////
  // others //
  ////////////
  // local state to remember addresses
  Vector #(TExp #(id_), FIFOF #(local_info)) localff <- replicateM (mkUGFIFOF);

  // handle address channel
  //////////////////////////////////////////////////////////////////////////////
  let arflitIn = arffIn.first;
  rule ar_send (localff[arflitIn.arid].notFull);
    vPrint (1, $format ("%m.mkAXI4ReadsNarrowToWide.ar_send"));
    // consume the incoming address request
    arffIn.deq;
    vPrint (2, $format ( "%m.mkAXI4ReadsNarrowToWide.ar_send, "
                       , "arflitIn ", fshow (arflitIn) ));
    // derive the new outgoing address request
    NumProxy #(out_byte_t) proxyBusW = ?;
    match {.nBytes, .arlenOut, .arsizeOut} <-
      deriveAccessParams (proxyBusW, arflitIn.arlen, arflitIn.arsize);
    let arflitOut = AXI4_ARFlit { arid: arflitIn.arid
                                , araddr: arflitIn.araddr
                                , arlen: arlenOut
                                , arsize: arsizeOut
                                , arburst: arflitIn.arburst
                                , arlock: arflitIn.arlock
                                , arcache: arflitIn.arcache
                                , arprot: arflitIn.arprot
                                , arqos: arflitIn.arqos
                                , arregion: arflitIn.arregion
                                , aruser: arflitIn.aruser };
    // send the outgoing address request
    arffOut.enq (arflitOut);
    vPrint (2, $format ( "%m.mkAXI4ReadsNarrowToWide.ar_send, "
                       , "arflitOut ", fshow (arflitOut) ));
    // pass local information to the data channel handling rule
    let localffpayload = tuple4 ( nBytes
                                , arflitIn.araddr
                                , arflitIn.arsize
                                , arflitIn.arlen );
    localff[arflitIn.arid].enq (localffpayload);
    vPrint (3, $format ( "%m.mkAXI4ReadsNarrowToWide.ar_send, "
                       , "localffpayload[%0d] "
                       , arflitIn.arid, fshow (localffpayload) ));
  endrule

  // handle data response channel
  //////////////////////////////////////////////////////////////////////////////
  Reg #(Bit #(MaxBytesSz)) cnt <- mkReg (0);
  let rflitOut = rffOut.first;
  let localffpayload = localff[rflitOut.rid].first;
  match {.nBytes, .addr, .arsize, .arlen} = localffpayload;
  rule r_accumulate_send (localff[rflitOut.rid].notEmpty);
    vPrint (1, $format ("%m.mkAXI4ReadsNarrowToWide.r_accumulate_send"));
    // read current local information
    vPrint (3, $format ( "%m.mkAXI4ReadsNarrowToWide.r_accumulate_send, "
                       , "localffpayload[%0d] "
                       , rflitOut.rid, fshow (localffpayload) ));
    // read incoming data response flit
    vPrint (2, $format ( "%m.mkAXI4ReadsNarrowToWide.r_accumulate_send, "
                       , "rflitOut ", fshow (rflitOut) ));
    // accumulate the data and book-keep
    Bit #(out_byte_idx_t) width = 1 << pack (arsize);
    Bit #(out_byte_idx_t) loOut = truncate (addr) + truncate (cnt);
    Bit #(out_bit_idx_t) loOutBit = zeroExtend (loOut) << 3;
    Bit #(in_bit_idx_t) loInBit = truncate (loOutBit);
    Bit #(MaxBytesSz) newCnt = cnt + zeroExtend (width);
    //rspData[hiInBit:loInBit] = rflitOut.rdata[hiOutBit:loOutBit];
    Bit #(in_bit_t) rspDataOut = truncate (rflitOut.rdata >> loOutBit);
    // did we reach the last flit
    Bool isLast = newCnt == nBytes;
    // push a response
    let rflitIn = AXI4_RFlit { rid: rflitOut.rid
                             , rdata: rspDataOut << loInBit
                             , rresp: rflitOut.rresp
                             , rlast: isLast
                             , ruser: rflitOut.ruser };
    rffIn.enq (rflitIn);
    vPrint (2, $format ( "%m.mkAXI4ReadsNarrowToWide.r_accumulate_send, "
                       , "rflitIn ", fshow (rflitIn) ));
    // will we consume from the returning r flits fifo?
    Bool rffOutConsume = False;
    // finished the burst
    if (isLast) begin
      vPrint (2, $format ( "%m.mkAXI4ReadsNarrowToWide.r_accumulate_send, "
                         , "last flit" ));
      // assertions
      // must build with the "-check-assert" flag to enable
      dynamicAssert (rflitOut.rlast, "should line up with last r flit");
      localff[rflitOut.rid].deq;
      newCnt = 0;
      rffOutConsume = True;
    end
    // full flit consumed
    Bit #(out_byte_idx_t) cntOffset = truncate (newCnt);
    rffOutConsume = rffOutConsume || (cntOffset == 0);
    if (rffOutConsume) begin
      rffOut.deq;
      vPrint (2, $format ( "%m.mkAXI4ReadsNarrowToWide.r_accumulate_send, "
                         , "full Out flit consumed" ));
    end
    // state update
    cnt <= newCnt;
    vPrint (2, $format ( "%m.mkAXI4ReadsNarrowToWide.r_accumulate_send, "
                       , "cnt (", fshow (cnt)
                       , ") <= newCnt (", fshow (newCnt), ")" ));
  endrule

  // return channels as interface
  //////////////////////////////////////////////////////////////////////////////
  return tuple4 ( toSink (arffIn), toSource (rffIn)
                , toSource (arffOut), toSink (rffOut) );

endmodule

endpackage
