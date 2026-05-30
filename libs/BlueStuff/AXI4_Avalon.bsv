/*-
 * Copyright (c) 2023 Alexandre Joannou
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

package AXI4_Avalon;

import FIFOF :: *;
import SpecialFIFOs :: *;
import GetPut :: *;
import ClientServer :: *;
import Connectable :: *;

import BlueBasics :: *;
import BlueAXI4 :: *;
import BlueAvalon :: *;

export axi4Rsp2AvalonMMRsp;
export avalonMMRsp2AXI4Rsp;
export axi4WriteReq2AvalonMMWriteReq;
export axi4ReadReq2AvalonMMReadReq;
export avalonMMReadRsp2AXI4ReadRsp;
export mkAXI4Manager_to_AvalonMMHost;
export mkAXI4Manager_to_PipelinedAvalonMMHost;

// debug prints
Integer curLvl = 0;
function Action dbgPrint (Integer tgtLvl, Fmt msg) = action
  if (curLvl >= tgtLvl) $display ("<%0t> ", $time, msg);
endaction;

////////////////////////////////////////////////////////////////////////////////
function Bit #(2) axi4Rsp2AvalonMMRsp (AXI4_Resp rsp) = case (rsp)
  OKAY: 2'h00;
  EXOKAY: 2'b01;
  SLVERR: 2'b10;
  DECERR: 2'b11;
endcase;

function AXI4_Resp avalonMMRsp2AXI4Rsp (Bit #(2) rsp) = case (rsp)
  2'b00: OKAY;
  2'b01: SLVERR; //EXOKAY;
  2'b10: SLVERR;
  2'b11: DECERR;
endcase;

function AvalonMMRequest #(addr_, data_) axi4WriteReq2AvalonMMWriteReq
  ( AXI4_AWFlit #(id_, addr_, awuser_) awflit
  , AXI4_WFlit #(data_, wuser_) wflit ) =
  AvalonMMRequest { address: awflit.awaddr
                  , lock: awflit.awlock == EXCLUSIVE
                  , byteenable: wflit.wstrb
                  , operation: tagged Write wflit.wdata };

function AvalonMMRequest #(addr_, data_) axi4ReadReq2AvalonMMReadReq
  (AXI4_ARFlit #(id_, addr_, aruser_) arflit)
  provisos ( NumAlias #(TDiv #(data_, 8), strb_)
           , NumAlias #(TLog #(strb_), strb_idx_)
           , Add #(_a, strb_idx_, addr_) );
  Bit #(strb_idx_) offset = truncate (arflit.araddr);
  Bit #(strb_) be = ~(~0 << fromAXI4_Size (arflit.arsize)) << offset;
  return AvalonMMRequest { address: arflit.araddr
                         , lock: arflit.arlock == EXCLUSIVE
                         , byteenable: be
                         , operation: tagged Read };
endfunction

function AXI4_RFlit #(id_, data_, ruser_) avalonMMReadRsp2AXI4ReadRsp
  (Bit #(id_) rid, AvalonMMResponse #(data_) rsp) =
  AXI4_RFlit { rid: rid
             , rdata: rsp.operation.Read
             , rresp: avalonMMRsp2AXI4Rsp (rsp.response)
             , rlast: True
             , ruser: ? };

////////////////////////////////////////////////////////////////////////////////
module mkAXI4Manager_to_Avalon #(
    function module #(
               Tuple2 #( Slave #( AvalonMMRequest #(addr_, data_)
                                , AvalonMMResponse #(data_) )
                       , ret_ )) transactor
  , AXI4_Master #( id_, addr_, data_
                 , awuser_, wuser_, buser_
                 , aruser_, ruser_ ) axm )
  (ret_)
  provisos ( Add #(_a, SizeOf #(AXI4_Len), addr_)
           , Add #(_b, TLog #(TDiv #(data_, 8)), addr_) );
  // deburst the axi manager
  AXI4_Shim #(id_, addr_, data_ , awuser_, wuser_, buser_ , aruser_, ruser_)
    //deBurst <- mkAXI4DeBurst;
    deBurst <- mkBurstToNoBurst;
  mkConnection (axm, deBurst.slave);
  // pipelined avalon mm transactor
  match {.avSlv, .avmmh} <- transactor;
  // convert axi traffic into avalon traffic
  let is_read_rsp = avSlv.rsp.canPeek
    && (avSlv.rsp.peek.operation matches tagged Read .* ? True : False);
  let write_id_ff <- mkFIFOF;
  let read_id_ff <- mkFIFOF;
  (* descending_urgency = "forward_write_req, forward_read_req" *)
  rule forward_write_req;
    dbgPrint (1, $format ("%m.forward_write_req"));
    let awflit <- get (deBurst.master.aw);
    let  wflit <- get (deBurst.master.w);
    avSlv.req.put (axi4WriteReq2AvalonMMWriteReq (awflit, wflit));
    write_id_ff.enq (awflit.awid);
  endrule
  rule forward_read_req;
    dbgPrint (1, $format ("%m.forward_read_req"));
    let arflit <- get (deBurst.master.ar);
    avSlv.req.put (axi4ReadReq2AvalonMMReadReq (arflit));
    read_id_ff.enq (arflit.arid);
  endrule
  rule forward_read_rsp (is_read_rsp);
    dbgPrint (1, $format ("%m.forward_read_rsp"));
    avSlv.rsp.drop;
    let rid <- get (read_id_ff);
    deBurst.master.r.put (avalonMMReadRsp2AXI4ReadRsp (rid, avSlv.rsp.peek));
  endrule
  rule forward_write_rsp (!is_read_rsp);
    dbgPrint (1, $format ("%m.forward_write_rsp"));
    avSlv.rsp.drop;
    let bid <- get (write_id_ff);
    deBurst.master.b.put (AXI4_BFlit {bid: bid, bresp: OKAY, buser: ?});
  endrule
  // return an avalon host interface
  return avmmh;
endmodule

module mkAXI4Manager_to_AvalonMMHost #(
  AXI4_Master #( id_, addr_, data_
               , awuser_, wuser_, buser_
               , aruser_, ruser_) axm
  ) (AvalonMMHost #(addr_, data_))
  provisos ( Add #(_a, SizeOf #(AXI4_Len), addr_)
           , Add #(_b, TLog #(TDiv #(data_, 8)), addr_) );
  let ifc <- mkAXI4Manager_to_Avalon (avalonMMHostTransactor, axm);
  return ifc;
endmodule

module mkAXI4Manager_to_PipelinedAvalonMMHost #(
  AXI4_Master #( id_, addr_, data_
               , awuser_, wuser_, buser_
               , aruser_, ruser_) axm
  ) (PipelinedAvalonMMHost #(addr_, data_))
  provisos ( Add #(_a, SizeOf #(AXI4_Len), addr_)
           , Add #(_b, TLog #(TDiv #(data_, 8)), addr_) );
  NumProxy #(4) depth_pxy = ?;
  let ifc <-
    mkAXI4Manager_to_Avalon (pipelinedAvalonMMHostTransactor (depth_pxy), axm);
  return ifc;
endmodule
////////////////////////////////////////////////////////////////////////////////

endpackage
