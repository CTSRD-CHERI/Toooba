/*-
 * Copyright (c) 2020 Jonas Fiala
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

package Monitored;

import SourceSink :: *;
import DefaultValue :: *;

// Wrapper interface for reporting events of a given interface
interface Monitored #(type t_ifc, type t_evts);
  interface t_ifc ifc;
  interface ReadOnly #(t_evts) events;
endinterface

// Report arbitrary events upon Source drop
module monitorSourceWith #(Source #(t) src, function t_evts f (t x))
                          (Monitored #(Source #(t), t_evts))
  provisos (DefaultValue #(t_evts), Bits #(t_evts, t_evts_sz));
  Wire #(t_evts) evt <- mkDWire (defaultValue);
  function fAct (x) = evt._write (f (x));
  interface ifc = onDrop (fAct, src);
  interface events = regToReadOnly (evt); // NOTE: Wire ifc == Reg ifc
endmodule

// Report drop events on a Source
module monitorSource #(Source #(t) src) (Monitored #(Source #(t), Bool));
  // NOTE: defaultValue for Bool in defined to be False
  let m <- monitorSourceWith (src, constFn (True));
  return m;
endmodule

// Report arbitrary events upon Sink put
module monitorSinkWith #(Sink #(t) snk, function t_evts f (t x))
                        (Monitored #(Sink #(t), t_evts))
  provisos (DefaultValue #(t_evts), Bits #(t_evts, t_evts_sz));
  Wire #(t_evts) evt <- mkDWire (defaultValue);
  function fAct (x) = evt._write (f (x));
  interface ifc = onPut (fAct, snk);
  interface events = regToReadOnly (evt); // NOTE: Wire ifc == Reg ifc
endmodule

// Report put events on a Sink
module monitorSink #(Sink #(t) snk) (Monitored #(Sink #(t), Bool));
  // NOTE: defaultValue for Bool in defined to be False
  let m <- monitorSinkWith (snk, constFn (True));
  return m;
endmodule

endpackage
