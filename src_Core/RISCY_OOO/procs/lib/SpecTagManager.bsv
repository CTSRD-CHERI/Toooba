
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

import Vector::*;
import ProcTypes::*;
import HasSpecBits::*;
import Ehr::*;
import ConfigReg::*;

interface SpecTagManager;
    method SpecBits currentSpecBits;
    method SpecTag  nextSpecTag;
    method Action   claimSpecTag;
    method Bool     canClaim;
    interface SpeculationUpdate specUpdate;
    // performance: count full cycle
    method Bool isFull_ehrPort0;
endinterface

(* synthesize *)
module mkSpecTagManager(SpecTagManager);
    Reg#(SpecBits) current_spec_bits <- mkReg(0);

    RWire#(SpecBits) correctSpeculation_wr <- mkRWire;
    PulseWire claimSpecTag_wr <- mkPulseWire;
    RWire#(SpecBits) incorrectSpeculation_wr <- mkRWire;

    // dependent_chekcpoints[i] is the SpecBits that depend on SpecTag i.
    // i.e., if SpecTag i is incorrect, then dependent_checkpoints[i] are all
    // wrong.
    Vector#(NumSpecTags, Reg#(SpecBits)) dependent_checkpoints <- replicateM(mkConfigReg(0));

    Maybe#(SpecTag) next_spec_tag = tagged Invalid;
    for (Integer i = valueOf(NumSpecTags) - 1 ; i >= 0 ; i = i-1) begin
        if (current_spec_bits[i] == 0) begin
            next_spec_tag = tagged Valid fromInteger(i);
        end
    end

    rule cannon;
        if ((next_spec_tag == tagged Invalid )) begin
            $fdisplay(stdout, "SpecTag manager locked");
        end

        SpecBits next_spec_bits = current_spec_bits;
        if (claimSpecTag_wr) next_spec_bits[fromMaybe(?,next_spec_tag)] = 1;
        next_spec_bits = next_spec_bits & fromMaybe(~0, correctSpeculation_wr.wget);
        next_spec_bits = fromMaybe(next_spec_bits,incorrectSpeculation_wr.wget);
        current_spec_bits <= next_spec_bits;
    endrule

    method SpecBits currentSpecBits;
        return current_spec_bits;
    endmethod
    method SpecTag nextSpecTag if (next_spec_tag matches tagged Valid .valid_spec_tag);
        return valid_spec_tag;
    endmethod
    method Action claimSpecTag if (next_spec_tag matches tagged Valid .valid_spec_tag); // conflict with wrong spec
        claimSpecTag_wr.send();

        for (Integer i = 0 ; i < valueOf(NumSpecTags) ; i = i+1) begin
            if (fromInteger(i) == valid_spec_tag) begin
                dependent_checkpoints[valid_spec_tag] <= (1 << valid_spec_tag);
            end else if (current_spec_bits[i] == 1) begin
                dependent_checkpoints[i] <= dependent_checkpoints[i] | (1 << valid_spec_tag);
            end
        end
    endmethod
    method Bool canClaim = isValid(next_spec_tag);
    interface SpeculationUpdate specUpdate;
        method Action incorrectSpeculation(Bool killAll, SpecTag tag);
            if(killAll) begin
                incorrectSpeculation_wr.wset(0);
            end
            else begin
                incorrectSpeculation_wr.wset(current_spec_bits & (~(dependent_checkpoints[tag])));
            end
        endmethod
        method Action correctSpeculation(SpecBits mask);
            correctSpeculation_wr.wset(mask);
        endmethod
    endinterface

    method Bool isFull_ehrPort0;
        return next_spec_tag == Invalid;
    endmethod
endmodule
