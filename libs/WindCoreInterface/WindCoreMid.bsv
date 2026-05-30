/*-
 * Copyright (c) 2021-2022 Alexandre Joannou
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

package WindCoreMid;

// This package defines the "mid level" WindCore interface as well as some
// helper types and functions

// Notes:
// * The debug module and the PLIC are wrapped inside this interface
//   (see WindCoreLo for the low level interface which does _not_ wrap these)
// * Reseting should be handled by a standard bluespec Reset, and should reset
//   all of the modules hidden inside it, _including the debug module_
// * The debug module should internally be connected to the appropriate Reset
//   network to be able to reset _all but itself_ upon receiving a reset command
// This assumes that the environment only ever resets the debug module together
// with the rest of the core simultaneously, and only the debug module is
// expected to need to reset all but itself within the core.

// XXX This is a work in progress! XXX

import BlueAXI4 :: *;
import Vector :: *;
import GetPut :: *;
import ClientServer :: *;

// Other control and status interface helpers
// ------------------------------------------
// Control and Status server for general requests to the core
// * ReleaseReq should release the core from a blocking state. It should not
//   generate any response.
// * ReleaseAndSetToHostAddrReq should set the tohost address and release the
//   core from a blocking state. It should not generate any response.
// * StatusReq should generate a response returning a status code from the core.
typedef union tagged {
  void ReleaseReq;
  void StatusReq;
  Bit #(64) ReleaseAndSetToHostAddrReq;
} ControlStatusReq deriving (Bits);
typedef union tagged {
  Bit #(8) StatusRsp;
} ControlStatusRsp deriving (Bits);
typedef Server #(ControlStatusReq, ControlStatusRsp) ControlStatusServer;
// Note:
// Discussions suggest that these interfaces might not actually be needed.
// Specifically, the release mechanism can be handled as back-pressure exercised
// by the environment on the memory interfaces as opposed to an explicit command
// and the status code does not appear to be actively used for much?

// The mid lever WindCore interface
// --------------------------------
interface WindCoreMid #(
// AXI lite subordinate control port parameters
  numeric type t_axls_control_addr
, numeric type t_axls_control_data
, numeric type t_axls_control_awuser
, numeric type t_axls_control_wuser
, numeric type t_axls_control_buser
, numeric type t_axls_control_aruser
, numeric type t_axls_control_ruser
// AXI manager 0 port parameters
, numeric type t_axm_0_id
, numeric type t_axm_0_addr
, numeric type t_axm_0_data
, numeric type t_axm_0_awuser
, numeric type t_axm_0_wuser
, numeric type t_axm_0_buser
, numeric type t_axm_0_aruser
, numeric type t_axm_0_ruser
// AXI manager 1 port parameters
, numeric type t_axm_1_id
, numeric type t_axm_1_addr
, numeric type t_axm_1_data
, numeric type t_axm_1_awuser
, numeric type t_axm_1_wuser
, numeric type t_axm_1_buser
, numeric type t_axm_1_aruser
, numeric type t_axm_1_ruser
// AXI subordinate 0 port parameters
, numeric type t_axs_0_id
, numeric type t_axs_0_addr
, numeric type t_axs_0_data
, numeric type t_axs_0_awuser
, numeric type t_axs_0_wuser
, numeric type t_axs_0_buser
, numeric type t_axs_0_aruser
, numeric type t_axs_0_ruser
// Number of interrupt lines
, numeric type t_n_irq
);

  // Control interfaces
  //////////////////////////////////////////////////////////////////////////////

  // NOTE: the `interface Server #(Bool, Bool) cpu_reset_server` is replaced by
  // the standard bsv managed reset. Note that it should *NOT* reset the debug
  // module in the individual implementations, and a dedicated debug module
  // reset request should be used instead.

  // debug related signals
  // ---------------------
  // NOTE:
  // It is intended that the debug module would eventually be moved out of the
  // cores implementing this interface. In the meantime, the front end to the
  // debug module is exposed here in a Server interface supporting resets, reads
  // and write requests.
  // It is currently expected that Piccolo / Flute / Toooba would handle a
  // debug module reset command using an `assertReset` call (in `MakeResetIfc`)
  // from a `mkReset` module, and use the associated `new_rst` signal as input
  // to the `reset_by` attribute on the appropriate module instances (or
  // similar).
  // This interface should provide the functionalities that used to be supported
  // in Piccolo / Flute / Toooba by:
  // `interface DMI dm_dmi;`
  interface AXI4Lite_Slave #( t_axls_control_addr
                            , t_axls_control_data
                            , t_axls_control_awuser
                            , t_axls_control_wuser
                            , t_axls_control_buser
                            , t_axls_control_aruser
                            , t_axls_control_ruser ) debug_subordinate;
  // Note:
  // The `interface Client #(Bool, Bool) ndm_reset_client;` interface is thought
  // to not be required to appear on the Mid interface. The wiring of the reset
  // request from the debug module to the rest of the core should be handled
  // internally.

  // interrupt related signals
  // -------------------------
  // NOTE:
  // The following interfaces provide the functionality of the Piccolo / Flute /
  // Toooba interfaces:
  // `interface Vector #(t_n_interrupt_sources, PLIC_Source_IFC) core_external_interrupt_sources;`
  // `method Action nmi_req (Bool set_not_clear);`
  // Here, the idea is that the Bool put into the given irq channel will be latched
  // internally.
  interface Vector #(t_n_irq, Put #(Bool)) irq;
  interface Put #(Bool) nmirq;

  // other control and status signals
  // --------------------------------
  // NOTE:
  // The following interfaces provide the functionality of the Piccolo / Flute /
  // Toooba interfaces:
  // `method Action start (Bool is_running, Bit #(64) tohost_addr, Bit #(64) fromhost_addr);`
  // `method Action ma_ddr4_ready;`
  // `method Bit #(8) mv_status;`
  interface ControlStatusServer controlStatusServer;

  // TODO:
  // XXX
  // The following information (tohost) actually sound static to me.
  // It probably does not belong in an interface, but rather, should be passed
  // as module arguments
  // `method Action set_watch_tohost (Bool watch_tohost, Bit #(64) tohost_addr);`
  // `method Bit #(64) mv_tohost_value;`
  // XXX Can we remove this one?
  // method Action set_verbosity (Bit #(4) verbosity, Bit #(64) logdelay);
  // XXX more to discuss:
  // for tandem verification
  // `interface Get #(Info_CPU_to_Verifier)  tv_verifier_info_get;`
  // for RVFI_DII reporting
  // `interface Flute_RVFI_DII_Server rvfi_dii_server;`
  // for perf counters reporting
  // `method Action send_tag_cache_master_events (Vector #(6, Bit #(1)) events);`

  // Memory interfaces
  //////////////////////////////////////////////////////////////////////////////

  // AXI manager 0 port parameters
  interface AXI4_Master #(
    t_axm_0_id
  , t_axm_0_addr
  , t_axm_0_data
  , t_axm_0_awuser
  , t_axm_0_wuser
  , t_axm_0_buser
  , t_axm_0_aruser
  , t_axm_0_ruser
  ) manager_0;
  // AXI manager 1 port parameters
  interface AXI4_Master #(
    t_axm_1_id
  , t_axm_1_addr
  , t_axm_1_data
  , t_axm_1_awuser
  , t_axm_1_wuser
  , t_axm_1_buser
  , t_axm_1_aruser
  , t_axm_1_ruser
  ) manager_1;
  // AXI subordinate 0 port parameters
  interface AXI4_Slave #(
    t_axs_0_id
  , t_axs_0_addr
  , t_axs_0_data
  , t_axs_0_awuser
  , t_axs_0_wuser
  , t_axs_0_buser
  , t_axs_0_aruser
  , t_axs_0_ruser
  ) subordinate_0;

endinterface

endpackage
