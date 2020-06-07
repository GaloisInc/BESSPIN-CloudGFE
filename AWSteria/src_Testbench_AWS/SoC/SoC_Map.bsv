// Copyright (c) 2013-2019 Bluespec, Inc. All Rights Reserved

package SoC_Map;

// ================================================================
// This module defines the overall 'address map' of the SoC, showing
// the addresses serviced by each slave IP, and which addresses are
// memory vs. I/O.

// ***** WARNING! WARNING! WARNING! *****

// During system integration, this address map should be identical to
// the system interconnect settings (e.g., routing of requests between
// masters and slaves).  This map is also needed by software so that
// it knows how to address various IPs.

// This module contains no state; it just has constants, and so can be
// freely instantiated at multiple places in the SoC module hierarchy
// at no hardware cost.  It allows this map to be defined in one
// place and shared across the SoC.

// ================================================================
// This version of SoC_Map is for the DARPA SSITH GFE

// Our "Near_Mem_IO" corresponds to "CLINT" in Rocket

// ================================================================
// Exports

export  Num_Masters;
export  imem_master_num;
export  dmem_master_num;
export  accel0_master_num;

export  Num_Slaves;
export  Wd_SId;
export  boot_rom_slave_num;
export  mem0_controller_slave_num;
export  uart16550_0_slave_num;
export  host_access_slave_num;
export  accel0_slave_num;

export  SoC_Map_IFC (..), mkSoC_Map;

export  N_External_Interrupt_Sources;
export  n_external_interrupt_sources;

export irq_num_uart16550_0;
export irq_num_host_to_hw;
export irq_num_accel0;

// ================================================================
// Bluespec library imports

import Routable :: *; // For Range

// ================================================================
// Project imports

import Fabric_Defs :: *;    // Only for type Fabric_Addr

`ifdef ISA_CHERI
import CHERICap     :: *;
import CHERICC_Fat  :: *;
`endif

// ================================================================
// Interface and module for the address map

interface SoC_Map_IFC;
   (* always_ready *)   method  Range #(Wd_Addr)  m_plic_addr_range;
   (* always_ready *)   method  Range #(Wd_Addr)  m_debug_module_addr_range;
   (* always_ready *)   method  Range #(Wd_Addr)  m_near_mem_io_addr_range;
   (* always_ready *)   method  Range #(Wd_Addr)  m_flash_mem_addr_range;
   (* always_ready *)   method  Range #(Wd_Addr)  m_ethernet_0_addr_range;
   (* always_ready *)   method  Range #(Wd_Addr)  m_dma_0_addr_range;
   (* always_ready *)   method  Range #(Wd_Addr)  m_uart16550_0_addr_range;
   (* always_ready *)   method  Range #(Wd_Addr)  m_gpio_0_addr_range;
`ifdef INCLUDE_ACCEL0
   (* always_ready *)   method  Range #(Wd_Addr)  m_accel0_addr_range;
`endif
   (* always_ready *)   method  Range #(Wd_Addr)  m_boot_rom_addr_range;
   (* always_ready *)   method  Range #(Wd_Addr)  m_ddr4_0_uncached_addr_range;
   (* always_ready *)   method  Range #(Wd_Addr)  m_ddr4_0_cached_addr_range;
   (* always_ready *)   method  Range #(Wd_Addr)  m_host_access_addr_range;
   (* always_ready *)   method  Range #(Wd_Addr)  m_mem0_controller_addr_range;

   (* always_ready *)
   method  Bool  m_is_mem_addr (Fabric_Addr addr);

   (* always_ready *)
   method  Bool  m_is_IO_addr (Fabric_Addr addr);

   (* always_ready *)
   method  Bool  m_is_near_mem_IO_addr (Fabric_Addr addr);

   (* always_ready *)   method  Bit #(64)  m_pc_reset_value;
   (* always_ready *)   method  Bit #(64)  m_mtvec_reset_value;
   (* always_ready *)   method  Bit #(64)  m_nmivec_reset_value;

`ifdef ISA_CHERI
   (* always_ready *)   method  CapReg  m_pcc_reset_value;
   (* always_ready *)   method  CapReg  m_ddc_reset_value;
   (* always_ready *)   method  CapReg  m_mtcc_reset_value;
   (* always_ready *)   method  CapReg  m_mepcc_reset_value;
`endif
endinterface

// ================================================================

(* synthesize *)
module mkSoC_Map (SoC_Map_IFC);

   // ----------------------------------------------------------------
   // PLIC

   let plic_addr_range = Range {
      base: 'h_0C00_0000,
      size: 'h_0040_0000    // 4M
   };

   // ----------------------------------------------------------------
   // DEBUG_MODULE

   let debug_module_addr_range = Range {
      base: 'h_1001_0000,
      size: 'h_0001_0000    // 64K
   };

   // ----------------------------------------------------------------
   // Near_Mem_IO (CLINT)

   let near_mem_io_addr_range = Range {
      base: 'h_1000_0000,
      size: 'h_0001_0000    // 64K
   };

   // ----------------------------------------------------------------
   // Flash Mem

   let flash_mem_addr_range = Range {
      base: 'h4000_0000,
      size: 'h0800_0000     // 128M
   };

   // ----------------------------------------------------------------
   // Ethernet 0

   let ethernet_0_addr_range = Range {
      base: 'h6210_0000,
      size: 'h0004_0000     // 256K
   };

   // ----------------------------------------------------------------
   // DMA 0

   let dma_0_addr_range = Range {
      base: 'h6220_0000,
      size: 'h0001_0000     // 64K
   };

   // ----------------------------------------------------------------
   // UART 0

   let uart16550_0_addr_range = Range {
      base: 'h6230_0000,
      size: 'h0000_1000     // 4K
   };

   // ----------------------------------------------------------------
   // AWS host access

   let host_access_addr_range = Range {
      base: 'h6250_0000,
      size: 'h0000_0080     // 128
   };

    // ----------------------------------------------------------------
   // ACCEL 0

`ifdef INCLUDE_ACCEL0
   let accel0_addr_range = Range {
      base: 'h6240_0000,
      size: 'h0000_1000     // 4K
   };
`endif

   // ----------------------------------------------------------------
   // GPIO 0

   let gpio_0_addr_range = Range {
      base: 'h6FFF_0000,
      size: 'h0001_0000     // 64K
   };

   // ----------------------------------------------------------------
   // Boot ROM

   let boot_rom_addr_range = Range {
      base: 'h_7000_0000,
      size: 'h_0000_1000    // 4K
   };

   // ----------------------------------------------------------------
   // DDR memory 0 uncached

   let ddr4_0_uncached_addr_range = Range {
      base: 'h_8000_0000,
      size: 'h_4000_0000    // 1G
   };

   // ----------------------------------------------------------------
   // DDR memory 0 cached

   let ddr4_0_cached_addr_range = Range {
      base: 'h_C000_0000,
      size: 'h_4000_0000    // 1G
   };

   // ----------------------------------------------------------------
   // Main Mem Controller 0

   let mem0_controller_addr_range = Range {
      base: rangeBase(ddr4_0_uncached_addr_range),
      size: rangeTop(ddr4_0_cached_addr_range) - rangeBase(ddr4_0_uncached_addr_range)
   };

   // ----------------------------------------------------------------
   // Memory address predicate
   // Identifies memory addresses in the Fabric.
   // (Caches needs this information to cache these addresses.)

   function Bool fn_is_mem_addr (Fabric_Addr addr);
      return (   inRange (ddr4_0_cached_addr_range, addr)
	      );
   endfunction

   // ----------------------------------------------------------------
   // I/O address predicate
   // Identifies I/O addresses in the Fabric.
   // (Caches needs this information to avoid cacheing these addresses.)

   function Bool fn_is_IO_addr (Fabric_Addr addr);
      return (   inRange (plic_addr_range, addr)
	      || inRange (debug_module_addr_range, addr)
	      || inRange (near_mem_io_addr_range, addr)
	   // || inRange (pcie_ecam_slave_bridge_addr_range, addr)
	      || inRange (flash_mem_addr_range, addr)
	   // || inRange (pcie_block_registers_addr_range, addr)
	      || inRange (ethernet_0_addr_range, addr)
	      || inRange (dma_0_addr_range, addr)
	      || inRange (uart16550_0_addr_range, addr)
`ifdef INCLUDE_ACCEL0
	      || inRange(accel0_addr_range, addr)
`endif
	      || inRange (gpio_0_addr_range, addr)
	      || inRange (boot_rom_addr_range, addr)
	      || inRange (ddr4_0_uncached_addr_range, addr)
	      );
   endfunction

   // ----------------------------------------------------------------
   // PC, MTVEC and NMIVEC reset values

   Bit #(64) pc_reset_value     = rangeBase(boot_rom_addr_range);
   Bit #(64) mtvec_reset_value  = 'h1000;    // TODO
   Bit #(64) nmivec_reset_value = ?;         // TODO

`ifdef ISA_CHERI
   CapPipe almightyPipe = almightyCap;
   CapReg pcc_reset_value  = cast(setOffset(almightyPipe, pc_reset_value).value);
   CapReg ddc_reset_value = almightyCap;
   CapReg mtcc_reset_value = cast(setOffset(almightyPipe, mtvec_reset_value).value);
   CapReg mepcc_reset_value = almightyCap;
`endif

   // ================================================================
   // INTERFACE

   method  Range #(Wd_Addr)  m_plic_addr_range = plic_addr_range;
   method  Range #(Wd_Addr)  m_debug_module_addr_range = debug_module_addr_range;
   method  Range #(Wd_Addr)  m_near_mem_io_addr_range = near_mem_io_addr_range;
   method  Range #(Wd_Addr)  m_flash_mem_addr_range = flash_mem_addr_range;
   method  Range #(Wd_Addr)  m_ethernet_0_addr_range = ethernet_0_addr_range;
   method  Range #(Wd_Addr)  m_dma_0_addr_range = dma_0_addr_range;
   method  Range #(Wd_Addr)  m_uart16550_0_addr_range = uart16550_0_addr_range;
   method  Range #(Wd_Addr)  m_host_access_addr_range = host_access_addr_range;
`ifdef INCLUDE_ACCEL0
   method  Range #(Wd_Addr)  m_accel0_addr_range = accel0_addr_range;
`endif
   method  Range #(Wd_Addr)  m_gpio_0_addr_range = gpio_0_addr_range;
   method  Range #(Wd_Addr)  m_boot_rom_addr_range = boot_rom_addr_range;
   method  Range #(Wd_Addr)  m_ddr4_0_uncached_addr_range = ddr4_0_uncached_addr_range;
   method  Range #(Wd_Addr)  m_ddr4_0_cached_addr_range = ddr4_0_cached_addr_range;
   method  Range #(Wd_Addr)  m_mem0_controller_addr_range = mem0_controller_addr_range;

   method  Bool  m_is_mem_addr (Fabric_Addr addr) = fn_is_mem_addr (addr);

   method  Bool  m_is_IO_addr (Fabric_Addr addr) = fn_is_IO_addr (addr);

   method  Bool  m_is_near_mem_IO_addr (Fabric_Addr addr) = inRange (near_mem_io_addr_range, addr);

   method  Bit #(64)  m_pc_reset_value     = pc_reset_value;
   method  Bit #(64)  m_mtvec_reset_value  = mtvec_reset_value;
   method  Bit #(64)  m_nmivec_reset_value = nmivec_reset_value;

`ifdef ISA_CHERI
   method  CapReg  m_pcc_reset_value   = pcc_reset_value;
   method  CapReg  m_ddc_reset_value   = ddc_reset_value;
   method  CapReg  m_mtcc_reset_value  = mtcc_reset_value;
   method  CapReg  m_mepcc_reset_value = mepcc_reset_value;
`endif
endmodule

// ================================================================
// Count and master-numbers of masters in the fabric.

Integer imem_master_num   = 0;
Integer dmem_master_num   = 1;
Integer accel0_master_num = 2;

`ifdef INCLUDE_ACCEL0
typedef 3 Num_Masters;
`else
typedef 2 Num_Masters;
`endif

// ================================================================
// Count and slave-numbers of slaves in the fabric.

`ifdef INCLUDE_ACCEL0
typedef 5 Num_Slaves;
`else
typedef 4 Num_Slaves;
`endif

Integer boot_rom_slave_num        = 0;
Integer mem0_controller_slave_num = 1;
Integer uart16550_0_slave_num     = 2;
Integer host_access_slave_num     = 3;
Integer accel0_slave_num          = 4;

// ================================================================
// Width of fabric 'id' buses
typedef TAdd#(Wd_MId_ext, TLog#(Num_Masters)) Wd_SId;

// ================================================================
// Interrupt request numbers (== index in to vector of
// interrupt-request lines in Core)

typedef  16  N_External_Interrupt_Sources;
Integer  n_external_interrupt_sources = valueOf (N_External_Interrupt_Sources);

Integer irq_num_uart16550_0 = 0;
Integer irq_num_host_to_hw  = 1;
Integer irq_num_accel0      = 2;

// ================================================================

endpackage
