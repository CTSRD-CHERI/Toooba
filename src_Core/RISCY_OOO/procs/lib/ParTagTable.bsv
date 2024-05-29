/*-
 * Copyright (c) 2024 Franz Fuchs
 * All rights reserved.
 *
 * This software was developed by the University of  Cambridge
 * Department of Computer Science and Technology under the
 * SIPP (Secure IoT Processor Platform with Remote Attestation)
 * project funded by EPSRC: EP/S030868/1
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

`ifdef ParTag

 import CHERICC_Fat :: *;
 import ProcTypes :: *;
 import Vector :: *;
 import FIFOF::*;
 
 interface ParTagTableInput;
    method Action setPTID(PTIndex ptid);
    method Action shootdown(PTIndex ptid);
`ifdef PERFORMANCE_MONITORING
    method Action reportHit();
`endif
 endinterface
 
 interface ParTagTable;
     method Action setNewPTID(CapMem ptid);
     method PTIndex getPTID();
 endinterface
 
 function PTIndex reduce(CapMem aptid);
     // currently a hash implementation
     return hash(aptid);
 endfunction
 
 typedef struct {
     CapMem aptid;
     Bool v;
 } ParTagTableEntry deriving (Bits, Eq, FShow);
 
 module mkParTagTable#(ParTagTableInput inIfc)(ParTagTable);
 
     Reg#(CapMem) rg_cur_ptid <- mkReg(0);
 
     // used a direct mapped cache, where mcid is the index
     Vector#(PTNumber, Reg#(ParTagTableEntry)) tab <- replicateM(mkReg(unpack(0)));
 
     // FIFO for empty slots
     FIFOF#(PTIndex) freeQ <- mkUGSizedFIFOF(valueOf(PTNumber));
 
     // freeQ needs initialization
     Reg#(Bool) inited <- mkReg(False);
     Reg#(PTIndex) initIdx <- mkReg(0);
 
     // "random" cycle count
     Reg#(PTIndex) count <- mkReg(0);
 
     rule initFreeQ(!inited);
         freeQ.enq(initIdx);
         initIdx <= initIdx + 1;
         if(initIdx == fromInteger(valueOf(PTNumber) - 1)) begin
             inited <= True;
         end
     endrule
 
     // will wrap around
     rule doIncCycleCount;
         count <= count + 1;
     endrule
 
     method Action setNewPTID(CapMem aptid);
         // cycle counter is the "pseudo random number generator"
         function PTIndex getRandomIndex();
             return count;
         endfunction
 
         function Maybe#(PTIndex) findEntry(CapMem a);
             Maybe#(PTIndex) ret = Invalid;
             for(Integer i = 0; i < valueOf(PTNumber); i = i + 1) begin
                 let e = tab[i];
                 if(e.v && e.aptid == a) ret = tagged Valid (fromInteger(i));
             end
             return ret;
         endfunction
         rg_cur_ptid <= aptid;
         let mptid_m = findEntry(aptid);
         if(mptid_m matches tagged Invalid) begin
             PTIndex mptid = 0;
             if(freeQ.notEmpty) begin
                 mptid = freeQ.first;
                 freeQ.deq;
             end
             else begin
                 mptid = getRandomIndex;
                 inIfc.shootdown(mptid);
             end
             ParTagTableEntry e = ParTagTableEntry{aptid: aptid, v: True};
             tab[mptid] <= e;
             mptid_m = tagged Valid mptid;
             $display("setNewPTID - aptid: ", fshow(aptid), "; mptid: ", fshow(mptid));
         end
`ifdef PERFORMANCE_MONITORING
         else begin
             inIfc.reportHit();
         end
`endif
         inIfc.setPTID(fromMaybe(?, mptid_m));
 
         $display("ParTagTable:");
         for(Integer i = 0; i < valueOf(PTNumber); i = i + 1) begin
             $display("tab: ", fshow(tab[i]));
         end
     endmethod
 
     method PTIndex getPTID();
         return reduce(rg_cur_ptid);
     endmethod
 endmodule
`endif