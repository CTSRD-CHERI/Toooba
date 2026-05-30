/*-
 * Copyright (c) 2022 Alexandre Joannou
 * All rights reserved.
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

// AXI4 imports
import AXI4_Types :: *;
import AXI4_Channels_Utils :: *;

// BlueStuff import
import BlueBasics :: *;

// Standard
import FIFOF :: *;
import Connectable :: *;

///////////////////////////
// ID namespace crossing //
////////////////////////////////////////////////////////////////////////////////

module change_AXI4_Master_Id #( // received parameters
                                parameter NumProxy #(nbEntries) proxyTableSz
                              , parameter NumProxy #(regsCntSz) proxyRegsCntSz
                                // received master port
                              , AXI4_Master #(t_id_a,b,c,d,e,f,g,h) mstr_a )
  // returned interface
  (AXI4_Master #(t_id_b,b,c,d,e,f,g,h))
  // constraints
  provisos (Add #(_, TLog #(nbEntries), t_id_b));
  Tuple2 #( AXI4_Slave  #(t_id_a,b,c,d,e,f,g,h)
          , AXI4_Master #(t_id_b,b,c,d,e,f,g,h) )
    ifcs <- mkAXI4IDNameSpaceCrossing (proxyTableSz, proxyRegsCntSz);
  match {.slv_a, .mstr_b} = ifcs;
  mkConnection (mstr_a, slv_a);
  return mstr_b;
endmodule

module change_AXI4_Slave_Id #( // received parameters
                               parameter NumProxy #(nbEntries) proxyTableSz
                             , parameter NumProxy #(regsCntSz) proxyRegsCntSz
                               // received master port
                             , AXI4_Slave #(t_id_a,b,c,d,e,f,g,h) slv_a )
  // returned interface
  (AXI4_Slave #(t_id_b,b,c,d,e,f,g,h))
  // constraints
  provisos (Add #(_, TLog #(nbEntries), t_id_a));
  Tuple2 #( AXI4_Slave  #(t_id_b,b,c,d,e,f,g,h)
          , AXI4_Master #(t_id_a,b,c,d,e,f,g,h) )
    ifcs <- mkAXI4IDNameSpaceCrossing (proxyTableSz, proxyRegsCntSz);
  match {.slv_b, .mstr_a} = ifcs;
  mkConnection (mstr_a, slv_a);
  return slv_b;
endmodule

module mkAXI4IDNameSpaceCrossing
  // received parameters
  #( parameter NumProxy #(nbEntries) proxyTableSz
   , parameter NumProxy #(regsCntSz) proxyRegsCntSz )
  // returned interface
  (Tuple2 #( AXI4_Slave  #( id_X, addr_, data_
                          , awuser_, wuser_, buser_, aruser_, ruser_ )
           , AXI4_Master #( id_Y, addr_, data_
                          , awuser_, wuser_, buser_, aruser_, ruser_ ) ))
  // constraints
  provisos (Add #(_, TLog #(nbEntries), id_Y));
  RegistrationTable #(Bit #(id_X), Bit #(id_Y))
    idsTable <- mkRegistrationTable (proxyTableSz, proxyRegsCntSz);
  RegistrationTable #(Bit #(id_X), Bit #(id_Y)) idTables[2] <- virtualize (idsTable, 2);
  match {.aw_X, .b_X, .aw_Y, .b_Y}
    <- mkAXI4WritesIDNameSpaceCrossing (idTables[0]);
  match {.ar_X, .r_X, .ar_Y, .r_Y}
    <- mkAXI4ReadsIDNameSpaceCrossing (idTables[1]);
  let wff <- mkFIFOF;
  return tuple2 (
    interface AXI4_Slave;
      interface aw = aw_X;
      interface  w = toSink (wff);
      interface  b = b_X;
      interface ar = ar_X;
      interface  r = r_X;
    endinterface
  , interface AXI4_Master;
      interface aw = aw_Y;
      interface  w = toSource (wff);
      interface  b = b_Y;
      interface ar = ar_Y;
      interface  r = r_Y;
    endinterface );
endmodule

module mkAXI4WritesIDNameSpaceCrossing
  // received parameters
  #( RegistrationTable #(Bit #(id_X), Bit #(id_Y)) idsTable )
  // returned interface
  (Tuple4 #( Sink #(AXI4_AWFlit #(id_X, addr_, awuser_))
           , Source #(AXI4_BFlit #(id_X, buser_))
           , Source #(AXI4_AWFlit #(id_Y, addr_, awuser_))
           , Sink #(AXI4_BFlit #(id_Y, buser_)) ));
  let awff_X <- mkFIFOF;
  let bff_X  <- mkFIFOF;
  let awff_Y <- mkFIFOF;
  let bff_Y  <- mkFIFOF;
  // handle requests
  rule req;
    AXI4_AWFlit #(id_X, addr_, awuser_) awflit_X = awff_X.first;
    let mawid_Y <- idsTable.registerData (awflit_X.awid);
    case (mawid_Y) matches
      tagged Valid .awid_Y: begin
        awff_X.deq;
        awff_Y.enq (mapAXI4_AWFlit_awid (constFn (awid_Y), awflit_X));
      end
    endcase
  endrule
  // handle responses
  rule rsp;
    AXI4_BFlit #(id_Y, buser_) bflit_Y = bff_Y.first;
    let mbid_X <- idsTable.deRegisterKey (bflit_Y.bid);
    case (mbid_X) matches
      tagged Valid .bid_X: begin
        bff_Y.deq;
        bff_X.enq (mapAXI4_BFlit_bid (constFn (bid_X), bflit_Y));
      end
    endcase
  endrule
  // interface
  return tuple4 ( toSink (awff_X), toSource (bff_X)
                , toSource (awff_Y), toSink (bff_Y) );
endmodule

module mkAXI4ReadsIDNameSpaceCrossing
  // received parameters
  #( RegistrationTable #(Bit #(id_X), Bit #(id_Y)) idsTable )
  // returned interface
  (Tuple4 #( Sink #(AXI4_ARFlit #(id_X, addr_, aruser_))
           , Source #(AXI4_RFlit #(id_X, data_, ruser_))
           , Source #(AXI4_ARFlit #(id_Y, addr_, aruser_))
           , Sink #(AXI4_RFlit #(id_Y, data_, ruser_)) ));
  let arff_X <- mkFIFOF;
  let rff_X  <- mkFIFOF;
  let arff_Y <- mkFIFOF;
  let rff_Y  <- mkFIFOF;
  // handle requests
  rule req;
    AXI4_ARFlit #(id_X, addr_, aruser_) arflit_X = arff_X.first;
    let marid_Y <- idsTable.registerData (arflit_X.arid);
    case (marid_Y) matches
      tagged Valid .arid_Y: begin
        arff_X.deq;
        arff_Y.enq (mapAXI4_ARFlit_arid (constFn (arid_Y), arflit_X));
      end
    endcase
  endrule
  // handle responses
  rule rsp;
    AXI4_RFlit #(id_Y, data_, ruser_) rflit_Y = rff_Y.first;
    let mrid_X = idsTable.dataLookup (rflit_Y.rid);
    case (mrid_X) matches
      tagged Valid .rid_X: begin
        rff_Y.deq;
        rff_X.enq (mapAXI4_RFlit_rid (constFn (rid_X), rflit_Y));
        if (rflit_Y.rlast)
          // this should never fail
          let _ <- idsTable.deRegisterKey (rflit_Y.rid);
      end
    endcase
  endrule
  // interface
  return tuple4 ( toSink (arff_X), toSource (rff_X)
                , toSource (arff_Y), toSink (rff_Y) );
endmodule
