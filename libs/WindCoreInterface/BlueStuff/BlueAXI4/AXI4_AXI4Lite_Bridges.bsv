/*-
 * Copyright (c) 2018-2022 Alexandre Joannou
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

import FIFO              :: *;
import Connectable       :: *;
import SourceSink        :: *;
import AXI4_Types        :: *;
import AXI4Lite_Types    :: *;
import AXI4_Common_Types :: *;

// die helper
function Action die (Fmt m) = action
  $display ("AXI4_AXI4Lite_Bridges.bsv ===> ", m);
  $finish (0);
endaction;

///////////////////////////////////////////
// simple flit conversion and assertions //
////////////////////////////////////////////////////////////////////////////////

// set of default AXI4 flit to represent AXI4Lite flits
AXI4_AWFlit #(id_, addr_, awuser_) dfltAW =
  AXI4_AWFlit { awid: 0
              , awaddr: ?
              , awlen: 0
              , awsize: ?
              , awburst: FIXED
              , awlock: NORMAL
              , awcache: 0
              , awprot: ?
              , awqos: 0
              , awregion: 0
              , awuser: ? };
AXI4_WFlit #(data_, wuser_) dfltW =
  AXI4_WFlit { wdata: ?
             , wstrb: ?
             , wlast: True
             , wuser: ? };
AXI4_ARFlit #(id_, addr_, aruser_) dfltAR =
  AXI4_ARFlit { arid: 0
              , araddr: ?
              , arlen: 0
              , arsize: ?
              , arburst: FIXED
              , arlock: NORMAL
              , arcache: 0
              , arprot: ?
              , arqos: 0
              , arregion: 0
              , aruser: ? };

// see previous definitions for field values of AXI4 exclusive fields
function AXI4_AWFlit #(id_, addr_, awuser_)
         fromAXI4Lite_AW (AXI4Lite_AWFlit #(addr_, awuser_) x);
  AXI4_AWFlit #(id_, addr_, awuser_) res = dfltAW;
  res.awaddr = x.awaddr;
  res.awprot = x.awprot;
  res.awuser = x.awuser;
  return res;
endfunction
function AXI4_WFlit #(data_, wuser_)
         fromAXI4Lite_W (AXI4Lite_WFlit #(data_, wuser_) x);
  AXI4_WFlit #(data_, wuser_) res = dfltW;
  res.wdata = x.wdata;
  res.wstrb = x.wstrb;
  res.wuser = x.wuser;
  return res;
endfunction
function AXI4_BFlit #(id_, buser_)
         fromAXI4Lite_B (Bit #(id_) someId, AXI4Lite_BFlit #(buser_) x) =
  AXI4_BFlit { bid: someId, bresp: x.bresp, buser: x.buser };
function AXI4_ARFlit #(id_, addr_, aruser_)
         fromAXI4Lite_AR (AXI4Lite_ARFlit #(addr_, aruser_) x);
  AXI4_ARFlit #(id_, addr_, aruser_) res = dfltAR;
  res.araddr = x.araddr;
  res.arprot = x.arprot;
  res.aruser = x.aruser;
  return res;
endfunction
function AXI4_RFlit #(id_, data_, ruser_)
         fromAXI4Lite_R (Bit #(id_) someId, AXI4Lite_RFlit #(data_, ruser_) x) =
  AXI4_RFlit { rid: someId
             , rdata: x.rdata
             , rresp: x.rresp
             , rlast: True
             , ruser: x.ruser };

// always strict subset of fields
function AXI4Lite_AWFlit #(addr_, awuser_)
         toAXI4Lite_AW (AXI4_AWFlit #(id_, addr_, awuser_) x) =
  AXI4Lite_AWFlit { awaddr: x.awaddr
                  , awprot: x.awprot
                  , awuser: x.awuser };
function AXI4Lite_WFlit #(data_, wuser_)
         toAXI4Lite_W (AXI4_WFlit #(data_, wuser_) x) =
  AXI4Lite_WFlit { wdata: x.wdata
                 , wstrb: x.wstrb
                 , wuser: x.wuser };
function AXI4Lite_BFlit #(buser_)
         toAXI4Lite_B (AXI4_BFlit #(id_, buser_) x) =
  AXI4Lite_BFlit { bresp: x.bresp
                 , buser: x.buser };
function AXI4Lite_ARFlit #(addr_, aruser_)
         toAXI4Lite_AR (AXI4_ARFlit #(id_, addr_, aruser_) x) =
  AXI4Lite_ARFlit { araddr: x.araddr
                  , arprot: x.arprot
                  , aruser: x.aruser };
function AXI4Lite_RFlit #(data_, ruser_)
         toAXI4Lite_R (AXI4_RFlit #(id_, data_, ruser_) x) =
  AXI4Lite_RFlit { rdata: x.rdata
                 , rresp: x.rresp
                 , ruser: x.ruser };

// assertions on AXI4 flits
function Action checkAXI4_AWFlit ( AXI4_Size busSize
                                 , Bool checkId
                                 , AXI4_AWFlit #(id_, addr_, awuser_) x) =
  action
    if (checkId && x.awid != 0)
      die ($format( "checkAXI4_AWFlit - Unsupported non-0 awid (%0d)"
                  , x.awid
                  , "\n", fshow (x) ));
    if (x.awlen != 0)
      die ($format( "checkAXI4_AWFlit - Unsupported non-0 awlen (%0d)"
                  , x.awlen
                  , "\n", fshow (x) ));
    if (x.awsize != busSize)
      die ($format("checkAXI4_AWFlit - Unsupported awsize"
                  , " (expected: ", showAXI4_Size (busSize)
                  , ", given: ", showAXI4_Size (x.awsize), ")"
                  , "\n", fshow (x) ));
    if (x.awburst != FIXED)
      die ($format( "checkAXI4_AWFlit - Unsupported non-FIXED awburst"
                  , "(", fshow (x.awburst), ")"
                  , "\n", fshow (x) ));
    if (x.awlock != NORMAL)
      die ($format( "checkAXI4_AWFlit - Unsupported non-NORMAL awlock"
                  , "(", fshow (x.awlock), ")"
                  , "\n", fshow (x) ));
    if (x.awcache != 0)
      die ($format( "checkAXI4_AWFlit - Unsupported non-0 awcache (0x%0x)"
                  , x.awcache
                  , "\n", fshow (x) ));
    if (x.awqos != 0)
      die ($format( "checkAXI4_AWFlit - Unsupported non-0 awqos (%0d)"
                  , x.awqos
                  , "\n", fshow (x) ));
    if (x.awregion != 0)
      die ($format( "checkAXI4_AWFlit - Unsupported non-0 awregion (%0d)"
                  , x.awregion
                  , "\n", fshow (x) ));
  endaction;
function Action checkAXI4_WFlit (AXI4_WFlit #(data_, wuser_) x) = action
  if (x.wlast != True)
    die ($format( "checkAXI4_WFlit - Unsupported non-True wlast"
                , "(", fshow (x.wlast), ")"
                , "\n", fshow (x) ));
endaction;
function Action checkAXI4_BFlit (Bool checkId, AXI4_BFlit #(id_, buser_) x) =
  action
    if (checkId && x.bid != 0)
      die ($format( "checkAXI4_BFlit - Unsupported non-0 bid (%0d)"
                  , x.bid
                  , "\n", fshow (x) ));
  endaction;
function Action checkAXI4_ARFlit ( AXI4_Size busSize
                                 , Bool checkId
                                 , AXI4_ARFlit #(id_, addr_, aruser_) x) =
  action
    if (checkId && x.arid != 0)
      die ($format( "checkAXI4_ARFlit - Unsupported non-0 arid (%0d)"
                  , x.arid
                  , "\n", fshow (x) ));
    if (x.arlen != 0)
      die ($format( "checkAXI4_ARFlit - Unsupported non-0 arlen (%0d)"
                  , x.arlen
                  , "\n", fshow (x) ));
    if (x.arsize != busSize)
      die ($format("checkAXI4_ARFlit - Unsupported arsize"
                  , " (expected: ", showAXI4_Size (busSize)
                  , ", given: ", showAXI4_Size (x.arsize), ")"
                  , "\n", fshow (x) ));
    if (x.arburst != FIXED)
      die ($format( "checkAXI4_ARFlit - Unsupported non-FIXED arburst"
                  , "(", fshow (x.arburst), ")"
                  , "\n", fshow (x) ));
    if (x.arlock != NORMAL)
      die ($format( "checkAXI4_ARFlit - Unsupported non-NORMAL arlock"
                  , "(", fshow (x.arlock), ")"
                  , "\n", fshow (x) ));
    if (x.arcache != 0)
      die ($format( "checkAXI4_ARFlit - Unsupported non-0 arcache (0x%0x)"
                  , x.arcache
                  , "\n", fshow (x) ));
    if (x.arqos != 0)
      die ($format( "checkAXI4_ARFlit - Unsupported non-0 arqos (%0d)"
                  , x.arqos
                  , "\n", fshow (x) ));
    if (x.arregion != 0)
      die ($format( "checkAXI4_ARFlit - Unsupported non-0 arregion (%0d)"
                  , x.arregion
                  , "\n", fshow (x) ));
  endaction;
function Action checkAXI4_RFlit ( Bool checkId
                                , AXI4_RFlit #(id_, data_, ruser_) x) = action
  if (checkId && x.rid != 0)
    die ($format( "checkAXI4_ARFlit - Unsupported non-0 rid (%0d)"
                , x.rid
                , "\n", fshow (x) ));
  if (x.rlast != True)
    die ($format( "checkAXI4_ARFlit - Unsupported non-True rlast"
                , "(", fshow(x.rlast), ")"
                , "\n", fshow (x) ));
endaction;

///////////////////////////
// Connectable instances //
////////////////////////////////////////////////////////////////////////////////

// AXI4Lite Master to AXI4 Slave
////////////////////////////////
instance Connectable #( AXI4Lite_Master #( addr_, data_
                                         , awuser_, wuser_, buser_
                                         , aruser_, ruser_ )
                      , AXI4_Slave #( id_, addr_, data_
                                    , awuser_, wuser_, buser_
                                    , aruser_, ruser_));
  module mkConnection #( AXI4Lite_Master #( addr_, data_
                                          , awuser_, wuser_, buser_
                                          , aruser_, ruser_ ) axlm
                       , AXI4_Slave #( id_, addr_, data_
                                     , awuser_, wuser_, buser_
                                     , aruser_, ruser_) axs) (Empty);
    //mkConnection (fromAXI4LiteToAXI4_Master (axlm), axs);
    mkConnection (axlm, fromAXI4ToAXI4Lite_Slave (axs));
  endmodule
endinstance
instance Connectable #( AXI4_Slave #( id_, addr_, data_
                                    , awuser_, wuser_, buser_
                                    , aruser_, ruser_)
                      , AXI4Lite_Master #( addr_, data_
                                         , awuser_, wuser_, buser_
                                         , aruser_, ruser_ ));
  module mkConnection #( AXI4_Slave #( id_, addr_, data_
                                     , awuser_, wuser_, buser_
                                     , aruser_, ruser_) axs
                       , AXI4Lite_Master #( addr_, data_
                                          , awuser_, wuser_, buser_
                                          , aruser_, ruser_ ) axlm) (Empty);
    mkConnection (axlm, axs);
  endmodule
endinstance

// AXI4 Master to AXI4Lite Slave
////////////////////////////////
instance Connectable #( AXI4_Master #( id_, addr_, data_
                                     , awuser_, wuser_, buser_
                                     , aruser_, ruser_ )
                      , AXI4Lite_Slave #( addr_, data_
                                        , awuser_, wuser_, buser_
                                        , aruser_, ruser_));
  module mkConnection #( AXI4_Master #( id_, addr_, data_
                                      , awuser_, wuser_, buser_
                                      , aruser_, ruser_ ) axm
                       , AXI4Lite_Slave #( addr_, data_
                                         , awuser_, wuser_, buser_
                                         , aruser_, ruser_) axls) (Empty);
    // id field fifos
    let awIdFF <- mkFIFO;
    let arIdFF <- mkFIFO;

    // convert and forward each flits
    let busSize = fromInteger(valueOf(data_)/8);
    rule aw;
      let awflit <- get (axm.aw);
      checkAXI4_AWFlit (busSize, False, awflit);
      axls.aw.put (toAXI4Lite_AW (awflit));
      awIdFF.enq (awflit.awid);
    endrule
    rule w;
      let wflit <- get (axm.w);
      checkAXI4_WFlit (wflit);
      axls.w.put (toAXI4Lite_W (wflit));
    endrule
    rule b;
      axm.b.put (fromAXI4Lite_B (awIdFF.first, axls.b.peek));
      axls.b.drop;
      awIdFF.deq;
    endrule
    rule ar;
      let arflit <- get (axm.ar);
      checkAXI4_ARFlit (busSize, False, arflit);
      axls.ar.put (toAXI4Lite_AR (arflit));
      arIdFF.enq (arflit.arid);
    endrule
    rule r;
      axm.r.put (fromAXI4Lite_R (arIdFF.first, axls.r.peek));
      axls.r.drop;
      arIdFF.deq;
    endrule

  endmodule
endinstance
instance Connectable #( AXI4Lite_Slave #( addr_, data_
                                        , awuser_, wuser_, buser_
                                        , aruser_, ruser_)
                      , AXI4_Master #( id_, addr_, data_
                                     , awuser_, wuser_, buser_
                                     , aruser_, ruser_ ));
  module mkConnection #( AXI4Lite_Slave #( addr_, data_
                                         , awuser_, wuser_, buser_
                                         , aruser_, ruser_) axls
                       , AXI4_Master #( id_, addr_, data_
                                      , awuser_, wuser_, buser_
                                      , aruser_, ruser_ ) axm) (Empty);
    mkConnection (axm, axls);
  endmodule
endinstance


////////////////////////
// Master convertions //
////////////////////////////////////////////////////////////////////////////////

function (AXI4Lite_Master #( addr_, data_
                           , awuser_, wuser_, buser_
                           , aruser_, ruser_))
         fromAXI4ToAXI4Lite_Master (
           AXI4_Master #( id_, addr_, data_
                        , awuser_, wuser_, buser_
                        , aruser_, ruser_) m) = interface AXI4Lite_Master;
  let busSize = fromInteger(valueOf(data_)/8);
  interface aw = mapSource ( toAXI4Lite_AW
                           , onDrop (checkAXI4_AWFlit (busSize, True), m.aw) );
  interface  w = mapSource ( toAXI4Lite_W
                           , onDrop (checkAXI4_WFlit, m.w) );
  interface  b = mapSink   ( fromAXI4Lite_B (0)
                           , onPut (checkAXI4_BFlit (True), m.b) );
  interface ar = mapSource ( toAXI4Lite_AR
                           , onDrop (checkAXI4_ARFlit (busSize, True), m.ar) );
  interface  r = mapSink   ( fromAXI4Lite_R (0)
                           , onPut (checkAXI4_RFlit (True), m.r) );
endinterface;

function (AXI4_Master #( id_, addr_, data_
                       , awuser_, wuser_, buser_
                       , aruser_, ruser_))
         fromAXI4LiteToAXI4_Master (
           AXI4Lite_Master #( addr_, data_
                            , awuser_, wuser_, buser_
                            , aruser_, ruser_) mLite) = interface AXI4_Master;
  let busSize = fromInteger(valueOf(data_)/8);
  interface aw = onDrop ( checkAXI4_AWFlit (busSize, True)
                        , mapSource (fromAXI4Lite_AW, mLite.aw) );
  interface  w = onDrop ( checkAXI4_WFlit
                        , mapSource (fromAXI4Lite_W, mLite.w) );
  interface  b = onPut  ( checkAXI4_BFlit (True)
                        , mapSink (toAXI4Lite_B, mLite.b) );
  interface ar = onDrop ( checkAXI4_ARFlit (busSize, True)
                        , mapSource (fromAXI4Lite_AR, mLite.ar) );
  interface  r = onPut  ( checkAXI4_RFlit (True)
                        , mapSink (toAXI4Lite_R, mLite.r) );
endinterface;

///////////////////////
// Slave convertions //
////////////////////////////////////////////////////////////////////////////////

function (AXI4Lite_Slave #( addr_, data_
                          , awuser_, wuser_, buser_
                          , aruser_, ruser_))
         fromAXI4ToAXI4Lite_Slave (
           AXI4_Slave #( id_, addr_, data_
                       , awuser_, wuser_, buser_
                       , aruser_, ruser_) s) = interface AXI4Lite_Slave;
  let busSize = fromInteger(valueOf(data_)/8);
  interface aw = mapSink   ( fromAXI4Lite_AW
                           , onPut (checkAXI4_AWFlit (busSize, True), s.aw) );
  interface  w = mapSink   ( fromAXI4Lite_W
                           , onPut (checkAXI4_WFlit, s.w) );
  interface  b = mapSource ( toAXI4Lite_B
                           , onDrop (checkAXI4_BFlit (True), s.b) );
  interface ar = mapSink   ( fromAXI4Lite_AR
                           , onPut (checkAXI4_ARFlit (busSize, True), s.ar) );
  interface  r = mapSource ( toAXI4Lite_R
                           , onDrop (checkAXI4_RFlit (True), s.r) );
endinterface;

function (AXI4_Slave #( id_, addr_, data_
                      , awuser_, wuser_, buser_
                      , aruser_, ruser_))
         fromAXI4LiteToAXI4_Slave (
           AXI4Lite_Slave #( addr_, data_
                           , awuser_, wuser_, buser_
                           , aruser_, ruser_) sLite) = interface AXI4_Slave;
  let busSize = fromInteger(valueOf(data_)/8);
  interface aw = onPut  ( checkAXI4_AWFlit (busSize, True)
                        , mapSink (toAXI4Lite_AW, sLite.aw) );
  interface  w = onPut  ( checkAXI4_WFlit
                        , mapSink (toAXI4Lite_W, sLite.w) );
  interface  b = onDrop ( checkAXI4_BFlit (True)
                        , mapSource (fromAXI4Lite_B (0), sLite.b) );
  interface ar = onPut  ( checkAXI4_ARFlit (busSize, True)
                        , mapSink (toAXI4Lite_AR, sLite.ar) );
  interface  r = onDrop ( checkAXI4_RFlit (True)
                        , mapSource (fromAXI4Lite_R (0), sLite.r) );
endinterface;
