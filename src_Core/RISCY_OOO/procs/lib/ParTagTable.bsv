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
 import CHERICap :: *;
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
     method Maybe#(PTIndex) translate(CapMem ptid);
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
 
     Reg#(CapMem) rg_cur_aptid <- mkReg(0);
     Reg#(PTIndex) rg_cur_mptid <- mkReg(0);
     RWire#(CapMem) wr_aptid <- mkRWire;
 
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
 
     rule setPTID;
        if(wr_aptid.wget() matches tagged Valid .ap) begin
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
            //if (getCID(rg_cur_aptid) == getCID(aptid)) noAction;
            //else begin
            // send pulse wire
            //pw.send();
            rg_cur_aptid <= ap;
            let mptid_m = findEntry(ap);
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
                ParTagTableEntry e = ParTagTableEntry{aptid: ap, v: True};
                tab[mptid] <= e;
                mptid_m = tagged Valid mptid;
                $display("setNewPTID - aptid: ", fshow(ap), "; mptid: ", fshow(mptid));
            end
`ifdef PERFORMANCE_MONITORING
            else begin
                inIfc.reportHit();
            end
`endif
         // Do not set PTID anymore
         //inIfc.setPTID(fromMaybe(?, mptid_m));
 
            $display("ParTagTable:");
            for(Integer i = 0; i < valueOf(PTNumber); i = i + 1) begin
                $display("tab: ", fshow(tab[i]));
            end
        end
     endrule

     method Action setNewPTID(CapMem aptid);
        wr_aptid.wset(aptid);
     endmethod

     method Maybe#(PTIndex) translate(CapMem ptid);
        function Maybe#(PTIndex) findEntry(CapMem a);
           Maybe#(PTIndex) ret = Invalid;
           for(Integer i = 0; i < valueOf(PTNumber); i = i + 1) begin
               let e = tab[i];
               if(e.v && e.aptid == a) ret = tagged Valid (fromInteger(i));
           end
           //if (pw) return Invalid;
           //else return ret;
           return ret;
        endfunction
        return findEntry(ptid);
     endmethod
 
     method PTIndex getPTID();
         return reduce(rg_cur_aptid);
     endmethod
 endmodule
`endif