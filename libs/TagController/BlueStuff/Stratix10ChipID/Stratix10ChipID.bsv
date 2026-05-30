/*
 * Copyright (c) 2021 Simon W. Moore
 * Copyright (c) 2022 Alexandre Joannou
 * All rights reserved.
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
 *
 * ----------------------------------------------------------------------------
 *
 * Read the Stratix 10 Chip ID
 */

package Stratix10ChipID;

import GetPut  :: *;
import FIFOF   :: *;
import Clocks  :: *;
import AXI4Lite :: *;
import SourceSink :: *;

interface RawStratix10ChipID;
  method Action   start;
  method Bit#(64) chip_id;
endinterface

import "BVI" chipid =
  module mkRawStratix10ChipID(RawStratix10ChipID);
    method start() enable (readid);
    method chip_id chip_id() ready (data_valid);
    schedule (chip_id) C  (chip_id);
    schedule (start)   C  (start);
    schedule (start)   SB (chip_id);
    default_clock clk (clk, (*unused*) clk_gate);
    default_reset rst (reset);
  endmodule

module mkStratix10ChipID(Get#(Bit#(64)));
  FIFOF#(Bit#(64))    idfifo <- mkFIFOF1;
  Reset               invRst <- invertCurrentReset();
  RawStratix10ChipID  getid <- mkRawStratix10ChipID(reset_by invRst);
  Reg#(Bit#(4))  start_timer <- mkReg(0);

  /*
     Note: 'start' triggers 'readid' and the Chip ID docs say:
       "The readid signal is used to read the ID value from the
       device. Every time the signal change value from 1 to 0, the IP
       core triggers the read ID operation. You must drive the signal
       to 0 when unused. To start the read ID operation, drive the signal
       high for at least 3 clock cycles, then pull it low. The IP core
       starts reading the value of the chip ID."
     start_timer achieves this.
   */

  rule trigger (idfifo.notFull && (msb(start_timer)==0));
     getid.start();
     start_timer <= start_timer+1;
  endrule

  rule store (msb(start_timer)==1);
    Bit#(64) id = getid.chip_id();
    idfifo.enq(id);
    start_timer <= 0;
  endrule

  return toGet(idfifo);
endmodule

module mkStratix10ChipID_Sim#(Bit#(64) default_id)(Get#(Bit#(64)));
  Reg#(Bit#(64)) idreg <- mkReg(default_id);
  return toGet(idreg);
endmodule

module mkAXI4_Stratix10ChipID (AXI4Lite_Slave #( addr_, 32
                                               , awuser_, wuser_, buser_
                                               , aruser_, ruser_));
  Get #(Bit #(64)) chip_id_reader <-
    (genC) ? mkStratix10ChipID_Sim (10) // Use "10" as chip id in simulation for now.
           : mkStratix10ChipID;
  let axiShim <- mkAXI4LiteShimFF;
  // read requests handling, i.e. return the Stratix10 Chip ID
  rule read_req;
    let r <- get (axiShim.master.ar);
    let chip_id <- get (chip_id_reader);
    let rsp = AXI4Lite_RFlit { rdata: (r.araddr[2] == 1'b0)
                                      ? truncate (chip_id)
                                      : truncateLSB (chip_id)
                             , rresp: OKAY
                             , ruser: ? };
    axiShim.master.r.put (rsp);
  endrule
  // write requests handling, i.e. always ignnore write and return success
  rule write_req;
    let aw <- get (axiShim.master.aw);
    let w <- get (axiShim.master.w);
    let rsp = AXI4Lite_BFlit { bresp: OKAY, buser: ? };
    axiShim.master.b.put (rsp);
  endrule
  // interface
  return axiShim.slave;
endmodule

endpackage: Stratix10ChipID
