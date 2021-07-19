// Copyright (c) 2016-2020 Bluespec, Inc. All Rights Reserved.

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

package SoC_Top;

// ================================================================
// This package is the SoC "top-level".

// (Note: there will be further layer(s) above this for
//    simulation top-level, FPGA top-level, etc.)

// ================================================================
// Exports

export SoC_Top_IFC (..), mkSoC_Top;

// ================================================================
// BSV library imports

import FIFOF         :: *;
import GetPut        :: *;
import ClientServer  :: *;
import Connectable   :: *;
import Memory        :: *;
import Clocks        :: *;
import Vector        :: *;

// ----------------
// BSV additional libs

import Cur_Cycle   :: *;
import GetPut_Aux  :: *;
import Routable    :: *;
import AXI4        :: *;

// ================================================================
// Project imports

import Fabric_Defs :: *;
import SoC_Map     :: *;

// SoC components (CPU, mem, and IPs)

import CoreW_IFC        :: *;
import Praesidio_CoreWW :: *;
import PLIC             :: *;    // For interface to PLIC interrupt sources, in CoreW_IFC

import Boot_ROM       :: *;
import Mem_Controller :: *;
import UART_Model     :: *;

`ifdef INCLUDE_CAMERA_MODEL
import Camera_Model   :: *;
`endif

`ifdef INCLUDE_ACCEL0
import AXI4_Accel_IFC :: *;
import AXI4_Accel     :: *;
`endif

`ifdef INCLUDE_TANDEM_VERIF
import TV_Info :: *;
`endif

`ifdef RVFI_DII
import RVFI_DII_Types :: *;
import ProcTypes :: *;
`endif

`ifdef INCLUDE_GDB_CONTROL
import Debug_Module     :: *;
`endif

// ================================================================
// The outermost interface of the SoC

interface SoC_Top_IFC;
   // Set core's verbosity
   method Action  set_verbosity (Bit #(4)  verbosity, Bit #(64)  logdelay);

`ifdef INCLUDE_GDB_CONTROL
   // DMI (Debug Module Interface) facing remote debugger
   interface DMI dmi;

   // Non-Debug-Module Reset (reset all except DM)
   interface Client #(Bool, Bool) ndm_reset_client;
`endif

`ifdef INCLUDE_TANDEM_VERIF
   // To tandem verifier
   interface Get #(Info_CPU_to_Verifier) tv_verifier_info_get;
`elsif RVFI_DII
   interface Toooba_RVFI_DII_Server rvfi_dii_server;
`endif

   // External real memory
   interface MemoryClient #(Bits_per_Raw_Mem_Addr, Bits_per_Raw_Mem_Word)  to_raw_mem;

   // UART0 to external console
   interface Get #(Bit #(8)) get_to_console;
   interface Put #(Bit #(8)) put_from_console;

   // Catch-all status; return-value can identify the origin (0 = none)
   (* always_ready *)
   method Bit #(8) status;

   // Start CPU execution
   // For ISA tests: watch memory writes to <tohost> addr
   method Action start (Fabric_Addr  tohost_addr, Fabric_Addr  fromhost_addr);
endinterface

// ================================================================
// Local types and constants

typedef enum {SOC_START,
              SOC_RESETTING,
              SOC_IDLE} SoC_State
deriving (Bits, Eq, FShow);

// ================================================================
// The module

(* synthesize *)
module mkSoC_Top #(Reset dm_power_on_reset)
                 (SoC_Top_IFC);
   Integer verbosity = 2;    // Normally 0; non-zero for debugging

   Reg #(SoC_State) rg_state <- mkReg (SOC_START);

   // SoC address map specifying base and limit for memories, IPs, etc.
   SoC_Map_IFC soc_map <- mkSoC_Map;

   // Core: CPU + Near_Mem_IO (CLINT) + PLIC + Debug module (optional) + TV (optional)
   // The Debug Module has its own RST_N reset signal (which comes
   // from outside this module as a paramter)
   Praesidio_CoreWW #(N_External_Interrupt_Sources)  corew <- mkPraesidioCoreWW (dm_power_on_reset, soc_map);

   // SoC Boot ROM
   Boot_ROM_IFC  boot_rom <- mkBoot_ROM(False);
   // AXI4 Deburster in front of Boot_ROM
   AXI4_ManagerSubordinate_Shim#(Wd_SId, Wd_Addr, Wd_Data, 0, 0, 0, 0, 0)
      boot_rom_axi4_deburster <- mkBurstToNoBurst_ManagerSubordinate;

   // SoC Memory
   Mem_Controller_IFC  mem0_controller <- mkMem_Controller;
   // AXI4 Deburster in front of SoC Memory
   AXI4_ManagerSubordinate_Shim#(Wd_SId, Wd_Addr, Wd_Data, 0, 0, 0, 0, 0)
      mem0_controller_axi4_deburster <- mkBurstToNoBurst_ManagerSubordinate;

   // SoC IPs
   UART_IFC   uart0  <- mkUART;

`ifdef INCLUDE_ACCEL0
   // Accel0 manager to fabric
   AXI4_Accel_IFC  accel0 <- mkAXI4_Accel;
`endif

   // ----------------
   // SoC fabric manager connections
   // Note: see 'SoC_Map' for definitions

   Vector#(2, AXI4_Manager #(TAdd#(Wd_MId,2), Wd_Addr, Wd_Data,
                                      0, 0, 0, 0, 0))
      manager_vector = newVector;

   // CPU mem interface to fabric
   manager_vector[imem_manager_num] = corew.insecure_mem_manager;
   manager_vector[dmem_manager_num] = corew.secure_mem_manager;

   // ----------------
   // SoC fabric subordinate connections
   // Note: see 'SoC_Map' for 'subordinate_num' definitions

   Vector#(Num_Subordinates, AXI4_Subordinate #(Wd_SId, Wd_Addr, Wd_Data,
                                    0, 0, 0, 0, 0))
      subordinate_vector = newVector;
   Vector#(Num_Subordinates, Range#(Wd_Addr)) route_vector = newVector;

   // Fabric to Boot ROM
   mkConnection(boot_rom_axi4_deburster.manager, boot_rom.slave);
   subordinate_vector[boot_rom_subordinate_num] = boot_rom_axi4_deburster.subordinate;
   route_vector[boot_rom_subordinate_num] = soc_map.m_boot_rom_addr_range;

   // Fabric to Mem Controller
   mkConnection(mem0_controller_axi4_deburster.manager, mem0_controller.slave);
   subordinate_vector[mem0_controller_subordinate_num] = mem0_controller_axi4_deburster.subordinate;
   route_vector[mem0_controller_subordinate_num] = soc_map.m_mem0_controller_addr_range;

   // Fabric to UART0
   subordinate_vector[uart0_subordinate_num] = zeroSubordinateUserFields(uart0.slave);
   route_vector[uart0_subordinate_num] = soc_map.m_uart0_addr_range;

`ifdef INCLUDE_ACCEL0
   // Fabric to accel0
   subordinate_vector[accel0_subordinate_num] = zeroSubordinateUserFields (accel0.slave);
   route_vector[accel0_subordinate_num] = soc_map.m_accel0_addr_range;
`endif

`ifdef HTIF_MEMORY
   AXI4_Subordinate_IFC#(Wd_Id, Wd_Addr, Wd_Data, Wd_User) htif <- mkAxi4LRegFile(bytes_per_htif);

   subordinate_vector[htif_subordinate_num] = htif;
   route_vector[htif_subordinate_num] = soc_map.m_htif_addr_range;
`endif

   function my_route (addr);
      let route = routeFromMappingTable(route_vector)(addr);
      let alt_route = replicate(False);
      alt_route[mem0_controller_subordinate_num] = True;
      if (inRange (soc_map.m_ddr4_0_uncached_addr_range, addr)) begin
        return alt_route;
      end else begin
        return route;
      end
   endfunction

   // SoC Fabric
   let bus <- mkAXI4Bus (my_route, manager_vector, subordinate_vector);

   // ----------------
   // Connect interrupt sources for CPU external interrupt request inputs.

   (* fire_when_enabled, no_implicit_conditions *)
   rule rl_connect_external_interrupt_requests;
      Bool intr = uart0.intr;

      // UART
      corew.core_external_interrupt_sources [irq_num_uart0].m_interrupt_req (intr);
      Integer last_irq_num = irq_num_uart0;

`ifdef INCLUDE_ACCEL0
      Bool intr_accel0 = accel0.interrupt_req;
      corew.core_external_interrupt_sources [irq_num_accel0].m_interrupt_req (intr_accel0);
      last_irq_num = irq_num_accel0;
`endif

      // Tie off remaining interrupt request lines (1..N)
      for (Integer j = last_irq_num + 1; j < valueOf (N_External_Interrupt_Sources); j = j + 1)
         corew.core_external_interrupt_sources [j].m_interrupt_req (False);

      // Non-maskable interrupt request. [Tie-off; TODO: connect to genuine sources]
      corew.nmi_req (False);
   endrule

   // ================================================================
   // MODULE INITIALIZATIONS

   function Action fa_reset_start_actions;
      action
         mem0_controller.server_reset.request.put (?);
         uart0.server_reset.request.put (?);
      endaction
   endfunction

   function Action fa_reset_complete_actions;
      action
         let mem0_controller_rsp <- mem0_controller.server_reset.response.get;
         let uart0_rsp           <- uart0.server_reset.response.get;
         // Initialize address maps of subordinate IPs
         boot_rom.set_addr_map (rangeBase(soc_map.m_boot_rom_addr_range),
                                rangeTop(soc_map.m_boot_rom_addr_range));

         mem0_controller.set_addr_map (rangeBase(soc_map.m_mem0_controller_addr_range),
                                       rangeTop(soc_map.m_mem0_controller_addr_range),
                                       rangeBase(soc_map.m_ddr4_0_uncached_addr_range),
                                       rangeTop(soc_map.m_ddr4_0_uncached_addr_range));

         uart0.set_addr_map (rangeBase(soc_map.m_uart0_addr_range),
                             rangeTop(soc_map.m_uart0_addr_range));

`ifdef INCLUDE_ACCEL0
         accel0.init (fabric_default_id,
                      soc_map.m_accel0_addr_range.base,
                      rangeTop(soc_map.m_accel0_addr_range));
`endif

         if (verbosity != 0) begin
            $display ("  SoC address map:");
            $display ("  Boot ROM:        0x%0h .. 0x%0h",
                      rangeBase(soc_map.m_boot_rom_addr_range),
                      rangeTop(soc_map.m_boot_rom_addr_range));
            $display ("  Mem0 Controller: 0x%0h .. 0x%0h",
                      rangeBase(soc_map.m_mem0_controller_addr_range),
                      rangeTop(soc_map.m_mem0_controller_addr_range));
            $display ("  UART0:           0x%0h .. 0x%0h",
                      rangeBase(soc_map.m_uart0_addr_range),
                      rangeTop(soc_map.m_uart0_addr_range));
         end
      endaction
   endfunction

   // ----------------
   // Initial reset

   rule rl_reset_start_initial (rg_state == SOC_START);
      fa_reset_start_actions;
      rg_state <= SOC_RESETTING;

      $display ("%0d: %m.rl_reset_start_initial ...", cur_cycle);
   endrule

   rule rl_reset_complete_initial (rg_state == SOC_RESETTING);
      fa_reset_complete_actions;
      rg_state <= SOC_IDLE;

      $display ("%0d: %m.rl_reset_complete_initial", cur_cycle);
   endrule

   // ================================================================
   // INTERFACE

   method Action  set_verbosity (Bit #(4)  new_verbosity, Bit #(64)  logdelay);
      corew.set_verbosity (new_verbosity, logdelay);
   endmethod

   // To external controller (E.g., GDB)
`ifdef INCLUDE_GDB_CONTROL
   // DMI (Debug Module Interface) facing remote debugger
   interface DMI dmi = corew.dmi;

   // Non-Debug-Module Reset (reset all except DM)
   interface Client ndm_reset_client = corew.ndm_reset_client;
`endif

`ifdef INCLUDE_TANDEM_VERIF
   // To tandem verifier
   interface tv_verifier_info_get = corew.tv_verifier_info_get;
`elsif RVFI_DII
   interface rvfi_dii_server = corew.rvfi_dii_server;
`endif

   // External real memory
   interface to_raw_mem = mem0_controller.to_raw_mem;

   // UART to external console
   interface get_to_console   = uart0.get_to_console;
   interface put_from_console = uart0.put_from_console;

   // Catch-all status; return-value can identify the origin (0 = none)
   method Bit #(8) status;
      return mem0_controller.status;
   endmethod

   // Start CPU execution
   // For ISA tests: watch memory writes to <tohost> addr
   method Action start (Fabric_Addr  tohost_addr, Fabric_Addr  fromhost_addr);
      Bool watch_tohost = (tohost_addr != 0);
      mem0_controller.set_watch_tohost (watch_tohost, tohost_addr);
      Bool is_running = True;
      corew.start (is_running, tohost_addr, fromhost_addr);
      $display ("%0d: %m.method start (tohost %0h, fromhost %0h)",
                cur_cycle, tohost_addr, fromhost_addr);
   endmethod
endmodule: mkSoC_Top

// ================================================================

endpackage
