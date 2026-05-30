/*-
 * Copyright (c) 2020 Jonas Fiala
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

package PerformanceMonitor;

import Vector :: *;
import ConfigReg :: *;

// A module which wants to count events must return some vector of events
// However it is easier to count the events as a Struct within a module
// So if the Struct is an instance of this class it can be returned as is
typeclass BitVectorable#(type from, numeric type n, numeric type m)
  dependencies (from determines (n, m));
  function Vector#(m, Bit#(n)) to_vector (from e);
endtypeclass

instance BitVectorable#(Vector#(m, Bit#(n)), n, m);
  function to_vector = id;
endinstance

// A Bit#(n) will be converted to a 1 element vector
instance BitVectorable#(Bit#(n), n, 1);
  function to_vector = replicate;
endinstance

function Vector#(mm, Bit#(nn)) to_large_vector (from e)
  provisos (BitVectorable#(from, n, m), Add#(a__, n, nn), Add#(b__, m, mm));
  return append(map(zeroExtend, to_vector(e)), replicate(0));
endfunction

// Use to_vector = struct_to_vector
// with BitVectorable instances for structs of events
// The struct must only contain Bools (or Bit#(1)) for this fn to be reasonable
function Vector#(m, Bit#(1)) struct_to_vector (from e)
  provisos (Bits#(from, m));
  return reverse(unpack(pack(e)));
endfunction

function Bit#(n) saturating_truncate(Bit#(m) wide)
  provisos (Add#(n,a_,m)); // SizeOf m > SizeOf n
  Bit#(TSub#(m,n)) msb = truncateLSB(wide);
  return (msb == 0) ? truncate(wide) : ~0;
endfunction

// Write is exposed to only one counter per cycle
// Could change write_* methods to return WriteOnly Vector if needed
interface PerfCounters_IFC#( numeric type ctrs
                           , numeric type ctrW
                           , numeric type rptW
                           , numeric type evts);
  (* always_ready, always_enabled *)
  method Action send_performance_events (Vector#(evts, Bit#(rptW)) evts);

  (* always_ready *)
  method Vector#(ctrs, ReadOnly#(Bit#(ctrW))) read_counters;
  (* always_ready *)
  method Vector#(ctrs, ReadOnly#(Bit#(TLog#(evts)))) read_ctr_sels;
  (* always_ready *)
  method ReadOnly#(Bit#(ctrs)) read_ctr_inhibit;
  (* always_ready *)
  method ReadOnly#(Bit#(ctrs)) read_ctr_overflow;

  (* always_ready *)
  method Action write_counter (Bit#(TLog#(ctrs)) idx, Bit#(ctrW) val);
  (* always_ready *)
  method Action write_ctr_sel (Bit#(TLog#(ctrs)) idx, Bit#(TLog#(evts)) val);
  (* always_ready *)
  method Action write_ctr_inhibit (Bit#(ctrs) val);
endinterface


module mkPerfCounters (PerfCounters_IFC#(ctrs, ctrW, rptW, evts))
  provisos (Add#(rptW, _a, ctrW));
  let ctrs = valueOf(ctrs);
  let ctrW = valueOf(ctrW);
  let evts = valueOf(evts);

  // Event counters
  Vector#(ctrs, Reg#(Bit#(ctrW)))
    vec_rg_counter <- replicateM(mkConfigReg(0));
  // Which event the corresponding counter will count
  Vector#(ctrs, Reg#(Bit#(TLog#(evts))))
    vec_rg_event_sel <- replicateM(mkConfigReg(0));

  Reg#(Bit#(ctrs)) rg_ctr_inhibit <- mkConfigReg(0);
  Wire#(Bit#(ctrs)) wr_overflow <- mkDWire(0);

  RWire#(Tuple2#(Bit#(TLog#(ctrs)), Bit#(ctrW))) write_counter_wire <- mkRWire;
  RWire#(Tuple2#(Bit#(TLog#(ctrs)), Bit#(TLog#(evts)))) write_ctr_sel_wire <- mkRWire;
  RWire#(Vector#(evts, Bit#(rptW))) events_wire <- mkRWire;

  (* no_implicit_conditions, fire_when_enabled *)
  rule do_writes;
    if (write_ctr_sel_wire.wget matches tagged Valid .v) begin
      match {.idx, .val} = v;
      vec_rg_event_sel[idx] <= val;
    end
    Vector#(ctrs, Bit#(ctrW)) new_ctrs = readVReg(vec_rg_counter);
    if (events_wire.wget matches tagged Valid .events) begin
      Bit#(ctrs) overflow = 0;
		  for (Integer i = 0; i < ctrs; i = i + 1) begin
		    // Get the number of times the selected event fired this cycle
		    Bit#(ctrW) event_count = 0;
		    if (vec_rg_event_sel[i] <= fromInteger(evts - 1))
		    event_count = zeroExtend(events[vec_rg_event_sel[i]]);

		    // Check that the given counter is not inhibited
		    Bool inhibit = unpack(rg_ctr_inhibit[i]);
		    // Count event
		    if (!inhibit) begin
					Bit#(TAdd#(ctrW, 1)) count_sum = zeroExtend(vec_rg_counter[i])
									                       + zeroExtend(event_count);
					new_ctrs[i] = truncate(count_sum);
					overflow[i] = truncateLSB(count_sum);
		    end

		    // $display("<time %0t, StatCounters> Counter #%2d Counting event %0d: Adding %0d to %0d (Inhibit %0d)",
		    //   $time, i, vec_rg_event_sel[i], event_count, vec_rg_counter[i][0], inhibit);
		  end
		  wr_overflow <= overflow;
    end
    if (write_counter_wire.wget matches tagged Valid .v) begin
      match {.idx, .val} = v;
      new_ctrs[idx] = val;
    end
    writeVReg(vec_rg_counter, new_ctrs);
  endrule

  method Action send_performance_events (Vector#(evts, Bit#(rptW)) events) = events_wire.wset(events);

  method Vector#(ctrs, ReadOnly#(Bit#(ctrW))) read_counters =
    map(regToReadOnly, vec_rg_counter);

  method Vector#(ctrs, ReadOnly#(Bit#(TLog#(evts)))) read_ctr_sels =
    map(regToReadOnly, vec_rg_event_sel);

  method ReadOnly#(Bit#(ctrs)) read_ctr_inhibit =
    regToReadOnly(rg_ctr_inhibit);

  method ReadOnly#(Bit#(ctrs)) read_ctr_overflow =
    regToReadOnly(wr_overflow);


  method write_counter (idx, val) = write_counter_wire.wset(tuple2(idx, val));

  method write_ctr_sel (idx, val) = write_ctr_sel_wire.wset(tuple2(idx, val));

  method write_ctr_inhibit = rg_ctr_inhibit._write;
endmodule

endpackage
