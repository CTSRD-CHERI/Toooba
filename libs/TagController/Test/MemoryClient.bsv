/* Copyright 2015 Matthew Naylor
 * Copyright 2018 Jonathan Woodruff
 * Copyright 2018-2022 Alexandre Joannou
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-10-C-0237
 * ("CTSRD"), as part of the DARPA CRASH research programme.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249
 * ("MRC2"), as part of the DARPA MRC research programme.
 *
 * This software was developed by the University of Cambridge Computer
 * Laboratory as part of the Rigorous Engineering of Mainstream
 * Systems (REMS) project, funded by EPSRC grant EP/K008528/1.
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

import DefaultValue :: *;
import StmtFSM      :: *;
import RegFile      :: *;
import FIFO         :: *;
import FIFOF        :: *;
import SpecialFIFOs :: *;
import Vector       :: *;
import BlueCheck    :: *;
import Debug        :: *;
import SourceSink   :: *;
import BlueAXI4     :: *;

// This module has been developed for the purpose of testing the
// (shared) memory sub-system.  It aims to provide a neat Bluespec
// interface to memory resembling the memory instructions of the MIPS
// ISA.  Given a fiddley axiSlaveer interface we return a neat
// MemoryClient interface.

// Interface ==================================================================

interface MemoryClient;

  // Load value at address
  method Action load(Addr addr);

  // Store data to address
  method Action store(Data data, Addr addr);

  // Get response
  method ActionValue#(MemoryClientResponse) getResponse;
  method Bool canGetResponse;

  // Check if all outstanding operations have been consumed
  method Bool done;

  // Set mapping from Addr values to physical address
  method Action setAddrMap(AddrMap map);
endinterface

// Types ======================================================================

typedef 4 NumAddrBits;

typedef struct {
  Bit#(NumAddrBits) addr;
  Bit#(1) dword;
} Addr
  deriving (Bits, Eq, Bounded);

typedef Bit#(17) Data;

typedef union tagged {
  void WriteResponse;
  Data DataResponse;
} MemoryClientResponse
  deriving (Bits, Eq, FShow);

typedef struct {
  Bool isLoad;           // True for load, False for store to data mem
  Bit#(8) lowAddr;       // Lower 8-bits of address
} OutstandingMemInstr
  deriving (Bits);

// How to map an Addr to a 24-bit physical address offset
typedef struct {
  Vector#(NumAddrBits, Bit#(5)) index;
} AddrMap deriving (Bits, Eq, Bounded);

// Convert an Addr to a 64-bit MIPS virtual address
function Bit#(64) fromAddr(Addr x, AddrMap addrMap);
  Bit#(24) offset = 0;
  for (Integer i = 0; i < valueOf(NumAddrBits); i=i+1)
    offset[addrMap.index[i]] = x.addr[i];
  Bit#(5) line = extend({x.dword, 4'b000});
  return (64'h00000000 + {0, offset, line });
endfunction

// Functions ==================================================================

// Convert from Data to 64-bit data
function Tuple2#(Bit#(1), Bit#(128)) fromData(Data x) = tuple2(x[16],zeroExtend(x));

// Convert from 64-bit data to Data
function Data toData(Bit#(1) t, Bit#(128) d) = {t, d[15:0]};

// Show addresses
instance FShow#(Addr);
  function Fmt fshow (Addr a) =
    $format("%x:%x", a.addr, a.dword);
endinstance

// Show address map
instance FShow#(AddrMap);
  function Fmt fshow(AddrMap map) =
    $format("<" , map.index[3],
            ", ", map.index[2],
            ", ", map.index[1],
            ", ", map.index[0],
            ">");
endinstance

// Custom generators ==========================================================

// Custom generator for AddrMap.  Each value in an AddrMap must be
// unique and lie in the range 0..23 inclusive.

module [BlueCheck] genAddrMap (Gen#(AddrMap));
  Gen#(Vector#(NumAddrBits, Bit#(3))) offsetsGen <- mkGenDefault;
  method ActionValue#(AddrMap) gen;
    Vector#(NumAddrBits, Bit#(3)) offsets <- offsetsGen.gen;
    AddrMap map;
    Bit#(5) offset = 0;
    for (Integer i = 0; i < valueOf(NumAddrBits); i = i+1) begin
      Bit#(5) newOffset = offset + zeroExtend(bound(offsets[i], 4));
      map.index[i] = newOffset;
      offset = newOffset+1;
    end
    return map;
  endmethod
endmodule

instance MkGen#(AddrMap);
  mkGen = genAddrMap;
endinstance

// Memory client module =======================================================

module mkMemoryClient#(AXI4_Slave#(idWidth, addrWidth, 128, 0, 1, 0, 0, 1) axiSlave) (MemoryClient)
  provisos (Add#(a__, addrWidth, 64), Add#(b__, idWidth, 8));

  // Response FIFO
  FIFOF#(MemoryClientResponse) responseFIFO <- mkSizedFIFOF(4);

  // FIFO storing details of outstanding loads/stores
  FIFOF#(OutstandingMemInstr) outstandingFIFO <- mkSizedFIFOF(4);

  Reg#(Bit#(8)) idCount <- mkReg(0);

  // Address mapping
  Reg#(AddrMap) addrMap <- mkRegU;

  Bool nextIsLoad = outstandingFIFO.first.isLoad;
  // Fill response FIFO
  rule handleWriteResponses (!nextIsLoad && axiSlave.b.canPeek);
    outstandingFIFO.deq;
    let b <- get(axiSlave.b);
  endrule
  rule handleReadResponses (nextIsLoad && axiSlave.r.canPeek);
    outstandingFIFO.deq;
    let r <- get(axiSlave.r);
    responseFIFO.enq(DataResponse(toData(r.ruser, r.rdata)));
  endrule

  // Functions
  function Action loadGeneric(Addr addr) =
    action
      Bit#(64) fullAddr = fromAddr(addr, addrMap);
      AXI4_ARFlit#(idWidth, addrWidth, 0) addrReq = defaultValue;
      addrReq.arid = truncate(idCount);
      idCount <= idCount + 1;
      addrReq.araddr = truncate(fullAddr);
      addrReq.arsize = 16;
      addrReq.arcache = 4'b1011;
      axiSlave.ar.put(addrReq);

      outstandingFIFO.enq(OutstandingMemInstr{
        isLoad: True,
        lowAddr: fullAddr[7:0]
      });
    endaction;

  function Action storeGeneric(Data data, Addr addr) =
    action
      Bit#(64) fullAddr = fromAddr(addr, addrMap);
      AXI4_AWFlit#(idWidth, addrWidth, 0) addrReq = defaultValue;
      addrReq.awid = truncate(idCount);
      idCount <= idCount + 1;
      addrReq.awcache = 4'b1011;
      addrReq.awaddr = truncate(fullAddr);
      axiSlave.aw.put(addrReq);

      AXI4_WFlit#(128, 1) dataReq = defaultValue;
      match {.t, .d} = fromData(data);
      dataReq.wuser = t;
      dataReq.wdata = d;
      axiSlave.w.put(dataReq);

      outstandingFIFO.enq(OutstandingMemInstr{
        isLoad: False,
        lowAddr: fullAddr[7:0]
      });
    endaction;

  // Load value at address into register
  method Action load(Addr addr);
    loadGeneric(addr);
  endmethod

  // Store data to address
  method Action store(Data data, Addr addr);
    storeGeneric(data, addr);
  endmethod

  // Responses
  method ActionValue#(MemoryClientResponse) getResponse;
    responseFIFO.deq;
    return responseFIFO.first;
  endmethod

  method Bool canGetResponse = responseFIFO.notEmpty;

  // Check if all outstanding operations have been consumed
  method Bool done = !outstandingFIFO.notEmpty &&
                     !responseFIFO.notEmpty;

//   // Set mapping from Addr values to physical address
  method Action setAddrMap(AddrMap map);
    addrMap <= map;
  endmethod

endmodule

// Golden memory client =======================================================

module mkMemoryClientGolden (MemoryClient);

  // Response FIFO
  FIFOF#(MemoryClientResponse) responseFIFO <- mkSizedFIFOF(4);


  // Golden memory unit (one mem per dword)
  RegFile#(Bit#(NumAddrBits), Data) memA <- mkRegFileFull;
  RegFile#(Bit#(NumAddrBits), Data) memB <- mkRegFileFull;

  // Keep track of tag bits
  RegFile#(Addr, Bool) tagMem <- mkRegFileFull;

  // Initialisation
  Reg#(Bool) init <- mkReg(True);
  Reg#(Addr) memAddr <- mkReg(minBound);

  // Address mapping
  Reg#(AddrMap) addrMap <- mkRegU;

  rule initialiseMem(init);
    if (pack(memAddr) == maxBound)
      init <= False;
    else
      memAddr <= unpack(pack(memAddr) + 1);
    memA.upd(memAddr.addr, 0);
    memB.upd(memAddr.addr, 0);
    tagMem.upd(memAddr, False);
  endrule

  // Load value at address into register
  method Action load(Addr addr) if (!init);
    let dA = memA.sub(addr.addr);
    let dB = memB.sub(addr.addr);
    responseFIFO.enq(DataResponse(addr.dword == 1 ? dB : dA));
  endmethod

  // Store data to address
  method Action store(Data data, Addr addr) if (!init);
    if (addr.dword == 1)
      memB.upd(addr.addr, data);
    else
      memA.upd(addr.addr, data);
    tagMem.upd(addr, False);
  endmethod

  // Check if all outstanding operations have been consumed
  method Bool done = !responseFIFO.notEmpty;

  // Responses
  method ActionValue#(MemoryClientResponse) getResponse;
    //$display("response: ", fshow(responseFIFO.first));
    responseFIFO.deq;
    return responseFIFO.first;
  endmethod

  method Bool canGetResponse = responseFIFO.notEmpty;

  //   // Set mapping from Addr values to physical address
  method Action setAddrMap(AddrMap map);
    addrMap <= map;
  endmethod

endmodule
