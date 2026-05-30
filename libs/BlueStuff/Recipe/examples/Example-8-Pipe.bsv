/*-
 * Copyright (c) 2018-2021 Alexandre Joannou
 * Copyright (c) 2018 Matthew Naylor
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

import SourceSink :: *;
import MasterSlave :: *;
import Recipe :: *;
#include "RecipeMacros.h"

module top ();

  PulseWire done <- mkPulseWire;
  // Pipeline latches
  let latch_0_1 <- mkRegU;
  let latch_1_2 <- mkRegU;
  // pipeline description
  function Recipe shiftLRFlip (
    Tuple3#(Bit#(8), Bit#(8), Bit#(8)) args,
    Sink#(Bit#(8)) ressnk);
    return Pipe
      action
        match {.a, .b, .c} = args;
        let tmp = a << b;
        $display("%0t -- Stage 1, %b << %0d ===> %b", $time, a, b, tmp);
        latch_0_1 <= tuple2(tmp, c);
      endaction, action
        match {.a, .b} = latch_0_1;
        let tmp = a >> b;
        $display("%0t -- Stage 2, %b >> %0d ===> %b", $time, a, b, tmp);
        latch_1_2 <= tmp;
      endaction, action
        let a = latch_1_2;
        let tmp = ~a;
        $display("%0t -- Stage 3, %b ===> %b", $time, a, tmp);
        ressnk.put(tmp);
      endaction
    End;
  endfunction

  let shifter <- mkRecipeFSMSlave(shiftLRFlip);

  Recipe r = Par
    FastSeq
      shifter.req.put(tuple3('b00000001, 5, 3)),
      shifter.req.put(tuple3('b00001000, 9, 3)),
      shifter.req.put(tuple3('b10000000, 0, 3)),
      shifter.req.put(tuple3('b00001000, 2, 2))
    End,
    FastSeq
    action
      let x <- get(shifter.rsp);
      $display("%0t -- res: %b", $time, x);
    endaction, action
      let x <- get(shifter.rsp);
      $display("%0t -- res: %b", $time, x);
    endaction, action
      let x <- get(shifter.rsp);
      $display("%0t -- res: %b", $time, x);
    endaction, action
      let x <- get(shifter.rsp);
      $display("%0t -- res: %b", $time, x);
    endaction,
    done.send
    End
  End;
  RecipeFSM m <- mkRecipeFSM(r);

  // Start runing the recipe
  Reg#(Bool) triggered <- mkReg(False);
  rule run (!triggered);
    $display("starting at time %0t", $time);
    $display("------------------------------------------");
    m.trigger;
    triggered <= True;
  endrule

  // On the recipe's last cyle, terminate simulation
  rule endSim (done);
    $display("------------------------------------------");
    $display("finishing at time %0t", $time);
    $finish(0);
  endrule

endmodule
