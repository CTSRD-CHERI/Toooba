
// Copyright (c) 2017 Massachusetts Institute of Technology
//
//-
// RVFI_DII + CHERI modifications:
//     Copyright (c) 2020 Jonathan Woodruff
//     Copyright (c) 2024 Franz Fuchs
//     All rights reserved.
//
//     This software was developed by SRI International and the University of
//     Cambridge Computer Laboratory (Department of Computer Science and
//     Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
//     DARPA SSITH research programme.
//
//     This work was supported by NCSC programme grant 4212611/RFA 15971 ("SafeBet").
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

`include "ProcConfig.bsv"
import Types::*;
import ProcTypes::*;
import RegFile::*;
import Vector::*;
import Ehr::*;
import CHERICC_Fat::*;
import CHERICap::*;

interface RAS;
    method CapMem first;
    method ActionValue#(RasIndex) pop(Bool doPop);
endinterface

// Local RAS Typedefs SHOULD BE A POWER OF TWO.
typedef 2 NUM_RAS_STACK_IFCS;
typedef 3 NUM_RAS_VALIDS_IFCS;
typedef 16 RasEntries;
typedef Bit#(TLog#(RasEntries)) RasIndex;
typedef RasIndex RasPredTrainInfo;

interface ReturnAddrStack;
    interface Vector#(SupSize, RAS) ras;
`ifdef ParTag
    method Action setPTID(PTIndex ptid);
    method Action shootdown(PTIndex ptid);
`endif
    method Bool pendingPush;
    method Action push(CapMem pushAddr);
    method Action write(CapMem pushAddr, RasIndex h);
    method Action setHead(RasIndex h);
    method Action flush;
    method Bool flush_done;
endinterface