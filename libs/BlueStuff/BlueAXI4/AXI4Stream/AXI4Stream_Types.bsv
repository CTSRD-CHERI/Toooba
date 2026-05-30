/*-
 * Copyright (c) 2021 Ivan Ribeiro
 * Copyright (c) 2021 Alexandre Joannou
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

// Based on AXI4-Stream specification from:
//
// AMBA AXI-Stream Protocol Specification
// ARM IHI 0051B (ID122117)
// https://developer.arm.com/documentation/ihi0051/b/

package AXI4Stream_Types;

import Connectable :: *;

// BlueBasics import
import SourceSink :: *;

import AXI4_Common_Types :: *;

typedef struct {
  Bit #(data_)            tdata;
  Bit #(TDiv #(data_, 8)) tstrb;
  Bit #(TDiv #(data_, 8)) tkeep;
  Bool                    tlast;
  Bit #(id_)              tid;
  Bit #(dest_)            tdest;
  Bit #(user_)            tuser;
} AXI4Stream_Flit #( numeric type id_
                   , numeric type data_
                   , numeric type dest_
                   , numeric type user_)
deriving (Bits, FShow);

(* always_ready, always_enabled *)
interface AXI4Stream_Master_Sig #( numeric type id_
                                 , numeric type data_
                                 , numeric type dest_
                                 , numeric type user_);
  method Bit #(data_)            tdata;
  method Bit #(TDiv #(data_, 8)) tstrb;
  method Bit #(TDiv #(data_, 8)) tkeep;
  method Bool                    tlast;
  method Bit #(id_)              tid;
  method Bit #(dest_)            tdest;
  method Bit #(user_)            tuser;
  method Bool                    tvalid;
  (* prefix="" *) method Action  tready (Bool tready);
endinterface

(* always_ready, always_enabled *)
interface AXI4Stream_Slave_Sig #( numeric type id_
                                , numeric type data_
                                , numeric type dest_
                                , numeric type user_);
  (* prefix="" *) method Action tflit ( Bool                    tvalid
                                      , Bit #(data_)            tdata
                                      , Bit #(TDiv #(data_, 8)) tstrb
                                      , Bit #(TDiv #(data_, 8)) tkeep
                                      , Bool                    tlast
                                      , Bit #(id_)              tid
                                      , Bit #(dest_)            tdest
                                      , Bit #(user_)            tuser);
  method Bool tready;
endinterface

typedef Source #(AXI4Stream_Flit #(id_, data_, dest_, user_))
        AXI4Stream_Master #( numeric type id_
                           , numeric type data_
                           , numeric type dest_
                           , numeric type user_);

typedef Sink #(AXI4Stream_Flit #(id_, data_, dest_, user_))
        AXI4Stream_Slave #( numeric type id_
                          , numeric type data_
                          , numeric type dest_
                          , numeric type user_);


instance CulDeSac#(AXI4Stream_Master #(id_, data_, dest_, user_));
  function culDeSac = nullSource;
endinstance

instance CulDeSac#(AXI4Stream_Slave #(id_, data_, dest_, user_));
  function culDeSac = nullSink;
endinstance

instance CulDeSac#(AXI4Stream_Master_Sig #(id_, data_, dest_, user_));
  function culDeSac = interface AXI4Stream_Master_Sig;
    method tdata     = ?;
    method tstrb     = ?;
    method tkeep     = ?;
    method tlast     = ?;
    method tid       = ?;
    method tdest     = ?;
    method tuser     = ?;
    method tvalid    = False;
    method tready(_) = noAction;
  endinterface;
endinstance

instance CulDeSac#(AXI4Stream_Slave_Sig #(id_, data_, dest_, user_));
  function culDeSac = interface AXI4Stream_Slave_Sig;
    method tflit (a,b,c,d,e,f,g,h) = noAction;
    method tready = True;
  endinterface;
endinstance

interface AXI4Stream_Shim #( numeric type id_
                           , numeric type data_
                           , numeric type dest_
                           , numeric type user_);
  interface AXI4Stream_Master #(id_, data_, dest_, user_) master;
  interface AXI4Stream_Slave #(id_, data_, dest_, user_) slave;
endinterface


endpackage
