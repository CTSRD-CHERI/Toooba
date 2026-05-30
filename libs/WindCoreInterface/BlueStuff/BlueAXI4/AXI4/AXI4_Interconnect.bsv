/*-
 * Copyright (c) 2018-2022 Alexandre Joannou
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

package AXI4_Interconnect;

export mkAXI4Bus;
export mkAXI4Bus_Sig;
export mkAXI4Switch;

import List   :: *;
import Vector :: *;
import Printf :: *;

import AXI4_Types   :: *;
import AXI4_Utils   :: *;
import SourceSink   :: *;
import MasterSlave  :: *;
import ListExtra    :: *;
import Interconnect :: *;
import Routable     :: *;

`define PARAMS t_addr, t_data, t_awuser, t_wuser, t_buser, t_aruser, t_ruser
`define MPARAMS t_mid, `PARAMS
`define SPARAMS t_sid, `PARAMS


///////////////////////////////////////////
// AXI4 Write merge/split - Read helpers //
////////////////////////////////////////////////////////////////////////////////

module fromAXI4MasterToWriteMasterReadMaster #(AXI4_Master #(`MPARAMS) m)
  (Tuple2 #( Master #( AXI4_WriteFlit #( t_mid, t_addr, t_data
                                       , t_awuser, t_wuser )
                     , AXI4_BFlit #(t_mid, t_buser) )
           , Master #( AXI4_ARFlit #(t_mid, t_addr, t_aruser)
                     , AXI4_RFlit #(t_mid, t_data, t_ruser) ) ));
  let merged <- mergeWrite (m.aw, m.w);
  return tuple2 ( interface Master;
                    interface req = merged;
                    interface rsp = m.b;
                  endinterface
                , interface Master;
                    interface req = m.ar;
                    interface rsp = m.r;
                  endinterface );
endmodule

module fromAXI4SlaveToWriteSlaveReadSlave #(AXI4_Slave #(`SPARAMS) s)
  (Tuple2 #( Slave #( AXI4_WriteFlit #(t_sid, t_addr, t_data, t_awuser, t_wuser)
                    , AXI4_BFlit #(t_sid, t_buser) )
           , Slave #( AXI4_ARFlit #(t_sid, t_addr, t_aruser)
                    , AXI4_RFlit #(t_sid, t_data, t_ruser) ) ));
  let split <- splitWrite (s.aw, s.w);
  return tuple2 ( interface Slave;
                    interface req = split;
                    interface rsp = s.b;
                  endinterface
                , interface Slave;
                    interface req = s.ar;
                    interface rsp = s.r;
                  endinterface );
endmodule

//////////////
// AXI4 bus //
////////////////////////////////////////////////////////////////////////////////
// This AXI4 bus will route requests from AXI4 masters to an AXI4 slave based on
// the provided routing function, and will automatically take care of augmenting
// the ID field for appropriate routing back of the response (hence the size
// difference between the master side ID field and the slave side ID field as
// captured in the provisos)

module mkAXI4Bus #(
  function Vector #(nSlaves, Bool) route (Bit #(t_addr) val)
, Vector #(nMasters, AXI4_Master #(`MPARAMS)) masters
, Vector #(nSlaves,  AXI4_Slave  #(`SPARAMS)) slaves
) (Empty) provisos (
  Add #(1, a__, nSlaves)
, Add #(1, b__, nMasters)
, Add #(t_mid, TLog #(nMasters), t_sid)
);

  // prepare masters and slaves
  let mPairs <- mapM (fromAXI4MasterToWriteMasterReadMaster, masters);
  match {.write_masters, .read_masters} = unzip (mPairs);
  let sPairs <- mapM (fromAXI4SlaveToWriteSlaveReadSlave, slaves);
  match {.write_slaves, .read_slaves} = unzip (sPairs);

  // connect with standard busses
  mkRelaxedTwoWayBus (route, write_masters, write_slaves);
  mkRelaxedTwoWayBus (route, read_masters,  read_slaves);

endmodule

module mkAXI4Bus_Sig #(
  function Vector #(nSlaves, Bool) route (Bit #(t_addr) val)
, Vector #(nMasters, AXI4_Master_Sig #(`MPARAMS)) masters
, Vector #(nSlaves,  AXI4_Slave_Sig  #(`SPARAMS)) slaves
) (Empty) provisos (
  Add #(1, a__, nSlaves)
, Add #(1, b__, nMasters)
, Add #(t_mid, TLog #(nMasters), t_sid)
);
  let msNoSig <- mapM (fromAXI4_Master_Sig, masters);
  let ssNoSig <- mapM (fromAXI4_Slave_Sig,  slaves);
  mkAXI4Bus (route, msNoSig, ssNoSig);
endmodule

/////////////////
// AXI4 switch //
////////////////////////////////////////////////////////////////////////////////
// This module takes care of routing the requests from AXI4 masters to AXI4
// slaves using the provided request routing function and the address field, and
// routes the responses from AXI4 slaves to AXI4 masters using the provided
// response routing function. It DOES NOT alter the ID field in any way, unlike
// the mkAXI4Bus module.

module mkAXI4Switch #(
  function Vector #(nSlaves, Bool) routeReq (Bit #(t_addr) val)
, function Vector #(nMasters, Bool) routeRsp (Bit #(t_mid) val)
, Vector #(nMasters, AXI4_Master #(`MPARAMS)) masters
, Vector #(nSlaves,  AXI4_Slave  #(`SPARAMS)) slaves
) (Empty) provisos (
  Add #(1, a__, nSlaves)
, Add #(1, b__, nMasters)
, Add #(0, t_mid, t_sid) // Masters and Slaves with same width ID field
);

  // prepare masters and slaves
  let mPairs <- mapM (fromAXI4MasterToWriteMasterReadMaster, masters);
  match {.write_masters, .read_masters} = unzip (mPairs);
  let sPairs <- mapM (fromAXI4SlaveToWriteSlaveReadSlave, slaves);
  match {.write_slaves, .read_slaves} = unzip (sPairs);

  // connect with standard busses
  mkUpDownSwitch (routeReq, routeRsp, write_masters, write_slaves);
  mkUpDownSwitch (routeReq, routeRsp, read_masters, read_slaves);

endmodule

endpackage

`undef PARAMS
`undef MPARAMS
`undef SPARAMS
