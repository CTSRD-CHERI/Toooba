/*-
 * Copyright (c) 2021 Alexandre Joannou
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

package WindCoreUtils;

import WindCoreLo  :: *;
import WindCoreMid :: *;
import WindCoreHi  :: *;

import FIFOF      :: *;
import Vector     :: *;
import GetPut     :: *;
import SourceSink :: *;
import AXI4Lite   :: *;
import Routable   :: *;

// Convert a WindCoreLo into a WindCoreMid
// XXX THIS MODULE IS CURRENTLY ONLY HERE AS A PLACE HOLDER XXX
module windCoreLo2Mid #(
  WindCoreLo #( // AXI manager 0 port parameters
                t_axm_0_id
              , t_axm_0_addr
              , t_axm_0_data
              , t_axm_0_awuser
              , t_axm_0_wuser
              , t_axm_0_buser
              , t_axm_0_aruser
              , t_axm_0_ruser
              // AXI manager 1 port parameters
              , t_axm_1_id
              , t_axm_1_addr
              , t_axm_1_data
              , t_axm_1_awuser
              , t_axm_1_wuser
              , t_axm_1_buser
              , t_axm_1_aruser
              , t_axm_1_ruser
              // AXI subordinate 0 port parameters
              , t_axs_0_id
              , t_axs_0_addr
              , t_axs_0_data
              , t_axs_0_awuser
              , t_axs_0_wuser
              , t_axs_0_buser
              , t_axs_0_aruser
              , t_axs_0_ruse) lo
              // PLIC ?
              // Debug Module ?
              )
  (WindCoreMid #( // AXI lite subordinate control port parameters
                  t_axls_control_addr
                , t_axls_control_data
                , t_axls_control_awuser
                , t_axls_control_wuser
                , t_axls_control_buser
                , t_axls_control_aruser
                , t_axls_control_ruser
                // AXI manager 0 port parameters
                , t_axm_0_id
                , t_axm_0_addr
                , t_axm_0_data
                , t_axm_0_awuser
                , t_axm_0_wuser
                , t_axm_0_buser
                , t_axm_0_aruser
                , t_axm_0_ruser
                // AXI manager 1 port parameters
                , t_axm_1_id
                , t_axm_1_addr
                , t_axm_1_data
                , t_axm_1_awuser
                , t_axm_1_wuser
                , t_axm_1_buser
                , t_axm_1_aruser
                , t_axm_1_ruser
                // AXI subordinate 0 port parameters
                , t_axs_0_id
                , t_axs_0_addr
                , t_axs_0_data
                , t_axs_0_awuser
                , t_axs_0_wuser
                , t_axs_0_buser
                , t_axs_0_aruser
                , t_axs_0_ruser
                // Number of interrupt lines
                , t_n_irq));
  // TODO
  return ?;
endmodule

// This module provides an AXI4Lite subordinate to control some interrupt
// interfaces (Put #(Bool)) received as arguments. 2 vectors of up to 32
// interrupt interfaces are received, one for conventional irqs and one for
// non-maskable irqs. 32-bit writes to the subordinate control the setting and
// clearing of the irq lines. Reads return a SLVERR.
// - 32-bit offset 0 (byte offset 0x00000000):
//   set irq lines that correspond to high bits in the written data
// - 32-bit offset 1 (byte offset 0x00000004):
//   clear irq lines that correspond to high bits in the written data
// - 32-bit offset 2 (byte offset 0x00000008):
//   set nmirq lines that correspond to high bits in the written data
// - 32-bit offset 3 (byte offset 0x0000000c):
//   clear nmirq lines that correspond to high bits in the written data
module mkIrqAXI4Lite_Subordinate #( Vector #(t_n_irq, Put #(Bool)) irqs
                                  , Vector #(t_n_nmirq, Put #(Bool)) nmirqs )
  (AXI4Lite_Slave # ( t_axls_control_addr
                    , t_axls_control_data
                    , t_axls_control_awuser
                    , t_axls_control_wuser
                    , t_axls_control_buser
                    , t_axls_control_aruser
                    , t_axls_control_ruser ))
  provisos ( Add #(t_n_irq, _n0, 32)
           , Add #(t_n_nmirq, _n1, 32)
           , Add #(t_n_irq, _n2, t_axls_control_data)
           , Add #(t_n_nmirq, _n3, t_axls_control_data) );
  // write response fifo
  FIFOF #(AXI4Lite_BFlit #(t_axls_control_buser)) bff <- mkFIFOF;
  // write request sinks
  Tuple2 #( Sink #(AXI4Lite_AWFlit #( t_axls_control_addr
                                    , t_axls_control_awuser))
          , Sink #(AXI4Lite_WFlit #( t_axls_control_data
                                   , t_axls_control_wuser)) )
    writeSinks <- splitSink (interface Sink;
        method canPut = True;
        method put (writeflit) = action
          match {.awflit, .wflit} = writeflit;
          Vector #(t_n_irq, Bool) irqBitField =
            unpack (truncate (wflit.wdata));
          Vector #(t_n_nmirq, Bool) nmirqBitField =
            unpack (truncate (wflit.wdata));
          function Action setIrq (Put #(Bool) irqIfc, Bool doSet) = action
            if (doSet) irqIfc.put (True);
          endaction;
          function Action clearIrq (Put #(Bool) irqIfc, Bool doClear) = action
            if (doClear) irqIfc.put (False);
          endaction;
          case (awflit.awaddr[3:2])
            // first 32-bits: set irqs
            0: zipWithM (setIrq, irqs, irqBitField);
            // second 32-bits: clear irqs
            1: zipWithM (clearIrq, irqs, irqBitField);
            // third 32-bits: set nmirqs
            2: zipWithM (setIrq, nmirqs, nmirqBitField);
            // fourth 32-bits: clear nmirqs
            3: zipWithM (clearIrq, nmirqs, nmirqBitField);
          endcase
          bff.enq (AXI4Lite_BFlit { bresp: OKAY, buser: ? });
        endaction;
      endinterface);
  match {.awIfc, .wIfc} = writeSinks;
  match {.arIfc, .rIfc} <-
    mkReqRspPost (mkFIFOF, constFn (AXI4Lite_RFlit { rdata: ?
                                                   , rresp: SLVERR
                                                   , ruser: ? }));
  interface aw = awIfc;
  interface  w = wIfc;
  interface  b = toSource (bff);
  interface ar = arIfc;
  interface  r = rIfc;
endmodule

// Core function to convert a WindCoreMid into a WindCoreHi, optionally
// expose extra AXI4 Lite subordinates passed as arguments, and optionally
// connect up to 32 interrupts
module windCoreMid2Hi_Core #(
  WindCoreMid #( // AXI lite subordinate control port parameters
                 t_axls_control_addr
               , t_axls_control_data
               , t_axls_control_awuser
               , t_axls_control_wuser
               , t_axls_control_buser
               , t_axls_control_aruser
               , t_axls_control_ruser
               // AXI manager 0 port parameters
               , t_axm_0_id
               , t_axm_0_addr
               , t_axm_0_data
               , t_axm_0_awuser
               , t_axm_0_wuser
               , t_axm_0_buser
               , t_axm_0_aruser
               , t_axm_0_ruser
               // AXI manager 1 port parameters
               , t_axm_1_id
               , t_axm_1_addr
               , t_axm_1_data
               , t_axm_1_awuser
               , t_axm_1_wuser
               , t_axm_1_buser
               , t_axm_1_aruser
               , t_axm_1_ruser
               // AXI subordinate 0 port parameters
               , t_axs_0_id
               , t_axs_0_addr
               , t_axs_0_data
               , t_axs_0_awuser
               , t_axs_0_wuser
               , t_axs_0_buser
               , t_axs_0_aruser
               , t_axs_0_ruser
               // Number of interrupt lines
               , t_n_irq) mid
               // other AXI4 Lite subordinates to map
               , Vector #(m, Tuple2 #( AXI4Lite_Slave #( t_axls_control_addr
                                                       , t_axls_control_data
                                                       , t_axls_control_awuser
                                                       , t_axls_control_wuser
                                                       , t_axls_control_buser
                                                       , t_axls_control_aruser
                                                       , t_axls_control_ruser )
                                     , Range #(t_axls_control_addr))) others
               // extra irqs to wire up
               , Vector #(t_n_irq_extra, ReadOnly #(Bool)) irqs)
  (WindCoreHi #( // AXI lite subordinate control port parameters
                 t_axls_control_addr
               , t_axls_control_data
               , t_axls_control_awuser
               , t_axls_control_wuser
               , t_axls_control_buser
               , t_axls_control_aruser
               , t_axls_control_ruser
               // AXI manager 0 port parameters
               , t_axm_0_id
               , t_axm_0_addr
               , t_axm_0_data
               , t_axm_0_awuser
               , t_axm_0_wuser
               , t_axm_0_buser
               , t_axm_0_aruser
               , t_axm_0_ruser
               // AXI manager 1 port parameters
               , t_axm_1_id
               , t_axm_1_addr
               , t_axm_1_data
               , t_axm_1_awuser
               , t_axm_1_wuser
               , t_axm_1_buser
               , t_axm_1_aruser
               , t_axm_1_ruser
               // AXI subordinate 0 port parameters
               , t_axs_0_id
               , t_axs_0_addr
               , t_axs_0_data
               , t_axs_0_awuser
               , t_axs_0_wuser
               , t_axs_0_buser
               , t_axs_0_aruser
               , t_axs_0_ruser))
  provisos ( Add #(7, t0_, t_axls_control_addr)
           , Add #(32, 0, t_axls_control_data)
           , Add #(t_n_irq_extra, t1_, t_n_irq)
           , Add #(t_n_irq, t2_, 32) );

  // prioritise extra interrupt lines
  // --------------------------------
  Vector #(t_n_irq, Put #(Bool)) prioIrqs = mid.irq;
  // for each extra irq, both wire it to the matching mid interface's irq line
  // and nullify the effects of affecting it from the AXI4Lite slave
  for (Integer i = 0; i < valueOf (t_n_irq_extra); i = i + 1) begin
    rule prioritiseIrq; mid.irq[i].put (irqs[i]); endrule
    prioIrqs[i] = interface Put; method put (x) = noAction; endinterface;
  end

  // AXI4Lite manager
  // ----------------
  let ctrlShim <- mkAXI4LiteShimFF;
  Vector #(1, AXI4Lite_Master #( t_axls_control_addr
                               , t_axls_control_data
                               , t_axls_control_awuser
                               , t_axls_control_wuser
                               , t_axls_control_buser
                               , t_axls_control_aruser
                               , t_axls_control_ruser ))
    managers = cons (ctrlShim.master, nil);

  // AXI4Lite subordinates
  // ---------------------
  // Requests received over the WindCoreHi axi lite control port are routed as
  // follows:
  // 0x0000_0000 -> 0x0000_0fff : Debug Unit
  // 0x0000_1000 -> 0x0000_1fff : Interrupt lines
  // 0x0000_2000 -> 0x0000_2fff : Others (still unclear what exactly)
  // Additional address ranges can be received together with additional AXI4Lite
  // subordinates in the "others" argument to this module
  // TODO: Ask Nikhil about this...
  Vector #(3, Tuple2 #( AXI4Lite_Slave #( t_axls_control_addr
                                        , t_axls_control_data
                                        , t_axls_control_awuser
                                        , t_axls_control_wuser
                                        , t_axls_control_buser
                                        , t_axls_control_aruser
                                        , t_axls_control_ruser )
                      , Range #(t_axls_control_addr) ))
    subs = newVector;
  // debug traffic
  subs[0] = tuple2 ( zero_AXI4Lite_Slave_user (mid.debug_subordinate)
                   , Range { base: 'h0000_0000, size: 'h0000_1000 } );
  // irq traffic
  let irqSub <- mkIrqAXI4Lite_Subordinate (prioIrqs, cons (mid.nmirq, nil));
  subs[1] = tuple2 (irqSub, Range { base: 'h0000_1000, size: 'h0000_1000 });
  // rest of the traffic
  subs[2] = tuple2 (culDeSac, Range { base: 'h0000_2000, size: 'h0000_1000 });
  // append with other subordinates
  match {.subordinates, .ranges} = unzip (append (subs, others));

  // wire up axi lite traffic
  // ------------------------
  mkAXI4LiteBus (routeFromMappingTable (ranges), managers, subordinates);

  // exported interface
  // ------------------
  interface control_subordinate = ctrlShim.slave;
  interface manager_0 = mid.manager_0;
  interface manager_1 = mid.manager_1;
  interface subordinate_0 = mid.subordinate_0;
endmodule

module windCoreMid2Hi #(
  WindCoreMid #( // AXI lite subordinate control port parameters
                 t_axls_control_addr
               , t_axls_control_data
               , t_axls_control_awuser
               , t_axls_control_wuser
               , t_axls_control_buser
               , t_axls_control_aruser
               , t_axls_control_ruser
               // AXI manager 0 port parameters
               , t_axm_0_id
               , t_axm_0_addr
               , t_axm_0_data
               , t_axm_0_awuser
               , t_axm_0_wuser
               , t_axm_0_buser
               , t_axm_0_aruser
               , t_axm_0_ruser
               // AXI manager 1 port parameters
               , t_axm_1_id
               , t_axm_1_addr
               , t_axm_1_data
               , t_axm_1_awuser
               , t_axm_1_wuser
               , t_axm_1_buser
               , t_axm_1_aruser
               , t_axm_1_ruser
               // AXI subordinate 0 port parameters
               , t_axs_0_id
               , t_axs_0_addr
               , t_axs_0_data
               , t_axs_0_awuser
               , t_axs_0_wuser
               , t_axs_0_buser
               , t_axs_0_aruser
               , t_axs_0_ruser
               // Number of interrupt lines
               , t_n_irq) mid)
  (WindCoreHi #( // AXI lite subordinate control port parameters
                 t_axls_control_addr
               , t_axls_control_data
               , t_axls_control_awuser
               , t_axls_control_wuser
               , t_axls_control_buser
               , t_axls_control_aruser
               , t_axls_control_ruser
               // AXI manager 0 port parameters
               , t_axm_0_id
               , t_axm_0_addr
               , t_axm_0_data
               , t_axm_0_awuser
               , t_axm_0_wuser
               , t_axm_0_buser
               , t_axm_0_aruser
               , t_axm_0_ruser
               // AXI manager 1 port parameters
               , t_axm_1_id
               , t_axm_1_addr
               , t_axm_1_data
               , t_axm_1_awuser
               , t_axm_1_wuser
               , t_axm_1_buser
               , t_axm_1_aruser
               , t_axm_1_ruser
               // AXI subordinate 0 port parameters
               , t_axs_0_id
               , t_axs_0_addr
               , t_axs_0_data
               , t_axs_0_awuser
               , t_axs_0_wuser
               , t_axs_0_buser
               , t_axs_0_aruser
               , t_axs_0_ruser))
  provisos ( Add #(7, t0_, t_axls_control_addr)
           , Add #(32, 0, t_axls_control_data)
           , Add #(t_n_irq, t1_, 32) );
  let hi <- windCoreMid2Hi_Core (mid, nil, nil);
  return hi;
endmodule

endpackage
