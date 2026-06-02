/*-
 * Copyright (c) 2018 Matthew Naylor
 * Copyright (c) 2018 Alexandre Joannou
 * All rights reserved.
 *
 * This software was partly developed by the University of Cambridge
 * Computer Laboratory as part of the Partially-Ordered Event-Triggered
 * Systems (POETS) project, funded by EPSRC grant EP/N031768/1.
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

package Socket;

// Access named sockets on the file system in simulation.

import Vector :: *;
import Clocks :: *;

// Imports from C
// --------------
import "BDPI" function ActionValue#(Bit#(64)) serv_socket_create_nameless(Bit#(32) dflt_port);
import "BDPI" function ActionValue#(Bit#(64)) serv_socket_create(String name, Bit#(32) dflt_port);
import "BDPI" function Action serv_socket_init(Bit#(64) ptr);
import "BDPI" function ActionValue#(Bit#(32))
  serv_socket_get8(Bit#(64) ptr);
import "BDPI" function ActionValue#(Bool)
  serv_socket_put8(Bit#(64) ptr, Bit#(8) b);
import "BDPI" function ActionValue#(Bool)
  serv_socket_put8_blocking(Bit#(64) ptr, Bit#(8) b);
import "BDPI" function ActionValue#(Bit#(n))
  serv_socket_getN(Bit#(64) ptr, Bit#(32) nbytes);
import "BDPI" function ActionValue#(Bool)
  serv_socket_putN(Bit#(64) ptr, Bit#(32) nbytes, Bit#(n) b);

// Wrappers
// --------

interface Socket#(numeric type n, numeric type m);
  method ActionValue#(Maybe#(Vector#(n, Bit#(8)))) get;
  method ActionValue#(Bool) put(Vector#(m, Bit#(8)) data);
endinterface

module mkSocket#(String name, Integer dflt_port) (Socket#(n,m));
  let    clk <- exposeCurrentClock;
  Reg#(Bool)      is_initialized <- mkSyncRegFromCC(False, clk);
  Reg#(Bit#(64)) serv_socket_ptr <- mkRegU;

  rule do_init (!is_initialized);
    Bit#(64) tmp = ?;
    if (name == "") tmp <- serv_socket_create_nameless(fromInteger(dflt_port));
    else tmp <- serv_socket_create(name, fromInteger(dflt_port));
    serv_socket_init(tmp);
    serv_socket_ptr <= tmp;
    is_initialized  <= True;
  endrule

  method get if (is_initialized) = actionvalue
    Vector#(n, Bit#(8)) res = replicate(0);
    Bit#(32) retVal = 0;
    for (Integer i = 0; i < valueOf(n); i = i+1) begin
      if (retVal != -1) retVal <- serv_socket_get8(serv_socket_ptr);
      if (retVal != -1) res[i] = truncate(retVal); 
    end
    if (retVal != -1) return Valid(res);
    else return Invalid;
  endactionvalue;

  method put(data) if (is_initialized) = actionvalue
    Bool retVal = True;
    for (Integer i = 0; i < valueOf(m); i = i+1) begin
      if (retVal) retVal <- serv_socket_put8_blocking(serv_socket_ptr, data[i]);
    end
    return retVal;
  endactionvalue;
endmodule

endpackage
