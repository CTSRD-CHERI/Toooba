/*-
 * Copyright (c) 2018-2021 Alexandre Joannou
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory (Department of Computer Science and
 * Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
 * DARPA SSITH research programme.
 *
 * This material is based upon work supported by the DoD Information Analysis
 * Center Program Management Office (DoD IAC PMO), sponsored by the Defense
 * Technical Information Center (DTIC) under Contract No. FA807518D0004.  Any
 * opinions, findings and conclusions or recommendations expressed in this
 * material are those of the author(s) and do not necessarily reflect the views
 * of the Air Force Installation Contracting Agency (AFICA).
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

package MemSim;

export mkMemSim;
export mkMemSimWithOffset;
export MemSimMaxAddrSize;
export MemSimDataT;

import FIFO         :: *;
import Vector       :: *;
import Printf       :: *;
import Clocks       :: *;
import SpecialFIFOs :: *;

import MemTypes    :: *;
import SourceSink  :: *;
import MasterSlave :: *;

// Types and BDPI interface functions
////////////////////////////////////////////////////////////////////////////////

typedef 64 MemSimMaxAddrSize;

typedef Bit #(64) MemSimCHandle;
typedef Bit #(64) MemSimSizeT;
typedef Bit #(MemSimMaxAddrSize) MemSimAddrT;
typedef Bit #(8) MemSimAccessSizeT;
typedef Bit #(64) MemSimDataT;
// XXX
// this is broken in bsc version untagged-gb37e90ec (build b37e90ec)
// typedef Bit #(TDiv #(SizeOf #(MemSimDataT), 8)) MemSimByteEnT;
// using this instead
// XXX
typedef Bit #(8) MemSimByteEnT;

import "BDPI" mem_create =
  function ActionValue #(MemSimCHandle) mem_create (MemSimSizeT byteSize);

import "BDPI" mem_init =
  function Action mem_init ( MemSimCHandle mem
                           , String hexFile
                           , MemSimAddrT offset );

import "BDPI" mem_zero = function Action mem_zero (MemSimCHandle mem);
import "BDPI" mem_read =
  function ActionValue #(MemSimDataT) mem_read ( MemSimCHandle mem
                                               , MemSimAddrT addr
                                               , MemSimAccessSizeT byteSize );
import "BDPI" mem_write =
  function Action mem_write ( MemSimCHandle mem
                            , MemSimAddrT addr
                            , MemSimByteEnT byteEn
                            , MemSimDataT data );

// Simulation memory with explicit offset
////////////////////////////////////////////////////////////////////////////////

module mkMemSimWithOffset #( Integer nIfcs
                           , Integer offset
                           , Integer size
                           , Maybe #(String) file)
  (Array #(Mem #(addr_t, data_t)))
  provisos ( NumAlias #(nbChunks, TDiv #(data_sz, SizeOf #(MemSimDataT)))
           , Bits #(addr_t, addr_sz)
           , Bits #(data_t, data_sz)
           , Add #(_a, addr_sz, MemSimMaxAddrSize)
           , Add #(_b, TDiv #(data_sz, 8), TMul #(nbChunks, 8))
           , Add #(_c, data_sz, TMul #(nbChunks, SizeOf #(MemSimDataT))) );

  // sanitize size input
  MemSimSizeT actualSize = fromInteger (size);
  if (2**(log2 (size)) != size) begin
    MemSimSizeT powerOf2Size = fromInteger (2**log2 (size));
    errorM (sprintf ( "Error: mkMemSimWithOffset called with non-power-of 2"
                    + " size %0d (nearest power-of-2 is %0d)"
                    , actualSize, powerOf2Size ));
  end

  let clk <- exposeCurrentClock;
  let rst <- mkReset (0, False, clk);

  Reg #(MemSimCHandle) memCHandle <- mkRegU;
  Reg #(Bool)         isAllocated <- mkSyncReg (False, clk, rst.new_rst, clk);
  Reg #(Bool)       isInitialized <- mkReg (False);

  rule do_alloc (!isAllocated);
    let tmp <- mem_create (actualSize);
    memCHandle <= tmp;
    isAllocated <= True;
  endrule
  rule do_init (isAllocated && !isInitialized);
    case (file) matches
      tagged Valid .f: mem_init (memCHandle, f, fromInteger (0));
      default: mem_zero (memCHandle);
    endcase
    isInitialized <= True;
  endrule

  // helper functions for simulated memory accesses
  // addresses
  function memAddrs (base, i) = zeroExtend (pack (base) + fromInteger (8*i));
  // elements read
  function memReadElem (nBytes, addr, i);
    if (i == 0) return mem_read (memCHandle, addr, 8'h01 << nBytes[1:0]);
    else if (fromInteger ((i+1)*8) <= (1 << nBytes))
      return mem_read (memCHandle, addr, 8'h08);
      else return actionvalue return 0; endactionvalue;
  endfunction
  // element write
  function memWriteElem (addr, be, d) =
    (be == 0) ? noAction : mem_write (memCHandle, addr, be, d);

  Mem #(addr_t, data_t) ifcs[nIfcs];
  for (Integer i = 0; i < nIfcs; i = i + 1) begin
    FIFO #(MemRsp #(data_t)) rsp <- mkPipelineFIFO;
    ifcs[i] = interface Slave;
      interface req = interface Sink;
        method canPut = isInitialized;
        method put (req) if (isInitialized) = action
          case (offsetMemReq (req, fromInteger (-offset))) matches
            tagged ReadReq .r: begin
              Vector #(nbChunks, MemSimDataT)
                res <- zipWithM ( memReadElem (r.numBytes)
                                , genWith (memAddrs (r.addr))
                                , genVector );
              rsp.enq (ReadRsp (unpack (truncate (pack (res)))));
            end
            tagged WriteReq .w: begin
              Vector #(nbChunks, MemSimAddrT) as = genWith (memAddrs (w.addr));
              Vector #(nbChunks, MemSimByteEnT)
                bes = unpack (zeroExtend (pack (w.byteEnable)));
              Vector #(nbChunks, MemSimDataT)
                ds = unpack (zeroExtend (pack (w.data)));
              let _ <- zipWith3M (memWriteElem, as, bes, ds);
              rsp.enq (WriteRsp);
            end
          endcase
        endaction;
      endinterface;
      interface rsp = interface Source;
        method canPeek = isInitialized;
        method peek if (isInitialized) = rsp.first;
        method drop if (isInitialized) = rsp.deq;
      endinterface;
    endinterface;
  end

  return ifcs;

endmodule

// Simulation memory
////////////////////////////////////////////////////////////////////////////////

module mkMemSim #(Integer nIfcs, Integer size, Maybe #(String) file)
  (Array #(Mem #(addr_t, data_t)))
  provisos ( NumAlias #(nbChunks, TDiv #(data_sz, SizeOf #(MemSimDataT)))
           , Bits #(addr_t, addr_sz)
           , Bits #(data_t, data_sz)
           , Add #(_a, addr_sz, MemSimMaxAddrSize)
           , Add #(_b, TDiv #(data_sz, 8), TMul #(nbChunks, 8))
           , Add #(_c, data_sz, TMul #(nbChunks, SizeOf #(MemSimDataT))) );
  let mem <- mkMemSimWithOffset (nIfcs, 0, size, file);
  return mem;
endmodule

endpackage
