// Copyright (c) 2017 Massachusetts Institute of Technology
//
//-
// RVFI_DII + CHERI modifications:
//     Copyright (c) 2020 Jessica Clarke
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

`ifdef ParTag
import Types::*;
import ProcTypes::*;
import ConfigReg::*;
import DReg::*;
import Map::*;
import Vector::*;
import CHERICC_Fat::*;
import CHERICap::*;
import Btb_IFC::*;
import BtbCore::*;

module mkBtbPartition(NextAddrPred#(hashSz))
    provisos (NumAlias#(tagSz, TSub#(TSub#(TSub#(AddrSz,SizeOf#(BtbBank)), SizeOf#(BtbIndex)), PcLsbsIgnore)),
        Add#(1, a__, TDiv#(tagSz, hashSz)),
    Add#(b__, tagSz, TMul#(TDiv#(tagSz, hashSz), hashSz)));

    Vector#(PTNumber, NextAddrPred#(hashSz)) btbs <- replicateM(mkBtbCore);
    Reg#(PTIndex) rg_ptid <- mkReg(0); // default zero id
    Reg#(Maybe#(PTIndex)) curr_ptid <- mkReg(?);

    method Action put_pc(CapMem pc, Maybe#(PTIndex) ptid);
        if(ptid matches tagged Valid .p) btbs[p].put_pc(pc, ptid);
        else noAction;
    endmethod
    method Vector#(SupSizeX2, Maybe#(CapMem)) pred;
        if(curr_ptid matches tagged Valid .cp) return btbs[cp].pred;
        else return ?;
    endmethod
    method Action update(CapMem pc, CapMem brTarget, Bool taken, Maybe#(PTIndex) ptid);
        if(ptid matches tagged Valid .p) btbs[p].update(pc, brTarget, taken, ptid);
        else noAction;
    endmethod
    method Action setPTID(PTIndex ptid);
        rg_ptid <= ptid;
    endmethod
    method shootdown = btbs[rg_ptid].shootdown;
    method flush = btbs[rg_ptid].flush;
    method flush_done = btbs[rg_ptid].flush_done;
endmodule
`endif