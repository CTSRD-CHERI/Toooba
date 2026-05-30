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

package WindCoreLo;

// This package defines the "low level" WindCore interface as well as some
// helper types and functions
// HOPE: This interface is implemented by the Piccolo, Flute and Toooba cores.

// XXX This is a work in progress! XXX

// The low lever WindCore interface
// --------------------------------
interface WindCoreLo #(
// AXI manager 0 port parameters
  numeric type t_axm_0_id
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

  // TODO

endinterface

endpackage
