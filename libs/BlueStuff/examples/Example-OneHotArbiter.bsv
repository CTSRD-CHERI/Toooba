/*-
 * Copyright (c) 2018 Alexandre Joannou
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
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

import OneHotArbiter :: *;

import List :: *;
import FIFOF :: *;
import LFSR :: *;

//`define PREFERRED_ARBITER(x) mkFairOneHotArbiter(x)
`define PREFERRED_ARBITER(x) mkStaticOneHotArbiter(x)

module top (Empty);

  Integer n = 6;
  let participants <- replicateM(n, mkFIFOF);
  let arbiter <- `PREFERRED_ARBITER(participants);
  let isNext <- replicateM(n, mkPulseWire);

  Reg#(Bool) isReset <- mkReg(True);
  Reg#(Bit#(5)) delay_count <- mkReg(0);
  let delay_cmp <- replicateM(n, mkLFSR_16);

  rule doReset (isReset); isReset <= False; endrule
  rule delayCount; delay_count <= delay_count + 1; endrule
  for (Integer i = 0; i < n; i = i + 1) begin
    rule init_delay (isReset); delay_cmp[i].seed(fromInteger(i)); endrule
    rule doEnq(!isReset && delay_cmp[i].value[15:11] >= delay_count);
      delay_cmp[i].next;
      participants[i].enq(fromInteger(i));
    endrule
    rule doDeq (isNext[i]);
      $display("%0t -- elected participant %0d", $time, participants[i].first);
      participants[i].deq;
    endrule
  end

  rule arbitrate;
    function pulse(c, w) = action if (c) w.send(); endaction;
    let nexts <- arbiter.next;
    let _ <- zipWithM(pulse, nexts, isNext);
  endrule

  let cnt <- mkReg(0);
  rule count; cnt <= cnt + 1; endrule
  rule terminate(cnt > 50); $finish(0); endrule

endmodule
