/*-
 * Copyright (c) 2018 Jonathan Woodruff
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

import ConfigReg::*;
import Vector::*;
import FF::*;

// Equal to Bluespec equivelant
module mkUGFFFullOfUniqueInts(FF#(data, depth))
provisos(Log#(depth,logDepth),Bits#(data, data_width),Literal#(data),FShow#(data));
  Reg#(Vector#(depth,data))    rf  <- mkReg(genWith(fromInteger));
  RWire#(data)            enqData  <- mkRWire;
  PulseWire                deqSig  <- mkPulseWire;
  Reg#(Bit#(TAdd#(logDepth,1))) lhead <- mkConfigRegA(fromInteger(valueOf(depth)));
  
  Bool empty = (lhead==0);
  Bool full  = (lhead==fromInteger(valueOf(depth)));
  Bit#(logDepth) head = truncate(lhead);
  
  rule updateRf;
    Vector#(depth,data) newRf = rf;
    Bit#(TAdd#(logDepth,1)) newHead = lhead;
    if (deqSig) begin
      newRf = shiftOutFrom0(0,rf,1);
      newHead = newHead - 1;
    end
    if (enqData.wget() matches tagged Valid .data) begin
      newRf[newHead] = data;
      newHead = newHead + 1;
    end
    rf <= newRf;
    lhead <= newHead;
  endrule
  
  method Action enq(data in);
    enqData.wset(in);
  endmethod
  method Action deq();
    deqSig.send();
  endmethod
  method data first() = rf[0];
  method Bool notFull() = !full;
  method Bool notEmpty() = !empty;
  method Action clear() = action lhead <= 0; endaction;
  method Bit#(TAdd#(logDepth, 1)) remaining() = fromInteger(valueOf(depth)) - lhead;
endmodule
