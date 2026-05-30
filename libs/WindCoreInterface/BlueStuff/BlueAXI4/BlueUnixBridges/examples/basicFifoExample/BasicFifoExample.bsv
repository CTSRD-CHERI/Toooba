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

package BasicFifoExample;

import SourceSink :: *;
import BlueUnixBridges :: *;

typedef struct {
  t_a a;
  t_b b;
} MyReqType #(type t_a, type t_b) deriving (Bits, FShow);

typedef struct {
  t_x x;
  t_y y;
} MyRspType #(type t_x, type t_y) deriving (Bits, FShow);

module testUnixFifo (Empty)
  provisos ( Alias #(t_req, MyReqType #(Bit #(12), Bit #(11)))
           , Alias #(t_rsp, MyRspType #(Bit #(22), Bit #(132))) );

  Sink #(t_req) reqSnk <- mkUnixFifoSink ("fifos/reqSource");
  Source #(t_rsp) rspSrc <- mkUnixFifoSource ("fifos/rspSink");

  Reg #(Bit #(12)) reqCnt <- mkReg (5);
  rule sendReq;
    t_req req = MyReqType { a: ~reqCnt >> reqCnt [1:0]
                          , b: truncate (reqCnt) };
    reqSnk.put (req);
    reqCnt <= reqCnt + 1;
    $display ("sent req: ", fshow (req), " (raw: ", fshow (pack (req)), ")");
  endrule
  rule rcvRsp;
    t_rsp rsp <- get (rspSrc);
    $display ("recieved rsp: ", fshow (rsp), " (raw: ", fshow (pack (rsp)), ")");
  endrule
  let cycle <- mkReg (0);
  rule isAlive;
    if (cycle > 1000000) begin
      //$display ("alive!");
      cycle <= 0;
    end else cycle <= cycle + 1;
  endrule
endmodule

endpackage
