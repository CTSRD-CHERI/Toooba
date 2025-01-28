
// Copyright (c) 2017 Massachusetts Institute of Technology
// 
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Types::*;
import ProcTypes::*;
import EpochManager::*;
import Vector::*;

(* noinline *)
function Maybe#(Addr) decodeBrPred( Addr pc, DecodedInst dInst, Bool histTaken, Bool is_32b_inst);
  Addr pcPlusN = pc + (is_32b_inst ? 4 : 2);
  Data imm_val = fromMaybe(?, getDInstImm(dInst));
  Maybe#(Addr) nextPc = tagged Invalid;
  if( dInst.iType == J ) begin
    Addr jTarget = pc + imm_val;
    nextPc = tagged Valid jTarget;
  end else if( dInst.iType == Br ) begin
    if( histTaken ) begin
      nextPc = tagged Valid (pc + imm_val);
    end else begin
      nextPc = tagged Valid pcPlusN;
    end
  end else if( dInst.iType == Jr ) begin
    // target is unknown until RegFetch
    nextPc = tagged Invalid;
  end else begin
    nextPc = tagged Valid pcPlusN;
  end
  return nextPc;
endfunction

// general types for direction predictor

// Function to offset PC by the probable size of an instruction without a full add delay.
function Addr offsetPc(Addr pc, Integer i) = {truncateLSB(pc), pc[7:0] + (fromInteger(i)*4)};

typedef struct {
    Bool taken;
    trainInfoT train;
    // For debug
    Addr pc;
} DirPredResult#(type trainInfoT) deriving(Bits, Eq, FShow);

typedef struct {
    DirPredResult#(trainInfoT) result;
    Epoch main_epoch;
    Bool decode_epoch;
} GuardedResult#(type trainInfoT) deriving(Bits, Eq, FShow);

typedef struct {
  Addr pc;
  Epoch main_epoch;
  Bool decode_epoch;
} PredIn deriving(Bits, Eq, FShow);


interface DirPred#(type trainInfoT);
  method ActionValue#(Maybe#(GuardedResult#(trainInfoT))) pred;
endinterface

interface DirPredictor#(type trainInfoT, type specInfoT);
    method Action nextPc(Vector#(SupSize,Maybe#(PredIn)) next);
    method Action specRecover(specInfoT specInfo, Bool taken);
    //interface Vector#(SupSize, DirPred#(trainInfoT, specInfoT)) pred;
    method Action update(Bool taken, trainInfoT train, Bool mispred);
    method Action confirmPred(Bit#(SupSize) results, SupCnt count); // By decode stage, for speculative history and end_pointer update
    
    method specInfoT getSpec(SupCnt i);

    method Action flush;
    method Bool flush_done;
endinterface

