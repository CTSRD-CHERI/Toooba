/*-
 * Copyright (c) 2018-2021 Alexandre Joannou
 * Copyright (c) 2018 Matthew Naylor
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

package Recipe;

// list of imported packages
import Printf :: *;
import FIFO :: *;
import FIFOF :: *;
import GetPut :: *;
import Connectable :: * ;
import SpecialFIFOs :: *;
import ModuleContext :: * ;

// non standard packages
import Monoid :: *;
import List :: *;
import ListExtra :: *;
import Dict :: *;
import MasterSlave :: *;
import SourceSink :: *;

// list of exported indentifiers
export Recipe;
export rAct;
export rActV;
export rFastSeq;
export rSeq;
export rPipe;
export rPar;
export rAllGuard;
export rOneMatch;
export rIfElse;
export rWhen;
export rWhile;
export rMutExGroup;
export rAppendRules;
export rMutexAppendRules;
export rBlock;
export RecipeBlock;
export ToRecipe(..);
export RecipeFSM(..);
export RecipeFSMRsp(..);
export mkRecipeFSM;
export mkRecipeFSMRspCore;
export mkRecipeFSMRsp;
export mkRecipeFSMSlaveCoreRules;
export mkRecipeFSMSlaveRules;
export mkRecipeFSMSlave;

// Flow control
typedef FIFOF#(Bit#(0)) FlowFF;
// Recipe data type
typedef union tagged {
  Action RAct;
  ActionValue#(Bool) RActV;
  Tuple4#(Module#(FlowFF), Bool, Recipe, Recipe) RIfElse;
  Tuple3#(Module#(FlowFF), Bool, Recipe) RWhile;
  Tuple5#(Module#(FlowFF), Bool, Bool, function Rules f(Rules x, Rules y), List#(Recipe)) RSeq;
  Tuple2#(Module#(FlowFF), List#(Recipe)) RPar;
  Tuple5#(Module#(FlowFF), List#(Bool), List#(Recipe), Module#(FlowFF), Recipe) ROneMatch;
  Tuple2#(String, Recipe) RMutexGroup;
  Tuple3#(Recipe, Maybe#(String), Rules) RAppendRules;
} Recipe;

// Recipe block constructor (to wrap multiple recipes in a list, passed to RSeq, RPar etc..)
typeclass RecipeBlock#(type a);
  function a mkRecipe(List#(Recipe) acc);
endtypeclass

instance RecipeBlock#(List#(Recipe));
  function mkRecipe(acc) = reverse(acc);
endinstance

instance RecipeBlock#(function a f(Action elem)) provisos (RecipeBlock#(a));
  function mkRecipe(acc, elem) = mkRecipe(cons(RAct(elem), acc));
endinstance

instance RecipeBlock#(function a f(ActionValue#(Bool) elem)) provisos (RecipeBlock#(a));
  function mkRecipe(acc, elem) = mkRecipe(cons(RActV(elem), acc));
endinstance

instance RecipeBlock#(function a f(Recipe elem)) provisos (RecipeBlock#(a));
  function mkRecipe(acc, elem) = mkRecipe(cons(elem, acc));
endinstance

function a rBlock() provisos (RecipeBlock#(a));
  return mkRecipe(Nil);
endfunction

// Class for converting types to a Recipe
typeclass ToRecipe#(type a);
  function Recipe toRecipe(a x);
endtypeclass

// Lift Action to Recipe
instance ToRecipe#(Action);
  function Recipe toRecipe(Action x) = rAct(x);
endinstance

// Lift Recipe to Recipe
instance ToRecipe#(Recipe);
  function Recipe toRecipe(Recipe x) = x;
endinstance

// Basic Action recipe
function Recipe rAct(Action a) = RAct(a);
// ActionValue recipe
function Recipe rActV(ActionValue#(Bool) a) = RActV(a);
// First recipe happens for a True condition, second recipe otherwise
function Recipe rIfElse(Bool c, Recipe r0, Recipe r1) = RIfElse(tuple4(mkBypassFIFOF, c, r0, r1));
function Recipe rWhen(Bool c, Recipe r) = rIfElse(c, r, rAct(noAction));
// Recipe happens as long as the condition is True
function Recipe rWhile(Bool c, Recipe r) = RWhile(tuple3(mkBypassFIFOF, c, r));
// All recipes happen in order
function Recipe rSeq(List#(Recipe) rs) = RSeq(tuple5(mkFIFOF1, True, False, rJoinMutuallyExclusive, rs));
// XXX FastSeq:
// All recipes happen in order with no latency (separated by mkBypassFIFOF).
// Data dependencies can still create latency. Any module whose firing in an early rule depends
// on the firing of a later rule (typically mkPipeLineFIFOF and the likes) will cause a scheduling
// error as the rules are separated by a mkBypassFIFOF, leading to a cycle in the canfire/willfire signals.
function Recipe rFastSeq(List#(Recipe) rs) = RSeq(tuple5(mkBypassFIFOF, True, False, rJoinDescendingUrgency, rs));
// XXX Pipe
//function Recipe rPipe(List#(Recipe) rs) = RSeq(tuple5(mkFIFOF, False, True, rJoinConflictFree, rs));
function Recipe rPipe(List#(Recipe) rs) = RSeq(tuple5(mkFIFOF, False, True, rJoinDescendingUrgency, rs));
// All recipes happen in parallel
function Recipe rPar(List#(Recipe) rs) = RPar(tuple2(mkBypassFIFOF, rs));
// All recipes with predicate matching happen in parallel
function Recipe rAllGuard(List#(Bool) gs, List#(Recipe) rs) = rPar(zipWith(rWhen, gs, rs));
// First recipe with that matches happens, otherwise fall-through recipe
function Recipe rOneMatch(List#(Bool) gs, List#(Recipe) rs, Recipe r) = ROneMatch(tuple5(mkBypassFIFOF, gs, rs, mkBypassFIFOF, r));
// Add recipe to a mutex group
function Recipe rMutExGroup(String s, Recipe r) = RMutexGroup(tuple2(s, r));
// Import Rules into the current recipe
function Recipe rAppendRules(Recipe r, Rules rs) = RAppendRules(tuple3(r, noMutEx, rs));
function Recipe rMutexAppendRules(Recipe r, String str, Rules rs) = RAppendRules(tuple3(r, Valid(str), rs));

// Inner Recipe types and helpers
////////////////////////////////////////////////////////////////////////////////
`define RULES_DICT Dict#(Maybe#(String), Rules)

typedef Sink#(Bit#(0)) FlowSnk;
typedef Source#(Bit#(0)) FlowSrc;
typedef struct {
  FlowSnk go;
  FlowSrc done;
  `RULES_DICT dict;
} CoreRecipe;
function `RULES_DICT getDict(CoreRecipe x) = x.dict;
function FlowSnk       getGo(CoreRecipe x) = x.go;
function FlowSrc     getDone(CoreRecipe x) = x.done;

module [Module] adapt#(Module#(t) m) (Tuple2#(Empty, t));
  t x <- m;
  return tuple2(?, x);
endmodule
// to be able to use rebury in order not to impose the [Module] decoration,
// you need to "adapt" your module such that it exposes an empty context...

typedef union tagged {
  Module#(FlowFF) MkFF;
  FlowFF FF;
} FlowFFArg;
module craftFlowFF#(FlowFFArg ffarg)(FlowFF);
  case (ffarg) matches
    tagged MkFF .mkFF: begin
      FlowFF newff <- rebury(adapt(mkFF));
      return newff;
    end
    tagged FF .ff: return ff;
  endcase
endmodule

Maybe#(String) noMutEx = tagged Invalid;

// Recipe interfaces
////////////////////////////////////////////////////////////////////////////////

interface RecipeFSM;
  method Bool   canTrigger;
  method Action trigger;
endinterface

interface RecipeFSMRsp#(type rsp_t);
  interface RecipeFSM fsm;
  interface Source#(rsp_t) rsp;
endinterface

module mkRecipeFSMCoreRules#(
  Module#(FIFOF#(out_t)) mkFF,
  function Recipe recipe_func (in_t args, Sink#(out_t) outsnk))
  (Tuple3#(RecipeFSM, Rules, Slave#(in_t, out_t)))
  provisos (Bits#(in_t, in_sz), Bits#(out_t, out_sz));
  Reg#(in_t) arg_reg[2] <- mkCRegU(2);
  FIFOF#(out_t) ret_ff <- rebury(adapt(mkFF));
  let core <- mkRecipeFSMRules(recipe_func(arg_reg[1], toSink(ret_ff)));
  match {.recipe_rules, .recipe_fsm} = core;
  let s = interface Slave;
    interface req = interface Sink;
      method canPut = recipe_fsm.canTrigger;
      method put(x) if (recipe_fsm.canTrigger) = action
        arg_reg[0] <= x;
        recipe_fsm.trigger;
      endaction;
    endinterface;
    interface rsp = toSource(ret_ff);
  endinterface;
  return tuple3(recipe_fsm, recipe_rules, s);
endmodule

module mkRecipeFSMSlaveCoreRules#(
  Module#(FIFOF#(out_t)) mkFF,
  function Recipe recipe_func (in_t args, Sink#(out_t) outsnk))
  (Tuple2#(Rules, Slave#(in_t, out_t)))
  provisos (Bits#(in_t, in_sz), Bits#(out_t, out_sz));
  let core <- mkRecipeFSMCoreRules(mkFF, recipe_func);
  match {._, .fsm_rules, .fsm_slv} = core;
  return tuple2(fsm_rules, fsm_slv);
endmodule
module mkRecipeFSMSlaveRules#(
  function Recipe recipe_func (in_t args, Sink#(out_t) outsnk))
  (Tuple2#(Rules, Slave#(in_t, out_t)))
  provisos (Bits#(in_t, in_sz), Bits#(out_t, out_sz));
  let core <- mkRecipeFSMSlaveCoreRules(mkBypassFIFOF, recipe_func);
  return core;
endmodule
module mkRecipeFSMSlave#(
  function Recipe recipe_func (in_t args, Sink#(out_t) outsnk))
  (Slave#(in_t, out_t)) provisos (Bits#(in_t, in_sz), Bits#(out_t, out_sz));
  let core <- mkRecipeFSMSlaveRules(recipe_func);
  addRules(tpl_1(core));
  return tpl_2(core);
endmodule

module mkRecipeFSMRspCore#(
  Module#(FIFOF#(rsp_t)) mkFF,
  function Recipe recipe_func (Sink#(rsp_t) outsnk))
  (RecipeFSMRsp#(rsp_t)) provisos (Bits#(rsp_t, rsp_sz));
  function Recipe drop1arg (Bit#(0) dummy, Sink#(rsp_t) outsnk) =
    recipe_func(outsnk);
  let core <- mkRecipeFSMCoreRules(mkFF, drop1arg);
  addRules(tpl_2(core));
  interface fsm = tpl_1(core);
  interface rsp = tpl_3(core).rsp;
endmodule

module mkRecipeFSMRsp#(
  function Recipe recipe_func (Sink#(rsp_t) outsnk))
  (RecipeFSMRsp#(rsp_t)) provisos (Bits#(rsp_t, rsp_sz));
  function Recipe drop1arg (Bit#(0) dummy, Sink#(rsp_t) outsnk) =
    recipe_func(outsnk);
  let core <- mkRecipeFSMCoreRules(mkBypassFIFOF, drop1arg);
  addRules(tpl_2(core));
  interface fsm = tpl_1(core);
  interface rsp = tpl_3(core).rsp;
endmodule

// Recipe compiler front modules
////////////////////////////////////////////////////////////////////////////////

// compiles a recipe, adds the rules to the module and returns a RecipeFSM
module mkRecipeFSM#(Recipe r) (RecipeFSM);
  Tuple2#(Rules, RecipeFSM) x <- mkRecipeFSMRules(r);
  addRules(tpl_1(x));
  return tpl_2(x);
endmodule

// compiles a recipe, returns the generated rules and a RecipeFSM
module mkRecipeFSMRules#(Recipe r) (Tuple2#(Rules, RecipeFSM));
  CoreRecipe cr <- mkCoreRecipe(r);
  // get the RecipeFSM interface
  RecipeFSM machine = interface RecipeFSM;
    method canTrigger = cr.go.canPut;
    method trigger    = cr.go.put(?);
  endinterface;
  // get the Rules
  Rules drain = rules rule drain; cr.done.drop; endrule endrules;
  function isNormal(x) = !isValid(tpl_1(x));
  function  isMutEx(x) = isValid(tpl_1(x));
  `RULES_DICT normalDict = Dict::filter(isNormal, cr.dict);
  `RULES_DICT  mutExDict = Dict::filter(isMutEx, cr.dict);
  Rules normal = foldl(rJoin, emptyRules, values(normalDict));
  Rules  mutEx = foldl(rJoinMutuallyExclusive, emptyRules, values(mutExDict));
  return tuple2(rJoin(drain, rJoin(normal, mutEx)), machine);
endmodule

// compile a recipe, returns the core recipe
module mkCoreRecipe#(Recipe r) (CoreRecipe);
  let coreRecipe <- coreRecipeCompile(noMutEx, r,
                                      MkFF(mkBypassFIFOF),
                                      MkFF(mkBypassFIFOF));
  return coreRecipe;
endmodule

// Core Recipe Compiler
////////////////////////////////////////////////////////////////////////////////
module coreRecipeCompile#(Maybe#(String) mutex,
                          Recipe r,
                          FlowFFArg goArg,
                          FlowFFArg doneArg)
                          (CoreRecipe);

  // prepare comp short name, goFF, doneFF and coreRecipe
  //////////////////////////////////////////////////////////////////////////////
  function comp = coreRecipeCompile;
  FlowFF goFF   <- craftFlowFF(goArg);
  FlowFF doneFF <- craftFlowFF(doneArg);
  CoreRecipe coreRecipe = CoreRecipe {
    go: toSink(goFF),
    done: toSource(doneFF),
    dict: mempty
  };

  // core compiler
  //////////////////////////////////////////////////////////////////////////////
  case (r) matches
    // Action recipe
    ////////////////////////////////////////////////////////////////////////////
    tagged RAct .a: coreRecipe.dict = dict(mutex, rules
      rule runAct;
        a;
        goFF.deq;
        doneFF.enq(?);
      endrule
    endrules);
    // ActionValue recipe
    ////////////////////////////////////////////////////////////////////////////
    tagged RActV .av: coreRecipe.dict = dict(mutex, rules
      rule runActV;
        Bool isDone <- av;
        if (isDone) begin
          goFF.deq;
          doneFF.enq(?);
        end
      endrule
    endrules);
    // If / Else recipe construct
    ////////////////////////////////////////////////////////////////////////////
    tagged RIfElse {.mkFF, .cond, .r_if, .r_else}: begin
      // declare flow control state //
      ////////////////////////////////
      FIFOF#(Bool) condFF <- mkBypassFIFOF;
      // compile and gather rules //
      //////////////////////////////
      CoreRecipe ifRecipe   <- comp(mutex, r_if,
                                    MkFF(mkFF), MkFF(mkBypassFIFOF));
      CoreRecipe elseRecipe <- comp(mutex, r_else,
                                    MkFF(mkFF), MkFF(mkBypassFIFOF));
      `RULES_DICT beforeRules = dict(noMutEx, rules rule enqCondFF;
        goFF.deq;
        condFF.enq(cond);
        if (cond) ifRecipe.go.put(?);
        else elseRecipe.go.put(?);
      endrule endrules);
      `RULES_DICT afterIfRules = dict(noMutEx, rules
      rule finishIf(condFF.first);
        condFF.deq;
        ifRecipe.done.drop;
        doneFF.enq(?);
      endrule endrules);
      `RULES_DICT afterElseRules = dict(noMutEx, rules
      rule finishElse(!condFF.first);
        condFF.deq;
        elseRecipe.done.drop;
        doneFF.enq(?);
      endrule endrules);
      // join rules //
      ////////////////
      `RULES_DICT ifRules   = mergeWith(rJoinExecutionOrder,
                                        ifRecipe.dict, afterIfRules);
      `RULES_DICT elseRules = mergeWith(rJoinExecutionOrder,
                                        elseRecipe.dict, afterElseRules);
      `RULES_DICT ifElseRules = mergeWith(rJoinMutuallyExclusive,
                                          ifRules, elseRules);
      coreRecipe.dict = mergeWith(rJoinExecutionOrder,
                                  beforeRules, ifElseRules);
    end
    // While loop recipe construct
    ////////////////////////////////////////////////////////////////////////////
    tagged RWhile {.mkFF, .cond, .r}: begin
      Reg#(Bool)       busy[2] <- mkCReg(2, False);
      Reg#(Bool) activeStep[3] <- mkCReg(3, False);
      // XXX Note, for cond, this wire emulates the behaviour of a ConfigReg to
      // avoid scheduling issues between the inner rules updating the condition
      // and the wrapping rules reading it.
      PulseWire condValid    <- mkPulseWire;
      CoreRecipe innerRecipe <- comp(mutex, r, MkFF(mkFF), MkFF(mkBypassFIFOF));
      `RULES_DICT wrappingRules = dict(noMutEx,
      (* descending_urgency = "endStepWhile, endWhile"*)
      rules
        rule ackGoFFWhile (!busy[0]);
          //$display("%0t -- ackGoFFWhile", $time);
          goFF.deq;
          busy[0] <= True;
        endrule
        rule readCondWhile (cond && busy[1]);
          //$display("%0t -- readCondWhile", $time);
          condValid.send;
        endrule
        rule startStepWhile (busy[1] && condValid && !activeStep[0]);
          //$display("%0t -- startStepWhile", $time);
          innerRecipe.go.put(?);
          activeStep[0] <= True;
        endrule
        rule endStepWhile;
          //$display("%0t -- endStepWhile", $time);
          innerRecipe.done.drop;
          activeStep[1] <= False;
        endrule
        rule endWhile (busy[1] && !condValid && !activeStep[2]);
          //$display("%0t -- endWhile", $time);
          busy[1] <= False;
          doneFF.enq(?);
        endrule
      endrules);
      coreRecipe.dict = mconcat(list(innerRecipe.dict, wrappingRules));
    end
    // Seq recipe construct
    ////////////////////////////////////////////////////////////////////////////
    tagged RSeq {.w_, .x_, .y_, .z_, Nil}: coreRecipe.dict = dict(noMutEx, rules
      rule emptySeq; goFF.deq; doneFF.enq(?); endrule
    endrules);
    tagged RSeq {.mkFF, .block, .invert, .rulesJoin, .rs}: begin
      Reg#(Bool) busy[2] <- mkCReg(2, False);
      FlowFF lastFF = goFF;
      Integer seqLength = length(rs);
      List#(Recipe) rList = rs;
      // go through the list and leave the last element in there
      `RULES_DICT seqRules = mempty;
      for (Integer i = 0; i < seqLength - 1; i = i + 1) begin
        let newFF <- rebury(adapt(mkFF));
        CoreRecipe step <- comp(mutex, head(rList), FF(lastFF), FF(newFF));
        lastFF   = newFF;
        if (invert) seqRules = mergeWith(rulesJoin, step.dict, seqRules);
        else seqRules = mergeWith(rulesJoin, seqRules, step.dict);
        rList    = tail(rList);
      end
      CoreRecipe lastStep <- comp(mutex, head(rList), FF(lastFF), FF(doneFF));
      if (invert)
        coreRecipe.dict = mergeWith(rulesJoin, lastStep.dict, seqRules);
      else coreRecipe.dict = mergeWith(rulesJoin, seqRules, lastStep.dict);
      if (block) begin
        coreRecipe.go = interface Sink;
          method canPut = !busy[0] && goFF.notFull;
          method put(x) if (!busy[0]) = action busy[0] <= True; goFF.enq(?); endaction;
        endinterface;
        coreRecipe.done = interface Source;
          method canPeek = busy[1] && doneFF.notEmpty;
          method peek    = doneFF.first;
          method drop if (busy[1]) = action
            busy[1] <= False;
            doneFF.deq;
          endaction;
        endinterface;
      end
    end
    // Par recipe construct
    ////////////////////////////////////////////////////////////////////////////
    tagged RPar {.mkFF, .rs}: begin
      function shuffleComp(a,b,c,d) = comp(a,d,b,c);
      List#(CoreRecipe) branches <- mapM(shuffleComp(mutex,
                                                     MkFF(mkFF),
                                                     MkFF(mkBypassFIFOF)),
                                         rs);
      `RULES_DICT branchRules = mconcat(map(getDict, branches));
      `RULES_DICT forkRule = dict(noMutEx, rules rule forkPar;
        goFF.deq;
        function trigger(x) = action x.go.put(?); endaction;
        joinActions(map(trigger, branches));
      endrule endrules);
      `RULES_DICT joinRule = dict(noMutEx, rules rule joinPar;
        function drain(x) = action x.done.drop; endaction;
        joinActions(map(drain, branches));
        doneFF.enq(?);
      endrule endrules);
      coreRecipe.dict = concatWith(rJoinExecutionOrder,
                                   list(forkRule, branchRules, joinRule));
    end
    // OneMatch recipe construct
    ////////////////////////////////////////////////////////////////////////////
    tagged ROneMatch {.mkFF, .gs, .rs, .mkDfltFF, .r}: begin
      // check for valid lengths //
      /////////////////////////////
      Integer rlen = length(rs);
      Integer glen = length(gs);
      if (rlen != glen) error(sprintf(
          "OneMatch recipe constructor: list of guards and of recipes must be "
        + "the same length (given %0d guards and %0d recipes).", glen, rlen));
      // local resources //
      /////////////////////
      PulseWire done  <- mkPulseWireOR;
      CoreRecipe dflt <- comp(mutex, r, MkFF(mkDfltFF), MkFF(mkBypassFIFOF));
      function shuffleComp(a,b,c,d) = comp(a,d,b,c);
      List#(CoreRecipe) branches <- mapM(shuffleComp(mutex,
                                                     MkFF(mkFF),
                                                     MkFF(mkBypassFIFOF)),
                                         rs);
      // rules for branch recipes //
      //////////////////////////////
      `RULES_DICT allbranchRules = concatWith(rJoinMutuallyExclusive,
                                              map(getDict, branches));
      `RULES_DICT branchRules = mergeWith(rJoinMutuallyExclusive,
                                          allbranchRules, dflt.dict);
      // rules for branch triggering //
      /////////////////////////////////
      `RULES_DICT triggerRules = dict(noMutEx, rules rule triggerOneMatch;
        goFF.deq;
        // trigger first matching branch, or default branch otherwise
        case(find(tpl_1, zip(gs, branches))) matches
          tagged Valid {.guard, .b}: b.go.put(?);
          tagged Invalid: dflt.go.put(?);
        endcase
      endrule endrules);
      // rules to gather each branch //
      /////////////////////////////////
      function gatherRule(x) = rules
        rule gatherOneMatch; x.done.drop; done.send; endrule
      endrules;
      Rules allGatherRules = fold(rJoinMutuallyExclusive,
                                  map(gatherRule, branches));
      Rules dfltGatherRules = rules
        rule gatherDfltOneMatch; dflt.done.drop; done.send(); endrule
      endrules;
      `RULES_DICT gatherRules = dict(noMutEx, rJoinMutuallyExclusive(
                                     allGatherRules, dfltGatherRules));
      // rules to generate final done signal //
      /////////////////////////////////////////
      `RULES_DICT finalRules = dict(noMutEx, rules
        rule finalOneMatch (done); doneFF.enq(?); endrule
      endrules);
      // compose all rules and return
      coreRecipe.dict = concatWith(rJoinExecutionOrder, list(
                        triggerRules, branchRules, gatherRules, finalRules));
    end
    // Tag recipe
    ////////////////////////////////////////////////////////////////////////////
    tagged RMutexGroup {.str, .recipe}: begin
      let d <- comp(Valid(str), recipe, FF(goFF), FF(doneFF));
      coreRecipe.dict = d.dict;
    end
    // Import rules into a recipe
    ////////////////////////////////////////////////////////////////////////////
    tagged RAppendRules {.r, .mtx, .rs}: begin
      let d <- comp(mutex, r, FF(goFF), FF(doneFF));
      coreRecipe.dict = mconcat(list(d.dict, dict(mtx, rs)));
    end
  endcase
  // return newly crafted core recipe
  return coreRecipe;
endmodule

`undef RULES_DICT

endpackage
