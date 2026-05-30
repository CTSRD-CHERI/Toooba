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

package Monitored;

import SourceSink :: *;
import DefaultValue :: *;
//import MasterSlave :: *;

// Wrapper interface for reporting events of a given interface
interface Monitored#(type originalIfc, type events_t);
  interface originalIfc ifc;
  interface ReadOnly#(events_t) events;
endinterface

// Report drop events on a Source
module monitorSource #(Source#(t) s) (Monitored#(Source#(t), Bool));
  PulseWire evt <- mkPulseWire;
  interface ifc = onDrop (constFn (evt.send), s);
  interface events = pulseWireToReadOnly(evt);
endmodule

// Report arbitrary events upon Source drop
module monitorSourceWith #(Source#(t) s, function evt_t f(t x))
                          (Monitored#(Source#(t), evt_t))
  provisos (DefaultValue#(evt_t), Bits#(evt_t, evt_sz));
  Wire#(evt_t) evt <- mkDWire(defaultValue);
  function fAct (x) = evt._write(f(x));
  interface ifc = onDrop (fAct, s);
  interface events = regToReadOnly(evt); // NOTE: Wire ifc == Reg ifc
endmodule

// Report put events on a Sink
module monitorSink #(Sink#(t) s) (Monitored#(Sink#(t), Bool));
  PulseWire evt <- mkPulseWire;
  interface ifc = onPut (constFn (evt.send), s);
  interface events = pulseWireToReadOnly(evt);
endmodule

// Report arbitrary events upon Sink put
module monitorSinkWith #(Sink#(t) s, function evt_t f(t x))
                        (Monitored#(Sink#(t), evt_t))
  provisos (DefaultValue#(evt_t), Bits#(evt_t, evt_sz));
  Wire#(evt_t) evt <- mkDWire(defaultValue);
  function fAct (x) = evt._write(f(x));
  interface ifc = onPut (fAct, s);
  interface events = regToReadOnly(evt); // NOTE: Wire ifc == Reg ifc
endmodule

/* TODO
// Report drop and put events on a Master
module monitorMaster #(Master#(req, resp) m)
                      (Monitored#(Master#(req, resp), MasterEvents));
endmodule

// Report drop and put events on a Master
module monitorSlave #(Slave#(req, resp) s)
                     (Monitored#(Slave#(req, resp), SlaveEvents));
endmodule
*/

endpackage
