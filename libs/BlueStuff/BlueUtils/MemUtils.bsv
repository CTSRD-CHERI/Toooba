/*-
 * Copyright (c) 2018-2023 Alexandre Joannou
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

package MemUtils;

export mkMem;
export mkMem2;

export mkMem2ToAXI4_Slave;
export mkAXI4SimpleMem;
export mkAXI4Mem;
export mkAXI4Mem2;

export mkMem2ToAXI4Lite_Slave;
export mkAXI4LiteSimpleMem;
export mkAXI4LiteMem;
export mkAXI4LiteMem2;

export mkAvalonMMMem;

export MemInit (..);

import BlueBasics  :: *;
import BlueAXI4    :: *;
import BlueAvalon  :: *;
import FIFO        :: *;
import MemSim      :: *;
import MemBRAM     :: *;
import MemTypes    :: *;

///////////////////
// 1 port memory //
////////////////////////////////////////////////////////////////////////////////

module mkMem #(Integer size, MemInit init) (Mem #(addr_t, data_t))
  provisos ( NumAlias #(nbChunks, TDiv #(data_sz, SizeOf #(MemSimDataT)))
           , NumAlias #(addr_sz, SizeOf #(addr_t))
           , NumAlias #(data_sz, SizeOf #(data_t))
           , NumAlias #(be_sz, TDiv #(data_sz, 8))
           , Add #(idx_sz, TLog #(be_sz), addr_sz)
           , Log #( TAdd #(1, be_sz)
                  , TAdd #(TLog #(be_sz), 1) )
           , Add #(_a, addr_sz, MemSimMaxAddrSize)
           , Add #(_b, be_sz, TMul #(nbChunks, 8))
           , Add #(_c, data_sz, TMul #(nbChunks, SizeOf #(MemSimDataT))) );
  `ifdef ALTERA
    String initStr = case (init) matches
      tagged UnInit: "UNUSED"
      tagged FilePath .f: f
      default: error ("unsupported memory initialization method")
    endcase;
    BRAM #(idx_sz, data_sz)
      m <- mkAlteraBRAM (size, initStr);
    Mem #(addr_t, data_t) mem <- wrapUnaligned ("port 0", m);
    return mem;
  `else
    Mem #(addr_t, data_t) mem[1] <- mkMemSim (1, size, init);
    return mem[0];
  `endif
endmodule

////////////////////
// 2 ports memory //
////////////////////////////////////////////////////////////////////////////////

module mkMem2 #(Integer size, MemInit init)
               (Array #(Mem #(addr_t, data_t)))
  provisos ( NumAlias #(nbChunks, TDiv #(data_sz, SizeOf #(MemSimDataT)))
           , Bits #(addr_t, addr_sz)
           , Bits #(data_t, data_sz)
           , Add #(idx_sz, TLog #(TDiv #(data_sz, 8)), addr_sz)
           , Log #( TAdd #(1, TDiv #(data_sz, 8))
                  , TAdd #(TLog #(TDiv #(data_sz, 8)), 1) )
           , Add #(_a, addr_sz, MemSimMaxAddrSize)
           , Add #(_b, TDiv #(data_sz, 8), TMul #(nbChunks, 8))
           , Add #(_c, data_sz, TMul #(nbChunks, SizeOf #(MemSimDataT))) );
  `ifdef ALTERA
    String initStr = case (init) matches
      tagged UnInit: "UNUSED"
      tagged FilePath .f: f
      default: error ("unsupported memory initialization method")
    endcase;
    BRAM2 #(idx_sz, data_sz, idx_sz, data_sz)
      m <- mkAlteraBRAM2 (size, initStr);
    Mem #(addr_t, data_t) mem[2];
    mem[0] <- wrapUnaligned ("port0", m.p0);
    mem[1] <- wrapUnaligned ("port1", m.p1);
    return mem;
  `else
    Mem #(addr_t, data_t) mem[2] <- mkMemSim (2, size, init);
    return mem;
  `endif
endmodule

///////////////////////
// AXI4Lite memories //
////////////////////////////////////////////////////////////////////////////////

module mkAXI4LiteSimpleMem #(Integer size, MemInit init)
                            (AXI4Lite_Slave #( addr_sz, data_sz
                                             , awuser_sz, wuser_sz, buser_sz
                                             , aruser_sz, ruser_sz ))
  provisos ( NumAlias #(nbChunks, TDiv #(data_sz, SizeOf #(MemSimDataT)))
           , Log #( TAdd #(1, TDiv #(data_sz, 8))
                  , TAdd #(TLog #(TDiv #(data_sz, 8)), 1) )
           , Add #(_a, TLog #(TDiv #(data_sz, 8)), addr_sz)
           , Add #(_b, TLog #(TDiv #(data_sz, 8)), data_sz)
           , Add #(_c, addr_sz, MemSimMaxAddrSize)
           , Add #(_e, TDiv #(data_sz, 8), TMul #(nbChunks, 8))
           , Add #(_f, data_sz, TMul #(nbChunks, SizeOf #(MemSimDataT))) );
  Mem #(Bit #(addr_sz), Bit #(data_sz)) mem <- mkMem (size, init);
  Mem #(Bit #(addr_sz), Bit #(data_sz)) m[2];
  m[0] = mem;
  m[1] = mem;
  let ifc <- mkMem2ToAXI4Lite_Slave (m);
  return ifc;
endmodule

module mkAXI4LiteMem #(Integer size, MemInit init)
                      (AXI4Lite_Slave #( addr_sz, data_sz
                                       , awuser_sz, wuser_sz, buser_sz
                                       , aruser_sz, ruser_sz ))
  provisos ( NumAlias #(nbChunks, TDiv #(data_sz, SizeOf #(MemSimDataT)))
           , Log #( TAdd #(1, TDiv #(data_sz, 8))
                  , TAdd #(TLog #(TDiv #(data_sz, 8)), 1) )
           , Add #(_a, TLog #(TDiv #(data_sz, 8)), addr_sz)
           , Add #(_b, TLog #(TDiv #(data_sz, 8)), data_sz)
           , Add #(_d, addr_sz, MemSimMaxAddrSize)
           , Add #(_e, TDiv #(data_sz, 8), TMul #(nbChunks, 8))
           , Add #(_f, data_sz, TMul #(nbChunks, SizeOf #(MemSimDataT))) );
  Mem #(Bit #(addr_sz), Bit #(data_sz)) mem[2] <- mkMem2 (size, init);
  AXI4Lite_Slave #( addr_sz, data_sz
                  , awuser_sz, wuser_sz, buser_sz
                  , aruser_sz, ruser_sz) ifc;
  ifc <- mkMem2ToAXI4Lite_Slave (mem);
  return ifc;
endmodule

module mkAXI4LiteMem2 #(Integer size, MemInit init)
                       (Array #(AXI4Lite_Slave #( addr_sz, data_sz
                                                , awuser_sz, wuser_sz, buser_sz
                                                , aruser_sz, ruser_sz )))
  provisos ( NumAlias #(nbChunks, TDiv #(data_sz, SizeOf #(MemSimDataT)))
           , Log #( TAdd #(1, TDiv #(data_sz, 8))
                  , TAdd #(TLog #(TDiv #(data_sz, 8)), 1) )
           , Add #(_a, TLog #(TDiv #(data_sz, 8)), addr_sz)
           , Add #(_b, TLog #(TDiv #(data_sz, 8)), data_sz)
           , Add #(_d, addr_sz, MemSimMaxAddrSize)
           , Add #(_e, TDiv #(data_sz, 8), TMul #(nbChunks, 8))
           , Add #(_f, data_sz, TMul #(nbChunks, SizeOf #(MemSimDataT))) );
  Mem #(Bit #(addr_sz), Bit #(data_sz)) mem[2] <- mkMem2 (size, init);
  Mem #(Bit #(addr_sz), Bit #(data_sz)) portA[2];
  portA[0] = mem[0];
  portA[1] = mem[0];
  Mem #(Bit #(addr_sz), Bit #(data_sz)) portB[2];
  portB[0] = mem[1];
  portB[1] = mem[1];
  AXI4Lite_Slave #( addr_sz, data_sz
                  , awuser_sz, wuser_sz, buser_sz
                  , aruser_sz, ruser_sz) ifcs[2];
  ifcs[0] <- mkMem2ToAXI4Lite_Slave (portA);
  ifcs[1] <- mkMem2ToAXI4Lite_Slave (portB);
  return ifcs;
endmodule

///////////////////
// AXI4 memories //
////////////////////////////////////////////////////////////////////////////////

module mkAXI4SimpleMem #(Integer size, MemInit init)
                        (AXI4_Slave #( id_sz, addr_sz, data_sz
                                     , awuser_sz, wuser_sz, buser_sz
                                     , aruser_sz, ruser_sz ))
  provisos ( NumAlias #(axiNumBytes_fat_sz, TExp #(SizeOf #(AXI4_Size)))
           , NumAlias #( numBytes_sz
                       , TMax #( 1
                               , TLog #(TAdd #( 1
                                              , TLog #(TDiv #(data_sz, 8))))))
           , NumAlias #(data_byte_sz, TDiv #(data_sz, 8))
           , NumAlias #(byteIdx_sz, TLog #(data_byte_sz))
           , NumAlias #(nbChunks, TDiv #(data_sz, SizeOf #(MemSimDataT)))
           , Log #( TAdd #(1, TDiv #(data_sz, 8))
                  , TAdd #(TLog #(TDiv #(data_sz, 8)), 1))
           , Log #(data_byte_sz, byteIdx_sz)
           , Add #(_a, axiNumBytes_fat_sz, addr_sz)
           , Add #(_b, byteIdx_sz, addr_sz)
           , Add #(_c, numBytes_sz, SizeOf #(AXI4_Size))
           , Add #(_d, addr_sz, MemSimMaxAddrSize)
           , Add #(_e, TDiv #(data_sz, 8), TMul #(nbChunks, 8))
           , Add #(_f, data_sz, TMul #(nbChunks, SizeOf #(MemSimDataT))) );
  Mem #(Bit #(addr_sz), Bit #(data_sz)) mem <- mkMem (size, init);
  Mem #(Bit #(addr_sz), Bit #(data_sz)) m[2];
  m[0] = mem;
  m[1] = mem;
  let ifc <- mkMem2ToAXI4_Slave (m);
  return ifc;
endmodule

module mkAXI4Mem #(Integer size, MemInit init)
                  (AXI4_Slave #( id_sz, addr_sz, data_sz
                               , awuser_sz, wuser_sz, buser_sz
                               , aruser_sz, ruser_sz ))
  provisos ( NumAlias #(axiNumBytes_fat_sz, TExp #(SizeOf #(AXI4_Size)))
           , NumAlias #( numBytes_sz
                       , TMax #( 1
                               , TLog #(TAdd #( 1
                                              , TLog #(TDiv #(data_sz, 8))))))
           , NumAlias #(data_byte_sz, TDiv #(data_sz, 8))
           , NumAlias #(byteIdx_sz, TLog #(data_byte_sz))
           , NumAlias #(nbChunks, TDiv #(data_sz, SizeOf #(MemSimDataT)))
           , Log #( TAdd #(1, TDiv #(data_sz, 8))
                  , TAdd #(TLog #(TDiv #(data_sz, 8)), 1))
           , Log #(data_byte_sz, byteIdx_sz)
           , Add #(_a, axiNumBytes_fat_sz, addr_sz)
           , Add #(_b, byteIdx_sz, addr_sz)
           , Add #(_c, numBytes_sz, SizeOf #(AXI4_Size))
           , Add #(_d, addr_sz, MemSimMaxAddrSize)
           , Add #(_e, TDiv #(data_sz, 8), TMul #(nbChunks, 8))
           , Add #(_f, data_sz, TMul #(nbChunks, SizeOf #(MemSimDataT))) );
  Mem #(Bit #(addr_sz), Bit #(data_sz)) mem[2] <- mkMem2 (size, init);
  AXI4_Slave #( id_sz, addr_sz, data_sz
              , awuser_sz, wuser_sz, buser_sz
              , aruser_sz, ruser_sz) ifc;
  ifc <- mkMem2ToAXI4_Slave (mem);
  return ifc;
endmodule

module mkAXI4Mem2 #(Integer size, MemInit init)
                   (Array #(AXI4_Slave #( id_sz, addr_sz, data_sz
                                        , awuser_sz, wuser_sz, buser_sz
                                        , aruser_sz, ruser_sz )))
  provisos ( NumAlias #(axiNumBytes_fat_sz, TExp #(SizeOf #(AXI4_Size)))
           , NumAlias #( numBytes_sz
                       , TMax #( 1
                               , TLog #(TAdd #( 1
                                              , TLog #(TDiv #(data_sz, 8))))))
           , NumAlias #(data_byte_sz, TDiv #(data_sz, 8))
           , NumAlias #(byteIdx_sz, TLog #(data_byte_sz))
           , NumAlias #(nbChunks, TDiv #(data_sz, SizeOf #(MemSimDataT)))
           , Log #( TAdd #(1, TDiv #(data_sz, 8))
                  , TAdd #(TLog #(TDiv #(data_sz, 8)), 1))
           , Log #(data_byte_sz, byteIdx_sz)
           , Add #(_a, axiNumBytes_fat_sz, addr_sz)
           , Add #(_b, byteIdx_sz, addr_sz)
           , Add #(_c, numBytes_sz, SizeOf #(AXI4_Size))
           , Add #(_d, addr_sz, MemSimMaxAddrSize)
           , Add #(_e, TDiv #(data_sz, 8), TMul #(nbChunks, 8))
           , Add #(_f, data_sz, TMul #(nbChunks, SizeOf #(MemSimDataT))) );
  Mem #(Bit #(addr_sz), Bit #(data_sz)) mem[2] <- mkMem2 (size, init);
  Mem #(Bit #(addr_sz), Bit #(data_sz)) portA[2];
  portA[0] = mem[0];
  portA[1] = mem[0];
  Mem #(Bit #(addr_sz), Bit #(data_sz)) portB[2];
  portB[0] = mem[1];
  portB[1] = mem[1];
  AXI4_Slave #( id_sz, addr_sz, data_sz
              , awuser_sz, wuser_sz, buser_sz
              , aruser_sz, ruser_sz) ifcs[2];
  ifcs[0] <- mkMem2ToAXI4_Slave (portA);
  ifcs[1] <- mkMem2ToAXI4_Slave (portB);
  return ifcs;
endmodule

//////////////////////////
// AXI4Lite Mem wrapper //
////////////////////////////////////////////////////////////////////////////////

module mkMem2ToAXI4Lite_Slave #(Array #(Mem #(addr_t, data_t)) mem)
                               (AXI4Lite_Slave #( addr_sz, data_sz
                                                , awuser_sz, wuser_sz, buser_sz
                                                , aruser_sz, ruser_sz ))
  provisos ( Bits #(data_t, data_sz)
           , Bits #(addr_t, addr_sz)
           , Div #(data_sz, 8, data_byte_sz)
           , Log #(data_byte_sz, byteIdx_sz)
           , Add #(_a, byteIdx_sz, addr_sz) );

  // AXI4Lite shim to provide a slave port
  AXI4Lite_Shim #( addr_sz, data_sz
                 , awuser_sz, wuser_sz, buser_sz
                 , aruser_sz, ruser_sz ) shim <- mkAXI4LiteShim;

  // responses info tracking fifos
  FIFO #(Bit #(TAdd #(byteIdx_sz, 3))) readFF <- mkLFIFO;

  // Force some prioritisation to cope with the case where both mem interfaces
  // are the same (i.e. using a single port Mem as the backing memory)
  (* descending_urgency = "readReq, writeReq" *)
  (* descending_urgency = "readRsp, writeRsp" *)

  // handle AXI4Lite write requests
  /////////////////////////////////

  rule writeReq;
    AXI4Lite_AWFlit #(addr_sz, awuser_sz) awflit <- get (shim.master.aw);
    AXI4Lite_WFlit #(data_sz, wuser_sz) wflit <- get (shim.master.w);
    Bit #(byteIdx_sz) byteShift = truncate (awflit.awaddr);
    let bitShift = {byteShift, 3'b000};
    mem[0].req.put (
      tagged WriteReq { addr: unpack (awflit.awaddr)
                      , byteEnable: unpack (wflit.wstrb) >> byteShift
                      , data: unpack (wflit.wdata >> bitShift) });
  endrule
  rule writeRsp (mem[0].rsp.peek matches tagged WriteRsp);
    mem[0].rsp.drop;
    shim.master.b.put (AXI4Lite_BFlit { bresp: OKAY, buser: ? });
  endrule

  // handle AXI4 read requests
  ////////////////////////////

  rule readReq;
    let arflit <- get (shim.master.ar);
    mem[1].req.put (
      tagged ReadReq { addr: unpack (arflit.araddr)
                     , numBytes: fromInteger (log2 (valueOf (data_byte_sz))) });
    readFF.enq ({truncate (arflit.araddr), 3'b000});
  endrule
  rule readRsp (mem[1].rsp.peek matches tagged ReadRsp .rsp);
    mem[1].rsp.drop;
    readFF.deq;
    shim.master.r.put (
      AXI4Lite_RFlit { rdata: pack (rsp) << readFF.first
                     , rresp: OKAY
                     , ruser: ? });
  endrule

  // return the slave interface
  return shim.slave;
endmodule

//////////////////////
// AXI4 Mem wrapper //
////////////////////////////////////////////////////////////////////////////////

module mkMem2ToAXI4_Slave #(Array #(Mem #(addr_t, data_t)) mem)
                           (AXI4_Slave #( id_sz, addr_sz, data_sz
                                        , awuser_sz, wuser_sz, buser_sz
                                        , aruser_sz, ruser_sz ))
  provisos ( Bits #(data_t, data_sz)
           , Bits #(addr_t, addr_sz)
           , NumAlias #(axiNumBytes_fat_sz, TExp #(SizeOf #(AXI4_Size)))
           , NumAlias #( numBytes_sz
                       , TMax #( 1
                               , TLog #(TAdd #( 1
                                              , TLog #(TDiv #(data_sz, 8))))))
           , NumAlias #(data_byte_sz, TDiv #(data_sz, 8))
           , NumAlias #(byteShft_sz, TLog #(data_byte_sz))
           , NumAlias #(bitShft_sz, TAdd #(byteShft_sz, 3))
           , Log #(data_byte_sz, byteIdx_sz)
           , Add #(_a, axiNumBytes_fat_sz, addr_sz)
           , Add #(_b, byteIdx_sz, addr_sz)
           , Add #(_c, numBytes_sz, SizeOf #(AXI4_Size)) );

  // AXI4 shim to provide a slave port
  let shim <- mkAXI4Shim;

  // AXI4 addr calculation helpers
  function nextAddr (burst, size, addr) = case (burst)
    FIXED: addr;
    default: (addr + zeroExtend (fromAXI4_Size (size)));
  endcase;
  function nextLen (len) = len - 1;

  // Force some prioritisation to cope with the case where both mem interfaces
  // are the same (i.e. using a single port Mem as the backing memory)
  //(* descending_urgency = "readReq, writeReq" *)
  //(* descending_urgency = "readRsp, writeRsp" *)

  // handle AXI4 write requests
  /////////////////////////////

  let wflitCount <- mkReg (0);
  let awAddrReg <- mkRegU;
  let writeFF <- mkFIFO;
  // AXI4 AWFlit and WFlit handling
  rule writeReq;
    // get a handle on the current awflit
    let awflit = shim.master.aw.peek;
    // prepare the new wflit counter value
    let wflitCountNext = wflitCount + 1;
    // get a new wflit and identify the last one in a burst...
    let wflit <- get (shim.master.w);
    if (wflit.wlast) begin // if last one of the burst:
      wflitCountNext = 0; // re-initialize the wflit counter
      shim.master.aw.drop; // drop the awflit
      writeFF.enq (awflit.awid); // notify the response rule
    end

    // get the current address
    // (from the awflit on first wflit, from a register on subsequent wflits)
    let addr = (wflitCount == 0) ? awflit.awaddr : awAddrReg;
    // update the wflit count
    wflitCount <= wflitCountNext;
    // update the address register
    awAddrReg <= nextAddr (awflit.awburst, awflit.awsize, addr);

    // perform the memory write
    Bit #(byteIdx_sz) byteShift = truncate (addr);
    let bitShift = {byteShift, 3'b000};
    mem[0].req.put (
      tagged WriteReq { addr: unpack (addr)
                      , byteEnable: unpack (wflit.wstrb) >> byteShift
                      , data: unpack (wflit.wdata >> bitShift) });
  endrule
  // when the whole burst is handled, return an AXI4 BFlit write response
  rule writeRsp;
    writeFF.deq;
    shim.master.b.put (AXI4_BFlit { bid: writeFF.first
                                  , bresp: OKAY
                                  , buser: ? });
  endrule
  // inner memory should be drained of its write responses not to block
  rule drainInternalWriteRsp (mem[0].rsp.peek matches tagged WriteRsp);
    mem[0].rsp.drop;
  endrule

  // handle AXI4 read requests
  ////////////////////////////

  let rflitCount <- mkReg (0);
  let arAddrReg <- mkRegU;
  FIFO #(Tuple3 #(Bit #(id_sz), Bit #(bitShft_sz), Bool)) readFF <- mkFIFO;
  rule readReq;
    // get a handle on the current arflit
    let arflit = shim.master.ar.peek;
    // prepare next rflit counter value
    let rflitCountNext = rflitCount + 1;
    // detect the end of the burst of reads
    let isLast = rflitCount == arflit.arlen;
    if (isLast) begin
      rflitCountNext = 0; // re-initialize the rflit counter
      shim.master.ar.drop; // discard the pending arflit
    end
    // get the current address
    // (from the arflit on first rflit, from a register on subsequent rflits)
    let addr = (rflitCount == 0) ? arflit.araddr : arAddrReg;
    // update the rflit count
    rflitCount <= rflitCountNext;
    // update the address register
    arAddrReg <= nextAddr (arflit.arburst, arflit.arsize, addr);
    // perform the memory read and notify the response rule
    mem[1].req.put (
      tagged ReadReq { addr: unpack (addr)
                     , numBytes: truncate (pack (arflit.arsize)) });
    readFF.enq (tuple3 (arflit.arid, {truncate (addr), 3'b000}, isLast));
  endrule
  // send individual AXI4 RFlit responses
  rule readRsp (mem[1].rsp.peek matches tagged ReadRsp .rsp);
    mem[1].rsp.drop;
    match {.arid, .bitShift, .isLast} = readFF.first;
    readFF.deq;
    shim.master.r.put (AXI4_RFlit { rid: arid
                                  , rdata: pack (rsp) << bitShift
                                  , rresp: OKAY
                                  , rlast: isLast
                                  , ruser: ? });
  endrule

  // return the slave interface
  return shim.slave;
endmodule

////////////////////////
// Avalon Mem wrapper //
////////////////////////////////////////////////////////////////////////////////

function Slave #(AvalonMMRequest #(addr_sz, data_sz), AvalonMMResponse #(data_sz))
  memSlaveToAvalonMMSlave (Mem #(addr_t, data_t) mem)
  provisos ( Bits #(addr_t, addr_sz)
           , Bits #(data_t, data_sz)
           , NumAlias #(be_sz, TDiv #(data_sz, 8))
           , Add #(_a, TMax #(1, TLog#(TAdd #(1, TLog#(be_sz))))
                     , TLog #(TAdd #(1, be_sz))) ) =
  mapSlave (avalonMMReqToMemReq, memRspToAvalonMMRsp, mem);

module mkAvalonMMMem #(Integer size, MemInit init)
  (Slave #(AvalonMMRequest #(addr_sz, data_sz), AvalonMMResponse #(data_sz)))
  provisos ( NumAlias #(nbChunks, TDiv #(data_sz, SizeOf #(MemSimDataT)))
           , NumAlias #(be_sz, TDiv #(data_sz, 8))
           , Add #(idx_sz, TLog #(be_sz), addr_sz)
           , Log #( TAdd #(1, be_sz)
                  , TAdd #(TLog #(be_sz), 1) )
           , Add #(_a, addr_sz, MemSimMaxAddrSize)
           , Add #(_b, be_sz, TMul #(nbChunks, 8))
           , Add #(_c, data_sz, TMul #(nbChunks, SizeOf #(MemSimDataT)))
           , Add #(_d, TMax #(1, TLog #(TAdd #(1, TLog#(be_sz))))
                     , TLog #(TAdd #(1, be_sz))) );
  Mem #(Bit #(addr_sz), Bit #(data_sz)) mem <- mkMem (size, init);
  return memSlaveToAvalonMMSlave (mem);
endmodule

endpackage
