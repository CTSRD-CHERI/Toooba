/*-
 * Copyright (c) 2021 Jonathan Woodruff
 * Copyright (c) 2022-2024 Franz Fuchs
 * All rights reserved.
 *
 * This software was developed by the University of  Cambridge
 * Department of Computer Science and Technology under the
 * SIPP (Secure IoT Processor Platform with Remote Attestation)
 * project funded by EPSRC: EP/S030868/1
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
 * under the License is distributed on an "AS IS" BASIS, WITxHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * @BERI_LICENSE_HEADER_END@
 */

`include "ProcConfig.bsv"
import ProcTypes::*;

typedef 8 StlPredKeySize;
`ifdef ParTag
typedef TSub#(6, PTBits) StlPredIndexSize;
`else
typedef 6 StlPredIndexSize;
`endif
typedef 3 StlPredValueSize;
typedef 2 StlPredAssociativity;

typedef Bit#(StlPredKeySize) StlPredKey;
typedef Bit#(StlPredIndexSize) StlPredIndex;
typedef Int#(StlPredValueSize) StlPredValue;
typedef Bit#(TAdd#(StlPredKeySize, StlPredIndexSize)) HashValue;

interface STLPred;
    method Action update(HashValue pc_hash, Bool waited, Bool killedLd);
    method Bool pred(HashValue pc_hash);
`ifdef ParTag
    method Action setPTID(PTIndex ptid);
    method Action shootdown(PTIndex ptid);
`endif
endinterface
