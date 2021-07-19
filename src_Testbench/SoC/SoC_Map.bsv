// Copyright (c) 2013-2019 Bluespec, Inc. All Rights Reserved
//
//-
// RVFI_DII + CHERI modifications:
//     Copyright (c) 2020 Alexandre Joannou
//     Copyright (c) 2020 Peter Rugg
//     Copyright (c) 2020 Jonathan Woodruff
//     All rights reserved.
//
//     This software was developed by SRI International and the University of
//     Cambridge Computer Laboratory (Department of Computer Science and
//     Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
//     DARPA SSITH research programme.
//
//     This work was supported by NCSC programme grant 4212611/RFA 15971 ("SafeBet").
//-

package SoC_Map;

// ================================================================
// This module defines the overall 'address map' of the SoC, showing
// the addresses serviced by each subordinate IP, and which addresses are
// memory vs. I/O.

// ***** WARNING! WARNING! WARNING! *****

// During system integration, this address map should be identical to
// the system interconnect settings (e.g., routing of requests between
// managers and subordinates).  This map is also needed by software so that
// it knows how to address various IPs.

// This module contains no state; it just has constants, and so can be
// freely instantiated at multiple places in the SoC module hierarchy
// at no hardware cost.  It allows this map to be defined in one
// place and shared across the SoC.

// ================================================================
// Exports

export  SoC_Map_Struct (..), soc_map_struct;

export  SoC_Map_IFC (..), mkSoC_Map;

export  Num_Managers;
export  imem_manager_num;
export  dmem_manager_num;

export  Num_Subordinates;
export  Wd_SId;
export  boot_rom_subordinate_num;
export  mem0_controller_subordinate_num;
export  uart0_subordinate_num;
export  praesidio_subordinate_num;

export  N_External_Interrupt_Sources;
export  n_external_interrupt_sources;
export  irq_num_uart0;

// ================================================================
// Bluespec library imports

import Routable :: *; // For Range

// ================================================================
// Project imports

import Fabric_Defs :: *;    // Only for type Fabric_Addr

// ================================================================
// Top-level-struct version of the SoC Map for RISCY-OOO

typedef struct {
   Bit #(64)  near_mem_io_addr_base;

   Bit #(64)  main_mem_addr_base;
   Bit #(64)  main_mem_addr_size;

   Bit #(64)  pc_reset_value;
   } SoC_Map_Struct
deriving (FShow);

SoC_Map_Struct soc_map_struct =
SoC_Map_Struct {
   near_mem_io_addr_base: 'h_0200_0000,
   main_mem_addr_base:    'h_8000_0000,
`ifdef RVFI_DII
   main_mem_addr_size:    'h_4000_0000,
   pc_reset_value:        'h_8000_0000
`else
   main_mem_addr_size:    'h_1000_0000,
   pc_reset_value:        'h_0000_1000
`endif
   };

// ================================================================
// Interface and module for the address map

interface SoC_Map_IFC;
   (* always_ready *)   method  Range#(Wd_Addr)  m_near_mem_io_addr_range;
   (* always_ready *)   method  Range#(Wd_Addr)  m_praesidio_conf_addr_range;
   (* always_ready *)   method  Range#(Wd_Addr)  m_plic_addr_range;
   (* always_ready *)   method  Range#(Wd_Addr)  m_uart0_addr_range;
   (* always_ready *)   method  Range#(Wd_Addr)  m_boot_rom_addr_range;
   (* always_ready *)   method  Range#(Wd_Addr)  m_ddr4_0_uncached_addr_range;
   (* always_ready *)   method  Range#(Wd_Addr)  m_mem0_controller_addr_range;
   (* always_ready *)   method  Range#(Wd_Addr)  m_tcm_addr_range;

   (* always_ready *)
   method  Bool  m_is_mem_addr (Fabric_Addr addr);

   (* always_ready *)
   method  Bool  m_is_IO_addr (Fabric_Addr addr, Bool imem_not_dmem);

   (* always_ready *)
   method  Bool  m_is_near_mem_IO_addr (Fabric_Addr addr);

   (* always_ready *)   method  Bit #(64)  m_pc_reset_value;
   (* always_ready *)   method  Bit #(64)  m_mtvec_reset_value;
   (* always_ready *)   method  Bit #(64)  m_nmivec_reset_value;
endinterface

// ================================================================

(* synthesize *)
module mkSoC_Map (SoC_Map_IFC);

   // ----------------------------------------------------------------
   // Near_Mem_IO (including CLINT, the core-local interruptor)

   let near_mem_io_addr_range = Range {
      base: 'h_0200_0000,
      size: 'h_0000_C000    // 48K
   };

   // ----------------------------------------------------------------
   // Praesidio configuration address range
   let praesidio_conf_addr_range = Range {
      base: 'h_0300_0000,
      size: 'h_0000_1000
   };

   // ----------------------------------------------------------------
   // PLIC

   let plic_addr_range = Range {
      base: 'h0C00_0000,
      size: 'h0040_0000     // 4M
   };

   // ----------------------------------------------------------------
   // UART 0

   let uart0_addr_range = Range {
      base: 'hC000_0000,
      size: 'h0000_0080     // 128
   };

   // ----------------------------------------------------------------
   // Boot ROM

   let boot_rom_addr_range = Range {
      base: 'h_0000_1000,
      size: 'h_0000_1000    // 4K
   };

   // ----------------------------------------------------------------
   // Uncached DDR4 access

   let ddr4_0_uncached_addr_range = Range {
      base: 'h_D000_0000,
      size: 'h_4000_0000    // 1 GB
   };

   // ----------------------------------------------------------------
   // Main Mem Controller 0

   let mem0_controller_addr_range = Range {
      base: 'h_8000_0000,
      size: 'h_4000_0000    // 1 GB
   };

   // ----------------------------------------------------------------
   // Tightly-coupled memory ('TCM'; optional)

`ifdef Near_Mem_TCM
// Integer kB_per_TCM = 'h4;         // 4KB
// Integer kB_per_TCM = 'h40;     // 64KB
// Integer kB_per_TCM = 'h80;     // 128KB
// Integer kB_per_TCM = 'h400;    // 1 MB
   Integer kB_per_TCM = 'h4000;    // 16 MB
`else
   Integer kB_per_TCM = 0;
`endif
   Integer bytes_per_TCM = kB_per_TCM * 'h400;

   let tcm_addr_range = Range {
      base: 'h_0000_0000,
      size: fromInteger (bytes_per_TCM)
   };


   // ----------------------------------------------------------------
   // Memory address predicate
   // Identifies memory addresses in the Fabric.
   // (Caches need this information to cache these addresses.)

   function Bool fn_is_mem_addr (Fabric_Addr addr);
     return (  inRange(mem0_controller_addr_range, addr)
	          || inRange(tcm_addr_range, addr));
   endfunction

   // ----------------------------------------------------------------
   // I/O address predicate
   // Identifies I/O addresses in the Fabric.
   // (Caches need this information to avoid cacheing these addresses.)

   function Bool fn_is_IO_addr (Fabric_Addr addr, Bool imem_not_dmem);
      return (   inRange(boot_rom_addr_range, addr)
	      || (   (! imem_not_dmem)
		  && (   inRange(near_mem_io_addr_range, addr)
		      || inRange(plic_addr_range, addr)
		      || inRange(uart0_addr_range, addr)
          || inRange(praesidio_conf_addr_range, addr)
          || inRange(ddr4_0_uncached_addr_range, addr)
		      )
		  )
	      );
   endfunction

   // ----------------------------------------------------------------
   // PC, MTVEC and NMIVEC reset values

   Bit #(64) pc_reset_value     = rangeBase(boot_rom_addr_range);
   Bit #(64) mtvec_reset_value  = 'h1000;    // TODO
   Bit #(64) nmivec_reset_value = ?;         // TODO

   // ================================================================
   // INTERFACE

   method  Range#(Wd_Addr)  m_near_mem_io_addr_range = near_mem_io_addr_range;
   method  Range#(Wd_Addr)  m_praesidio_conf_addr_range = praesidio_conf_addr_range;
   method  Range#(Wd_Addr)  m_plic_addr_range = plic_addr_range;
   method  Range#(Wd_Addr)  m_uart0_addr_range = uart0_addr_range;
   method  Range#(Wd_Addr)  m_boot_rom_addr_range = boot_rom_addr_range;

   method  Range#(Wd_Addr)  m_ddr4_0_uncached_addr_range = ddr4_0_uncached_addr_range;
   method  Range#(Wd_Addr)  m_mem0_controller_addr_range = mem0_controller_addr_range;

   method  Range#(Wd_Addr)  m_tcm_addr_range = tcm_addr_range;

   method  Bool  m_is_mem_addr (Fabric_Addr addr) = fn_is_mem_addr (addr);

   method  Bool  m_is_IO_addr (Fabric_Addr addr, Bool imem_not_dmem) = fn_is_IO_addr (addr, imem_not_dmem);

   method  Bool  m_is_near_mem_IO_addr (Fabric_Addr addr) = inRange (near_mem_io_addr_range, addr);

   method  Bit #(64)  m_pc_reset_value     = pc_reset_value;
   method  Bit #(64)  m_mtvec_reset_value  = mtvec_reset_value;
   method  Bit #(64)  m_nmivec_reset_value = nmivec_reset_value;
endmodule

// ================================================================
// Count and manager-numbers of managers in the fabric.

typedef 2 Num_Managers;

Integer imem_manager_num = 0;
Integer dmem_manager_num = 1;

// ================================================================
// Count and subordinate-numbers of subordinates in the fabric.

typedef 4 Num_Subordinates;

Integer boot_rom_subordinate_num        = 0;
Integer mem0_controller_subordinate_num = 1;
Integer uart0_subordinate_num           = 2;
Integer praesidio_subordinate_num       = 3;

// ================================================================
// Width of fabric 'id' buses
typedef TAdd#(TAdd#(Wd_MId, TLog#(Num_Managers)),2) Wd_SId;

// ================================================================
// Interrupt request numbers (== index in to vector of
// interrupt-request lines in Core)

typedef  16  N_External_Interrupt_Sources;
Integer  n_external_interrupt_sources = valueOf (N_External_Interrupt_Sources);

Integer irq_num_uart0 = 0;

// ================================================================

endpackage
