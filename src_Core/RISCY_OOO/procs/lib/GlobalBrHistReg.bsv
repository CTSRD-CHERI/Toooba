
// Copyright (c) 2017 Massachusetts Institute of Technology
// 
//-
// CHERI modifications:
//     Copyright (c) 2024 Franz Fuchs
//     All rights reserved.
//
//     This software was developed by SRI International and the University of
//     Cambridge Computer Laboratory (Department of Computer Science and
//     Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
//     DARPA SSITH research programme.
//
//     This work was supported by NCSC programme grant 4212611/RFA 15971 ("SafeBet").
//
//     This software was developed by the University of  Cambridge
//     Department of Computer Science and Technology under the
//     SIPP (Secure IoT Processor Platform with Remote Attestation)
//     project funded by EPSRC: EP/S030868/1
//-
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

export GlobalBrHistReg(..);
export mkGlobalBrHistReg;

interface GlobalBrHistReg#(numeric type histLen);
    method Bit#(histLen) history;
    // add new history: taken[0--num-1] are newly added history
    // taken[num-1] is the latest branch
    method Action addHistory(Bit#(SupSize) taken, Bit#(TLog#(TAdd#(SupSize, 1))) num);
    method Action redirect(Bit#(histLen) newHist);
`ifdef ParTag
    method Action shootdown();
`endif
endinterface

typedef struct {
    Bit#(SupSize) taken;
    Bit#(TLog#(TAdd#(SupSize, 1))) num;
} AddHistory deriving(Bits, Eq, FShow);

module mkGlobalBrHistReg(GlobalBrHistReg#(histLen));
    // history reg: MSB is the most recent branch
    Reg#(Bit#(histLen)) hist <- mkReg(0);

    // wires to change history
    RWire#(AddHistory) addHist <- mkRWire; // used by addHistory
    RWire#(Bit#(histLen)) redirectHist <- mkRWire; // used by redirect
`ifdef ParTag
    // wire to delete history
    RWire#(Bool) sdHist <- mkRWire; // used by shootdown
`endif

    (* fire_when_enabled, no_implicit_conditions *)
`ifdef ParTag
    rule canon_redirect(!isValid(sdHist.wget) && isValid(redirectHist.wget));
`else
    rule canon_redirect(isValid(redirectHist.wget));
`endif
        hist <= validValue(redirectHist.wget);
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
`ifdef ParTag
    rule canon_addHistory(!isValid(sdHist.wget) && !isValid(redirectHist.wget) && isValid(addHist.wget));
`else
    rule canon_addHistory(!isValid(redirectHist.wget) && isValid(addHist.wget));
`endif
        let x = validValue(addHist.wget);
        // shift into hist from MSB
        hist <= truncate({x.taken, hist} >> x.num);
    endrule

`ifdef ParTag
    rule canon_shootdown(isValid(sdHist.wget));
        hist <= 0;
    endrule
`endif
    
    method history = hist;

    method Action addHistory(Bit#(SupSize) taken, Bit#(TLog#(TAdd#(SupSize, 1))) num);
        addHist.wset(AddHistory {
            taken: taken,
            num: num
        });
    endmethod

    method Action redirect(Bit#(histLen) newHist);
        redirectHist.wset(newHist);
    endmethod

`ifdef ParTag
    method Action shootdown();
        sdHist.wset(True);
    endmethod
`endif
endmodule
