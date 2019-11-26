package Proc;

// Copyright (c) 2018 Massachusetts Institute of Technology
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

// Portions Copyright (c) 2019 Bluespec, Inc.

// ================================================================
// BSV lib imports

import Assert       :: *;
import Vector       :: *;
import GetPut       :: *;
import ClientServer :: *;
import Connectable  :: *;
import FIFOF        :: *;
import ConfigReg    :: *;

// ----------------
// BSV additional libs

import GetPut_Aux     :: *;

// ================================================================
// Project imports

// ----------------
// From MIT RISCY-OOO

import Types::*;
import ProcTypes::*;
import L1CoCache::*;
import L2Tlb::*;
import CCTypes::*;
import CacheUtils::*;
import LLCache::*;
import MemLoader::*;
import L1LLConnect::*;
import LLCDmaConnect::*;
import MMIOAddrs::*;
import MMIOCore::*;
import DramCommon::*;
import Performance::*;

// ----------------
// From Tooba

import ISA_Decls  :: *;

import Core              :: *;
import Proc_IFC          :: *;
import MMIOPlatform      :: *;
import LLC_AXI4_Adapter  :: *;
import MMIO_AXI4_Adapter :: *;

import SoC_Map      :: *;
import AXI4_Types   :: *;
import Fabric_Defs  :: *;


`ifdef INCLUDE_GDB_CONTROL
import DM_CPU_Req_Rsp  :: *;
`endif

`ifdef INCLUDE_TANDEM_VERIF
import TV_Info  :: *;
`endif

`ifdef EXTERNAL_DEBUG_MODULE
`undef INCLUDE_GDB_CONTROL
`endif

// ================================================================

(* synthesize *)
module mkProc (Proc_IFC);

   // ----------------
    // cores
    Vector#(CoreNum, Core) core = ?;
    for(Integer i = 0; i < valueof(CoreNum); i = i+1) begin
        core[i] <- mkCore(fromInteger(i));
    end

   // ----------------
   // Verbosity control for debugging

   // Verbosity: 0=quiet; 1=instruction trace; 2=more detail
   Reg #(Bit #(4))  cfg_verbosity <- mkConfigReg (0);

   // ----------------
   // Reset requests and responses    (TODO: to be implemented)

   FIFOF #(Bit #(0))  f_reset_reqs <- mkFIFOF;
   FIFOF #(Bit #(0))  f_reset_rsps <- mkFIFOF;

   // ----------------
   // Communication to/from External debug module    (TODO: to be implemented)

`ifdef INCLUDE_GDB_CONTROL

   // Debugger run-control
   FIFOF #(Bool)  f_run_halt_reqs <- mkFIFOF;
   FIFOF #(Bool)  f_run_halt_rsps <- mkFIFOF;

   // Stop-request from debugger (e.g., GDB ^C or Dsharp 'stop')
   Reg #(Bool) rg_stop_req <- mkReg (False);

   // Count instrs after step-request from debugger (via dcsr.step)
   Reg #(Bit #(1))  rg_step_count <- mkReg (0);

   // Debugger GPR read/write request/response
   FIFOF #(DM_CPU_Req #(5,  XLEN)) f_gpr_reqs <- mkFIFOF1;
   FIFOF #(DM_CPU_Rsp #(XLEN))     f_gpr_rsps <- mkFIFOF1;

`ifdef ISA_F
   // Debugger FPR read/write request/response
   FIFOF #(DM_CPU_Req #(5,  FLEN)) f_fpr_reqs <- mkFIFOF1;
   FIFOF #(DM_CPU_Rsp #(FLEN))     f_fpr_rsps <- mkFIFOF1;
`endif

   // Debugger CSR read/write request/response
   FIFOF #(DM_CPU_Req #(12, XLEN)) f_csr_reqs <- mkFIFOF1;
   FIFOF #(DM_CPU_Rsp #(XLEN))     f_csr_rsps <- mkFIFOF1;

`endif

   // ----------------
   // Tandem Verification    (TODO: to be implemented)

`ifdef INCLUDE_TANDEM_VERIF
   FIFOF #(Trace_Data) f_trace_data  <- mkFIFOF;
`endif

   // ----------------
   // MMIO

   MMIO_AXI4_Adapter_IFC mmio_axi4_adapter <- mkMMIO_AXI4_Adapter;

   // MMIO platform
   Vector#(CoreNum, MMIOCoreToPlatform) mmioToP;
   for(Integer i = 0; i < valueof(CoreNum); i = i+1) begin
      mmioToP[i] = core[i].mmioToPlatform;
   end
   MMIOPlatform mmioPlatform <- mkMMIOPlatform (mmioToP,
						mmio_axi4_adapter.core_side);

   // last level cache
   LLCache llc <- mkLLCache;

   // connect LLC to L1 caches
   Vector#(L1Num, ChildCacheToParent#(L1Way, void)) l1 = ?;
   for(Integer i = 0; i < valueof(CoreNum); i = i+1) begin
      l1[i] = core[i].dCacheToParent;
      l1[i + valueof(CoreNum)] = core[i].iCacheToParent;
   end
   mkL1LLConnect(llc.to_child, l1);

   // ================================================================
   // LLC's DMA connections

    // Core's tlbToMem
    Vector#(CoreNum, TlbMemClient) tlbToMem = ?;
    for(Integer i = 0; i < valueof(CoreNum); i = i+1) begin
        tlbToMem[i] = core[i].tlbToMem;
    end

   // Stub out memLoader (TODO: can be Debug Module's access)
   let memLoaderStub = interface MemLoaderMemClient;
			  interface memReq = nullFifoDeq;
			  interface respSt = nullFifoEnq;
		       endinterface;

    mkLLCDmaConnect(llc.dma, memLoaderStub, tlbToMem);

   // ================================================================
   // interface LLC to AXI4

   LLC_AXI4_Adapter_IFC  llc_axi4_adapter <- mkLLC_AXi4_Adapter (llc.to_mem);

   // ================================================================
   // Connect stats

   for(Integer i = 0; i < valueof(CoreNum); i = i+1) begin
      rule broadcastStats;
         Bool doStats <- core[i].sendDoStats;
         for(Integer j = 0; j < valueof(CoreNum); j = j+1) begin
	    core[j].recvDoStats(doStats);
         end
         llc.perf.setStatus(doStats);
      endrule
   end

   // ================================================================
   // Stub out deadlock and renameDebug interfaces

   for(Integer j = 0; j < valueof(CoreNum); j = j+1) begin
      rule rl_dummy1;
	 let x <- core[j].deadlock.dCacheCRqStuck.get;
      endrule
      rule rl_dummy2;
	 let x <- core[j].deadlock.dCachePRqStuck.get;
      endrule
      rule rl_dummy3;
	 let x <- core[j].deadlock.iCacheCRqStuck.get;
      endrule
      rule rl_dummy4;
	 let x <- core[j].deadlock.iCachePRqStuck.get;
      endrule
      rule rl_dummy5;
	 let x <- core[j].deadlock.renameInstStuck.get;
      endrule
      rule rl_dummy6;
	 let x <- core[j].deadlock.renameCorrectPathStuck.get;
      endrule
      rule rl_dummy7;
	 let x <- core[j].deadlock.commitInstStuck.get;
      endrule
      rule rl_dummy8;
	 let x <- core[j].deadlock.commitUserInstStuck.get;
      endrule
      rule rl_dummy9;
	 let x <- core[j].deadlock.checkStarted.get;
      endrule

      rule rl_dummy20;
	 let x <- core[j].renameDebug.renameErr.get;
      endrule
   end

   // ================================================================
   // Reset

   rule rl_reset;
      let x <- pop (f_reset_reqs);

      llc_axi4_adapter.reset;
      mmio_axi4_adapter.reset;

      f_reset_rsps.enq (?);
   endrule

   // ----------------
   // Termination detection

   for(Integer i = 0; i < valueof(CoreNum); i = i+1) begin
      rule rl_terminate;
	 let x <- core[i].coreIndInv.terminate;
	 $display ("Core %d terminated", i);
      endrule
   end

   // Print out values written 'tohost'
   rule rl_tohost;
      let x <- mmioPlatform.to_host;
      $display ("mmioPlatform.rl_tohost: 0x%0x (= %0d)", x, x);
      if (x != 0) begin
	 // Standard RISC-V ISA tests finish by writing a value tohost with x[0]==1.
	 // Further when x[63:1]==0, all tests within the program pass,
	 // otherwise x[63:1] = the test within the program that failed.
	 let failed_testnum = (x >> 1);
	 if (failed_testnum == 0)
	    $display ("PASS");
	 else
	    $display ("FAIL %0d", failed_testnum);
	 $finish (0);
      end
   endrule

   // ================================================================
   // ================================================================
   // ================================================================
   // INTERFACE

   // Reset
   interface Server  hart0_server_reset = toGPServer (f_reset_reqs, f_reset_rsps);

   // ----------------
   // Start the cores running
   method Action start (Addr startpc, Addr tohostAddr, Addr fromhostAddr);
      action
	 for(Integer i = 0; i < valueof(CoreNum); i = i+1)
	    core[i].coreReq.start (startpc, tohostAddr, fromhostAddr);
      endaction

      mmioPlatform.start (tohostAddr, fromhostAddr);

      $display ("Proc.start: startpc = 0x%0h, tohostAddr = 0x%0h, fromhostAddr = %0h",
		startpc, tohostAddr, fromhostAddr);
   endmethod

   // ----------------
   // SoC fabric connections

   // Fabric master interface for memory (from LLC)
   interface  master0 = llc_axi4_adapter.mem_master;

   // Fabric master interface for IO (from MMIOPlatform)
   interface  master1 = mmio_axi4_adapter.mmio_master;

   // ----------------
   // External interrupts

   method Action  m_external_interrupt_req (x);
      core[0].setMEIP (pack (x));
   endmethod

   method Action  s_external_interrupt_req (x);
      core[0].setSEIP (pack (x));
   endmethod

   // ----------------
   // External interrupt [14] to go into Debug Mode

   method Action  debug_external_interrupt_req (Bool set_not_clear);
      core[0].setDEIP (pack (set_not_clear));
   endmethod

   // ----------------
   // Non-maskable interrupt

   // TODO: fixup: NMIs should send CPU to an NMI vector (TBD in SoC_Map)
   method Action  non_maskable_interrupt_req (Bool set_not_clear) = noAction;

   // ----------------
   // For tracing

   method Action  set_verbosity (Bit #(4)  verbosity);
      cfg_verbosity <= verbosity;
   endmethod

   // ----------------
   // Optional interface to Tandem Verifier

`ifdef INCLUDE_TANDEM_VERIF
   interface Get  trace_data_out = toGet (f_trace_data);
`endif

`ifdef RVFI_DII
   interface Toooba_RVFI_DII_Server rvfi_dii_server = core[0].rvfi_dii_server;
`endif

   // ----------------
   // Optional interface to Debug Module

`ifdef INCLUDE_GDB_CONTROL
   // run-control, other
   interface Server  hart0_server_run_halt = toGPServer (f_run_halt_reqs, f_run_halt_rsps);

   interface Put  hart0_put_other_req;
      method Action  put (Bit #(4) req);
	 cfg_verbosity <= req;
      endmethod
   endinterface

   // GPR access
   interface Server  hart0_gpr_mem_server = toGPServer (f_gpr_reqs, f_gpr_rsps);

`ifdef ISA_F
   // FPR access
   interface Server  hart0_fpr_mem_server = toGPServer (f_fpr_reqs, f_fpr_rsps);
`endif

   // CSR access
   interface Server  hart0_csr_mem_server = toGPServer (f_csr_reqs, f_csr_rsps);
`endif

endmodule: mkProc

// ================================================================

endpackage
