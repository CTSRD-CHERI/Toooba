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

// AXI4 imports
import AXI4_Types :: *;

// BlueStuff import
import BlueBasics :: *;

// Standard
import FIFOF :: *;

////////////////////////////////
// AXI4 Write channel helpers //
////////////////////////////////////////////////////////////////////////////////

module mergeWrite#(
  Source#(AXI4_AWFlit#(id_, addr_, awuser_)) aw,
  Source#(AXI4_WFlit#(data_, wuser_)) w)
  (Source#(AXI4_WriteFlit#(id_, addr_, data_, awuser_, wuser_)));
  let debug = False;

  let awug <- toUnguardedSource (aw, ?);
  let wug <- toUnguardedSource (w, ?);

  let awff <- mkFIFOF;
  let wff  <- mkFIFOF;
  let flitLeft <- mkReg(0);
  let doDrop   <- mkPulseWire;
  let outflit  <- mkDWire(OtherFlit(wff.first));
  let newCanPeek = (flitLeft == 0) ? awff.notEmpty && wff.notEmpty
                                   : wff.notEmpty;

  //rule passFlit;
  //  outflit <= (flitLeft == 0) ? FirstFlit(tuple2(aw.peek, w.peek))
  //                             : OtherFlit(w.peek);
  //endrule

  rule awFlit(awug.canPeek); awff.enq (awug.peek); awug.drop; endrule
  rule wFlit(wug.canPeek); wff.enq (wug.peek); wug.drop; endrule

  rule passFlit (flitLeft == 0);
    outflit <= FirstFlit(tuple2(awff.first, wff.first));
  endrule

  rule genFirst (doDrop && flitLeft == 0);
    awff.deq;
    wff.deq;
    // burst length given by AxLEN + 1
    flitLeft <= awff.first.awlen;
  endrule

  rule genOther (doDrop && flitLeft > 0);
    let wflit = wff.first;
    wff.deq;
    // decrement flit counter
    flitLeft <= flitLeft - 1;
    // check for error conditions
    if (wflit.wlast && flitLeft > 1) begin
      $display("%m - Expecting more write data flits");
      $finish(0);
    end else if (!wflit.wlast && flitLeft == 1) begin
      $display("%m - Expecting last write data flit");
      $finish(0);
    end
  endrule

  rule debug_print (debug);
    $display ("--- mergeWrite --- newCanPeek: ", fshow (newCanPeek));
    $display ("--- mergeWrite --- flitLeft: ", fshow (flitLeft));
    $display ("--- mergeWrite --- doDrop: ", fshow (doDrop));
    $display ("--- mergeWrite --- outflit: ", fshow (outflit));
  endrule

  method canPeek = newCanPeek;
  method peek if (newCanPeek) = outflit;
  method drop if (newCanPeek) = doDrop.send;
endmodule

module splitWrite#(
  Sink#(AXI4_AWFlit#(id_, addr_, awuser_)) aw,
  Sink#(AXI4_WFlit#(data_, wuser_)) w)
  (Sink#(AXI4_WriteFlit#(id_, addr_, data_, awuser_, wuser_)));
  let debug = False;

  let awug <- toUnguardedSink (aw);
  let wug <- toUnguardedSink (w);

  let flitLeft <- mkReg(0);
  let doPut <- mkWire;
  let canDoPut = (flitLeft == 0) ? awug.canPut && wug.canPut
                                 : wug.canPut;

  rule putFirst (flitLeft == 0
                 && awug.canPut
                 && wug.canPut);
    case (doPut) matches
      tagged FirstFlit{.awflit, .wflit}: begin
        awug.put(awflit);
        wug.put(wflit);
        // burst length given by AxLEN + 1
        flitLeft <= awflit.awlen;
      end
      default: begin
        $display("splitWrite - Expecting FirstFlit of merged write");
        $finish(0);
      end
    endcase
  endrule

  rule putOther (flitLeft > 0
                 && wug.canPut);
    case (doPut) matches
      tagged OtherFlit .wflit: begin
        wug.put(wflit);
        // decrement flit counter
        flitLeft <= flitLeft - 1;
        // check for error conditions
        if (wflit.wlast && flitLeft > 1) begin
          $display("splitWrite - Expecting more write data flits");
          $finish(0);
        end else if (!wflit.wlast && flitLeft == 1) begin
          $display("splitWrite - Expecting last write data flit");
          $finish(0);
        end
      end
      default: begin
        $display("splitWrite - Expecting OtherFlit of merged write");
        $finish(0);
      end
    endcase
  endrule

  rule debug_print (debug);
    $display ("--- splitWrite --- canDoPut: ", fshow (canDoPut));
    $display ("--- splitWrite --- flitLeft: ", fshow (flitLeft));
    $display ("--- splitWrite --- doPut: ", fshow (doPut));
  endrule

  method put(x) if (canDoPut) = action doPut <= x; endaction;
  method canPut = canDoPut;

endmodule
