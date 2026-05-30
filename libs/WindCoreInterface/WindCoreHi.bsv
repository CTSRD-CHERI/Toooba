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

package WindCoreHi;

import AXI4 :: *;
import AXI4Lite :: *;

// This package defines the "hi level" WindCore interfaces.
// It defines both a "non-sig" and a "sig" version of the hi level interface
// for easy bluespec component composition and for clean verilog generation.
// This interface aims to factor the control signals from the WindCoreLo
// interface into a single AXILite subordinate port, and re export the other
// memory ports.

// NOTE: typically, these two versions of the same interface would be defined
// via a macro, but it seams the verilog preprocessor used by bsc is not
// powerful enough to express this. For this reason interface is defined twice,
// and should be maintained accordingly.

/////////////////////////////////////
// "non sig in-bluespec" interface //
////////////////////////////////////////////////////////////////////////////////

interface WindCoreHi #(
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
);

  // Control interface
  ////////////////////

  // AXI lite subordinate control port
  interface AXI4Lite_Slave #(
    t_axls_control_addr
  , t_axls_control_data
  , t_axls_control_awuser
  , t_axls_control_wuser
  , t_axls_control_buser
  , t_axls_control_aruser
  , t_axls_control_ruser
  ) control_subordinate;

  // Memory interfaces
  ////////////////////

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

////////////////////////////////
// Replicated "sig" interface //
////////////////////////////////////////////////////////////////////////////////

interface WindCoreHi_Sig #(
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
);

  // Control interface
  ////////////////////

  // AXI lite subordinate control port
  interface AXI4Lite_Slave_Sig #(
    t_axls_control_addr
  , t_axls_control_data
  , t_axls_control_awuser
  , t_axls_control_wuser
  , t_axls_control_buser
  , t_axls_control_aruser
  , t_axls_control_ruser
  ) control_subordinate;

  // Memory interfaces
  ////////////////////

  // AXI manager 0 port parameters
  interface AXI4_Master_Sig #(
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
  interface AXI4_Master_Sig #(
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
  interface AXI4_Slave_Sig #(
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

////////////////////////////////
// convert "non-sig" to "sig" //
////////////////////////////////////////////////////////////////////////////////

module toWindCoreHi_Sig #(
  WindCoreHi #( // AXI lite subordinate control port parameters
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
              , t_axs_0_ruser) ifc)
  (WindCoreHi_Sig #( // AXI lite subordinate control port parameters
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
                   , t_axs_0_ruser));
  let control_subordinate_sig <- toAXI4Lite_Slave_Sig (ifc.control_subordinate);
  let manager_0_sig <- toAXI4_Master_Sig (ifc.manager_0);
  let manager_1_sig <- toAXI4_Master_Sig (ifc.manager_1);
  let subordinate_0_sig <- toAXI4_Slave_Sig (ifc.subordinate_0);
  interface control_subordinate = control_subordinate_sig;
  interface manager_0 = manager_0_sig;
  interface manager_1 = manager_1_sig;
  interface subordinate_0 = subordinate_0_sig;
endmodule

endpackage
