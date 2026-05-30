/*-
 * Copyright (c) 2020 Alexandre Joannou
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

import FIFOF      :: *;
import Vector     :: *;
import ConfigReg  :: *;
import SourceSink :: *;

module top (Empty);

  Reg #(Bit #(8)) count <- mkReg (0);
  Reg #(Bit #(8)) cycleCount <- mkReg (0);
  rule cycleCountUp; cycleCount <= cycleCount + 1; endrule

  // pick one here
  let srcsnk <- mkUGSrcSnk_own;
  //let srcsnk <- mkGSrcSnk_own;
  //let srcsnk <- mkUGSrcSnk_UGFIFOF;
  //let srcsnk <- mkGSrcSnk_UGFIFOF;
  //let srcsnk <- mkGSrcSnk_FIFOF;

  let raw_snk = debugSink (srcsnk.sink, $format ("Sink raw side"));
  let raw_src = debugSource (srcsnk.source, $format ("Source raw side"));

  `define NO_LOSS
  `ifdef NO_LOSS
  let snk = raw_snk;
  let src = raw_src;
  `else
  let tmp_snk <- toUnguardedSink (raw_snk);
  let tmp_src <- toUnguardedSource (raw_src, 55);
  let snk = debugSink (tmp_snk, $format ("Sink UG side"));
  let src = debugSource (tmp_src, $format ("Source UG side"));
  `endif

  rule write;
    $display ("%0t - writing %0d", $time, count);
    snk.put (count);
    count <= count + 1;
  endrule
  rule read;
    $display ("%0t - reading %0d", $time, src.peek);
    src.drop;
  endrule

  rule finishing (cycleCount > 20); $finish(); endrule

endmodule

// test modules
////////////////////////////////////////////////////////////////////////////////

interface SrcSnk #(type t);
  interface Source #(t) source;
  interface Sink #(t)   sink;
endinterface

module mkUGSrcSnk_own (SrcSnk #(t))
  provisos ( Bits #(t, t_sz)
           , NumAlias #(2, depth)
           , NumAlias #(TLog #(depth), idx));
  Vector #(depth, Reg #(t)) data <- replicateM (mkRegU);
  Reg #(Bit #(TAdd #(1, idx))) readPtr  <- mkConfigReg (0);
  Reg #(Bit #(TAdd #(1, idx))) writePtr <- mkConfigReg (0);
  Bit #(idx) readPtrLSB  = truncate (readPtr);
  Bit #(idx) writePtrLSB = truncate (writePtr);
  Bit #(1) readPtrMSB  = truncateLSB (readPtr);
  Bit #(1) writePtrMSB = truncateLSB (writePtr);
  Bool empty  = readPtrLSB == writePtrLSB && readPtrMSB == writePtrMSB;
  Bool full  = readPtrLSB == writePtrLSB && readPtrMSB != writePtrMSB;
  interface source = interface Source;
    method canPeek = !empty;
    method peek = data[readPtrLSB];
    method drop = action readPtr <= readPtr + 1; endaction;
  endinterface;
  interface sink = interface Sink;
    method canPut = !full;
    method put (x) = action
      data[writePtrLSB] <= x;
      writePtr <= writePtr + 1;
    endaction;
  endinterface;
endmodule

module mkGSrcSnk_own (SrcSnk #(t)) provisos (Bits #(t, t_sz) );
  let srcsnk <- mkUGSrcSnk_own;
  interface source = toGuardedSource (srcsnk.source);
  interface sink   = toGuardedSink   (srcsnk.sink);
endmodule

module mkGSrcSnk_FIFOF (SrcSnk #(t)) provisos (Bits#(t, t_sz));
  let ff <- mkFIFOF;
  interface source = toSource (ff);
  interface sink   = toSink   (ff);
endmodule

module mkUGSrcSnk_UGFIFOF (SrcSnk #(t)) provisos (Bits #(t, t_sz));
  let ff <- mkUGFIFOF;
  interface source = toSource (ff);
  interface sink   = toSink   (ff);
endmodule

module mkGSrcSnk_UGFIFOF (SrcSnk #(t)) provisos (Bits #(t, t_sz));
  let srcsnk <- mkUGSrcSnk_UGFIFOF;
  interface source = toGuardedSource (srcsnk.source);
  interface sink   = toGuardedSink   (srcsnk.sink);
endmodule
