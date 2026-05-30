/*-
 * Copyright (c) 2021 Alexandre Joannou
 * All rights reserved.
 *
 * This material is based upon work supported by the DoD Information Analysis
 * Center Program Management Office (DoD IAC PMO), sponsored by the Defense
 * Technical Information Center (DTIC) under Contract No. FA807518D0004.  Any
 * opinions, findings and conclusions or recommendations expressed in this
 * material are those of the author(s) and do not necessarily reflect the views
 * of the Air Force Installation Contracting Agency (AFICA).
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

import "DPI-C" function chandle mem_create (longint unsigned memSize);

import "DPI-C" function void mem_init ( chandle mem_ptr
                                      , string hexfile
                                      , longint unsigned offset );

import "DPI-C" function void mem_zero (chandle mem_ptr);

import "DPI-C" function longint unsigned mem_read ( chandle mem_ptr
                                                  , longint unsigned addr
                                                  , longint unsigned size );

import "DPI-C" function void mem_write ( chandle mem_ptr
                                       , longint unsigned addr
                                       , byte be
                                       , longint unsigned data );

import "DPI-C" function void mem_clean (chandle mem_ptr);
