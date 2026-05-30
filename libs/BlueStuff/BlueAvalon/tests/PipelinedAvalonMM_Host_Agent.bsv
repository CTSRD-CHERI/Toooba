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

package PipelinedAvalonMM_Host_Agent;

import BlueBasics :: *;
import AvalonMemoryMapped :: *;

import Connectable :: *;
import FIFOF :: *;
import SpecialFIFOs :: *;
import StmtFSM :: *;

`define ADDR_W 32
`define DATA_W 32
`define DELAY  5


Integer verboselvl = 3;
function Action lvlprint (Integer lvl, Fmt msg) =
  when (verboselvl >= lvl, $display ("<%0t> ", $time, msg));

function Action checkRsp ( Maybe #(Bit #(`DATA_W)) expected
                         , AvalonMMResponse #(`DATA_W) rsp) = action
    case (tuple2 (expected, rsp.operation)) matches
    {tagged Valid .x, tagged Read .y}: begin
      lvlprint (2, $format ( "HOST> expected read rsp: ", fshow (x)
                           , ", got read rsp: ", fshow (y) ) );
      if (x != y) $finish;
    end
    {tagged Invalid, tagged Write}:
      lvlprint (2,  $format ( "HOST> expected write rsp, got write rsp" ) );
    {.x, .y}: begin
      lvlprint (2, $format ( "HOST> expected rsp: ", fshow (x)
                           , ", got rsp: ", fshow (y) ) );
      $finish;
    end
  endcase
endaction;

module mkPipelinedAvalonMMHost (PipelinedAvalonMMHost #(`ADDR_W, `DATA_W));
  NumProxy #(8) depthProxy = ?;
  let {slave, ifc} <- pipelinedAvalonMMHostTransactor (depthProxy);

  let expectedRsp <- mkSizedFIFOF (8);
  let cntReq <- mkRegU;
  let cntRsp <- mkRegU;
  Integer nb_transaction = 5;
  mkAutoFSM (seq
    par
      for ( cntReq <= 0
          ; cntReq < fromInteger (nb_transaction)
          ; cntReq <= cntReq + 1 ) action
        lvlprint (1, $format ("HOST> FSM 1"));
        AvalonMMRequest #(`ADDR_W, `DATA_W) avreq = ?;
        avreq.address = cntReq;
        avreq.lock = False;
        avreq.byteenable = ~0;
        avreq.operation = tagged Read;
        slave.req.put (avreq);
        expectedRsp.enq (Valid (cntReq));
        lvlprint (1, $format ("HOST> sent: ", fshow (avreq)));
        lvlprint (1, $format ( "HOST> expecting read response "
                             , fshow (cntReq) ));
      endaction
      for ( cntRsp <= 0
          ; cntRsp < fromInteger (nb_transaction)
          ; cntRsp <= cntRsp + 1 ) action
        lvlprint (1, $format ("HOST> FSM 2"));
        let avrsp <- get (slave.rsp);
        checkRsp (expectedRsp.first, avrsp);
        expectedRsp.deq;
      endaction
    endpar
    $display ("success");
  endseq);

  //Reg #(Bit #(`ADDR_W)) addrCnt <- mkReg (0);
  //let expectedRsp <- mkSizedFIFOF (8);

  //rule genReq (addrCnt < fromInteger ((nb_transaction * (`DATA_W / 8))));
  //  Bool odd = unpack (addrCnt [fromInteger (log2 (`DATA_W / 8))]);
  //  AvalonMMRequest #(`ADDR_W, `DATA_W) req =
  //    AvalonMMRequest { address: addrCnt
  //                    , lock: False
  //                    , byteenable: ~0
  //                    , operation: (odd) ? tagged Write addrCnt : tagged Read };
  //  tprint ($format ("HOST> sent: ", fshow (req)));
  //  tprint ($format ( "HOST> expecting "
  //                  , (odd) ? $format ("write response")
  //                          : $format ("read response ") + fshow (addrCnt) ));
  //  slave.req.put (req);
  //  expectedRsp.enq ((odd) ? Invalid : Valid (addrCnt));
  //  addrCnt <= addrCnt + (`DATA_W / 8);
  //endrule

  //rule getRsp (slave.rsp.canPeek && expectedRsp.notEmpty);
  //  case (tuple2 (expectedRsp.first, slave.rsp.peek.operation)) matches
  //    {tagged Valid .x, tagged Read .y}: begin
  //      tprint ( $format ( "HOST> expected read rsp: ", fshow (x)
  //                       , ", got read rsp: ", fshow (y) ) );
  //      if (x != y) $finish;
  //    end
  //    {tagged Invalid, tagged Write}:
  //      tprint ( $format ( "HOST> expected write rsp, got write rsp" ) );
  //    {.x, .y}: begin
  //      tprint ( $format ( "HOST> expected rsp: ", fshow (x)
  //                       , ", got rsp: ", fshow (y) ) );
  //      $finish;
  //    end
  //  endcase
  //  if (    slave.rsp.peek.operation.Read
  //       >= fromInteger ((nb_transaction - 1) * (`DATA_W / 8)) ) begin
  //    tprint ($format ("success"));
  //    $finish;
  //  end
  //  slave.rsp.drop;
  //  expectedRsp.deq;
  //endrule

  return ifc;
endmodule

module mkPipelinedAvalonMMAgent (PipelinedAvalonMMAgent #(`ADDR_W, `DATA_W));
  NumProxy #(2) depthProxy = ?;
  let {master, ifc} <- pipelinedAvalonMMAgentTransactor (depthProxy);

  // artificial dealy in the agent
  let delay <- mkReg (`DELAY);
  rule dec_delay (delay > 0); delay <= delay - 1; endrule

  rule handleReq (delay == 0);
    let req = master.req.peek;
    let rsp = case (req.operation) matches
      tagged Read: AvalonMMResponse { response: 2'h00
                                    , operation: tagged Read req.address };
      tagged Write .*: AvalonMMResponse { response: 2'h00
                                        , operation: tagged Write };
    endcase;
    lvlprint (1, $format ( "AGENT> received: ", fshow (req)
                         , "\n       sending: ", fshow (rsp) ) );
    master.req.drop;
    master.rsp.put (rsp);
    delay <= `DELAY;
  endrule

  return ifc;
endmodule

module simTop (Empty);
  let h <- mkPipelinedAvalonMMHost;
  let a <- mkPipelinedAvalonMMAgent;
  (* fire_when_enabled, no_implicit_conditions *)
  rule debug;
    lvlprint (2, $format ("----------------------------------------"));
    lvlprint (2, $format (fshow (h), "\n", fshow (a)));
  endrule
  mkConnection (h, a);

endmodule

`undef ADDR_W
`undef DATA_W
`undef DELAY

endpackage
