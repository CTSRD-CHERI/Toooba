/*-
 * Copyright (c) 2020 Jonas Fiala
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

// This file is only provided as a convenience to consuming projects that want a
// BitVectorable instance available for the AXI4_Events type.
//
// For library compartmentalisation concerns, such an instance should not be
// defined in the AXI files, as those would pick up a dependency on
// PerformanceMonitor.bsv. Equally, such an instance should not be defined in
// the PerformanceMonitor.bsv file as it would pick up a dependency on the AXI
// bits of the library.
//
// This is a concern from the perspective of eventually splitting BlueStuff into
// more meaningful atoms.
//
// Providing an orphan instance in an explicitly imported file is here
// considered the lesser evil.

package AXI4_Events_BitVectorable_Instance;

import AXI4 :: *;
import PerformanceMonitor :: *;

instance BitVectorable#(AXI4_Events, 1, n) provisos (Bits#(AXI4_Events, n));
  function to_vector = struct_to_vector;
endinstance

endpackage
