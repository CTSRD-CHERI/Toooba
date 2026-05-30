/*-
 * Copyright (c) 2018-2020 Alexandre Joannou
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

package OneWayBus;

export mkOneWayBus;
export mkOneWayBusNoRoute;

import Routable      :: *;
import SourceSink    :: *;
import OneHotArbiter :: *;

import Vector :: *;

`define PREFERRED_ARBITER mkFairOneHotArbiter
//`define PREFERRED_ARBITER mkStaticOneHotArbiter

///////////////////////////////
// One-way bus core wrappers //
////////////////////////////////////////////////////////////////////////////////
module mkOneWayBus #(
  function Vector #(nO, Bool) route (r_t x) // the routing function to use
, Vector #(nI, in_t)  ins                   // the inputs
, Vector #(nO, out_t) outs                  // the outputs
) (Empty) provisos (
  ToSource #(in_t,  flit_t)
, ToSink   #(out_t, flit_t)
, Routable #(flit_t, r_t)
, Bits #(flit_t, flit_sz)
  // assertion on argument sizes
, Add #(1, a__, nI) // at least one input is needed
, Add #(1, b__, nO) // at least one output is needed
);
  mkOneWayBus_core (`PREFERRED_ARBITER, route, Invalid, ins, outs);
endmodule
module mkOneWayBusNoRoute #(
  function Vector #(nO, Bool) route (r_t x) // the routing function to use
, out_t dflt_out                            // the default output on route fail
, Vector #(nI, in_t)  ins                   // the inputs
, Vector #(nO, out_t) outs                  // the outputs
) (Empty) provisos (
  ToSource #(in_t,  flit_t)
, ToSink   #(out_t, flit_t)
, Routable #(flit_t, r_t)
, Bits #(flit_t, flit_sz)
  // assertion on argument sizes
, Add #(1, a__, nI) // at least one input is needed
, Add #(1, b__, nO) // at least one output is needed
);
  mkOneWayBus_core ( `PREFERRED_ARBITER, route, Valid (toSink (dflt_out))
                   , ins, outs );
endmodule

/////////////////////////////
// One-way bus core module //
////////////////////////////////////////////////////////////////////////////////
module mkOneWayBus_core #(
  // 1st arg - arbiter constructor
  function module #(OneHotArbiter) mkOneHotArbiter (List#(Bool) reqs)
  // 2nd arg - routing function
, function Vector #(nO, Bool) route (r_t x)
  // 3rd arg - Default output to use on route failure
, Maybe #(Sink #(flit_t)) m_dfltOutputSnk
  // 4th arg - all inputs
, Vector #(nI, in_t) ins
  // 5th arg - all outputs
, Vector #(nO, out_t) outs
) (Empty) provisos (
  ToSource #(in_t, flit_t)
, ToSink #(out_t, flit_t)
, Routable #(flit_t, r_t)
, Bits #(flit_t, flit_sz)
  // assertion on argument sizes
, Add #(1, a__, nI) // at least one input is needed
, Add #(1, b__, nO) // at least one output is needed
);

  // the following constants controls inclusion of various assertion rules and
  // debug messages
  let inputs_assertion_rules = True;
  let verbose_arbitration    = False;
  let verbose_inputs         = False;
  let verbose_ouptuts        = False;

  /////////////////////////////
  // boilerplate definitions //
  //////////////////////////////////////////////////////////////////////////////

  // helper function to detect valid one hot routes
  function isOneHot (x) = countIf (id, x) == 1;

  // statically detect if we are using a default no route sink or not
  let has_dflt_output = isValid (m_dfltOutputSnk);

  // Prepare wires to carry values from and to the inputs and outputs

  // declare input wires
  let inputSrc = map (toSource, ins);
  Vector #(nI, Wire #(Bool))
    inputCanPeek <- replicateM (mkDWire (False));
  Vector #(nI, Wire #(flit_t))
    inputPeek <- replicateM (mkDWire (?));
  Vector #(nI, Wire #(Vector #(nO, Bool)))
    inputDest <- replicateM (mkDWire (?));
  // assign input wires
  for (Integer i = 0; i < valueOf (nI); i = i + 1) begin
    (* no_implicit_conditions, fire_when_enabled *)
    rule set_input_canPeek_wire;
      inputCanPeek[i] <= inputSrc[i].canPeek;
    endrule
    (* fire_when_enabled *)
    rule set_input_peek_wires;
      inputPeek[i] <= inputSrc[i].peek;
      inputDest[i] <= compose (route, routingField) (inputSrc[i].peek);
    endrule
  end
  // declare output wires
  let outputSnk = map (toSink, outs);
  Vector #(nO, Wire #(Bool)) outputCanPut <- replicateM (mkDWire (False));
  let dfltOutputSnk = m_dfltOutputSnk.Valid;
  Wire #(Bool) dfltOutputCanPut <- mkDWire (False);
  // assign output wires
  for (Integer i = 0; i < valueOf (nO); i = i + 1) begin
    (* no_implicit_conditions, fire_when_enabled *)
    rule set_output_canPut_wire;
      outputCanPut[i] <= outputSnk[i].canPut;
    endrule
  end
  if (has_dflt_output) begin
    (* no_implicit_conditions, fire_when_enabled *)
    rule set_dflt_output_canPut_wire;
      dfltOutputCanPut <= dfltOutputSnk.canPut;
    endrule
  end

  // Helper function to read a vector of Wires
  function readVWire = readVReg;

  // This register keeps track of multi-flit packets, with their provenance and
  // their destination. Change in destination between flits of a same packet is
  // not supported
  Reg #(Maybe #(Tuple2 #(Vector #(nI, Bool), Vector #(nO, Bool))))
    moreFlits <- mkReg(Invalid);
  // These wires are used to carry a flit from a selected input to each of the
  // potential outputs. Only one is expected to be valid in a given cycle.
  Vector #(nO, RWire #(flit_t)) toOutput <- replicateM (mkRWire);
  // In case of un-routable flit, carry the flit to a default no-route output.
  RWire #(flit_t) toDfltOutput <- mkRWire;

  /////////////////
  // arbitration //
  //////////////////////////////////////////////////////////////////////////////

  // Define active requests for the current cycle: for each input, if there is
  // a request available, the requested destination is compared with the
  // available outputs. If the destination output is available, the request is
  // considered active as far as arbitration is concerned.
  // In the case where a default slave is available, consider invalid
  // destinations for active requests as well.
  function canUseRoute (x) =
       (has_dflt_output && !isOneHot (x) && dfltOutputCanPut)
    || \or (zipWith (\&& , x, readVWire (outputCanPut)));
  Vector #(nI, Bool) activeRequest = replicate (False);
  for (Integer i = 0; i < valueOf(nI); i = i + 1) if (inputCanPeek[i])
    activeRequest[i] = canUseRoute (inputDest[i]);

  // Determine the selected input with a one hot arbiter when the bus is not
  // already transferring a multi-flit packet. The arbiter receives the
  // activeRequest vector and produces on the selectInput wire a one hot vector
  // identifying the unique selected input.
  let arbiter <- mkOneHotArbiter (toList (activeRequest));
  Vector#(nI, Wire#(Bool)) selectInput <- replicateM(mkDWire(False));
  rule arbitrate (!isValid (moreFlits));
    let nexts <- arbiter.next;
    writeVReg (selectInput, toVector(nexts));
    if (verbose_arbitration) $display (
      "%0t -- %m debug: arbiter receives: ", $time, fshow (activeRequest)
      , ", next selectInput: ", fshow (nexts));
  endrule
  if (verbose_arbitration) begin
    rule arbitrate_debug;
      $display ("%0t -- %m debug: moreFlits: ", $time, fshow (moreFlits));
    endrule
  end

  ////////////
  // inputs //
  //////////////////////////////////////////////////////////////////////////////

  // We accumulate the rules to transfer a flit from each input. Two relevant
  // rules are generated per input: one to forward a flit from a new packet,
  // and one to forward a following flit from an already started packet. Those
  // two rules are marked as mutually exclusive with each-other. Additionally,
  // as only a single flit can be transferred over the bus in a cycle, rules
  // generated for each input are aggregated using rJoinMutuallyExclusive.
  // Rules for an input are guarded by the result of arbitration delegated to
  // the one hot arbiter module.

  // helper function to map accross destinations how to forward a flit
  function Action forwardFlit (t val, Bool cond, RWire #(t) rwire) =
    action if (cond) rwire.wset (val); endaction;

  Rules inputRules = emptyRules;
  for (Integer i = 0; i < valueOf (nI); i = i + 1) begin
    // handles on active input and output. Only useful when in a multi-flit.
    match {.from, .to} = moreFlits.Valid;
    if (verbose_inputs) begin
      rule input_debug;
        $display ( "%0t -- %m debug: input#%0d -- ", $time, i
                 , "inputCanPeek: ", fshow (inputCanPeek[i])
                 , ", inputDest: ", fshow (inputDest[i])
                 , ", selectInput: ", fshow (selectInput[i]));
      endrule
    end
    /////////////////////
    // assertion rules //
    /////////////////////
    rule arbitration_fail (inputs_assertion_rules && selectInput[i] && !inputCanPeek[i]);
      $display ( "%0t -- %m error: input#%0d ", $time, i
               , "was selected but did not emit a request");
      $finish (0);
    endrule
    rule legal_destination_fail ( inputs_assertion_rules
                               && !has_dflt_output
                               && selectInput[i]
                               && inputCanPeek[i]
                               && !isOneHot (inputDest[i]));
      $display ( "%0t -- %m error: input#%0d ", $time, i
               , "requested an invalid destination: "
               , fshow (inputDest[i]), " (not a valid one-hot destination)");
      $finish (0);
    endrule
    ////////////////////////////////
    // actual functionality rules //
    ////////////////////////////////
    inputRules = rJoinMutuallyExclusive (inputRules, rules
      (* mutually_exclusive = "input_first_flit, input_follow_flit" *)
      rule input_first_flit (!isValid (moreFlits) && selectInput[i]
                                                  && inputCanPeek[i]);
        if (verbose_inputs) $display (
          "%0t -- %m debug: input_first_flit#%0d - ", $time, i
        , "inputDest: ", fshow (inputDest[i]));
        // consume from the input
        inputSrc[i].drop;
        // forward the flit to the desired destination (default output in case
        // of non routable flit)
        if (!isOneHot (inputDest[i])) toDfltOutput.wset (inputPeek[i]);
        else zipWithM_ (forwardFlit (inputPeek[i]), inputDest[i], toOutput);
        // update next state of the bus in case of multi-flit transaction
        if (!isLast (inputPeek[i])) begin
          let newFrom = replicate (False);
          newFrom[i] = True;
          moreFlits <= Valid (tuple2 (newFrom, inputDest[i]));
          if (verbose_inputs) $display (
            "%0t -- %m debug: input_first_flit#%0d - ", $time, i
          , "starting multi-flit packet");
        end
      endrule
      rule input_follow_flit (
           isValid (moreFlits)
        && from[i] && inputCanPeek[i]
        && canUseRoute (to));
        if (verbose_inputs) $display (
          "%0t -- %m debug: input_follow_flit#%0d - ", $time, i
        , "to: ", fshow (to));
        // consume from the input
        inputSrc[i].drop;
        // forward the flit to the desired destination (default output in case
        // of non routable flit)
        if (!isOneHot (to)) toDfltOutput.wset (inputPeek[i]);
        else zipWithM_ (forwardFlit (inputPeek[i]), to, toOutput);
        // update next state of the bus on end of multi-flit transaction
        if (isLast (inputPeek[i])) begin
          moreFlits <= Invalid;
          if (verbose_inputs) $display (
            "%0t -- %m debug: input_follow_flit#%0d - ", $time, i
            , "ending multi-flit packet");
        end
      endrule
    endrules);
  end

  /////////////
  // outputs //
  //////////////////////////////////////////////////////////////////////////////

  // We accumulate the rules to transfer a flit to each output. The one rule
  // generated for each output simply puts the flit received on the toOutput
  // wire in the output sink. Only one of these rule should ever fire at a time
  // if arbitration was done correctly. For this reason, we aggregate these
  // rules using rJoinMutuallyExclusive.

  Rules outputRules = emptyRules;
  for (Integer i = 0; i < valueOf (nO); i = i + 1) begin
    if (verbose_ouptuts) begin
      rule output_debug;
        $display ( "%0t -- %m debug: output#%0d -- ", $time, i
                 , "outputCanPut: ", fshow (outputCanPut[i])
                 , ", toOutput: ", fshow (isValid (toOutput[i].wget)));
      endrule
    end
    outputRules = rJoinMutuallyExclusive (outputRules, rules
      rule output_selected (isValid (toOutput[i].wget) && outputCanPut[i]);
        if (verbose_ouptuts) $display (
          "%0t -- %m debug: output_selected#%0d", $time, i);
        outputSnk[i].put (toOutput[i].wget.Valid);
      endrule
    endrules);
  end

  // Additionally, we handle the default output targeted in case no route was
  // found.
  if (has_dflt_output) begin
    if (verbose_ouptuts) begin
      rule dflt_output_debug;
        $display ( "%0t -- %m debug: dflt_output -- ", $time
                 , "dfltOutputCanPut: ", fshow (dfltOutputCanPut)
                 , ", toDfltOutput: ", fshow (isValid (toDfltOutput.wget)));
      endrule
    end
    outputRules = rJoinMutuallyExclusive (outputRules, rules
      rule dflt_output_selected (  isValid (toDfltOutput.wget)
                                && dfltOutputCanPut);
        if (verbose_ouptuts) $display (
          "%0t -- %m debug: dflt_output_selected", $time);
        dfltOutputSnk.put (toDfltOutput.wget.Valid);
      endrule
    endrules);
  end

  // add the input and output rules to the current module
  addRules (rJoinExecutionOrder (inputRules, outputRules));

endmodule

endpackage
