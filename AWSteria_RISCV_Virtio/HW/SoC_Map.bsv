// Copyright (c) 2013-2021 Bluespec, Inc. All Rights Reserved

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

export  SoC_Map_Struct (..), soc_map_struct;

export  SoC_Map_IFC (..), mkSoC_Map;

// ================================================================
// Bluespec library imports

// None

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
   near_mem_io_addr_base: 'h_1000_0000,

   main_mem_addr_base:    'h_C000_0000,
   main_mem_addr_size:    'h_4000_0000,

   pc_reset_value:        'h_7000_0000
   };

// ================================================================
// Interface and module for the address map

interface SoC_Map_IFC;
   (* always_ready *)   method  Fabric_Addr  m_plic_addr_base;
   (* always_ready *)   method  Fabric_Addr  m_plic_addr_size;
   (* always_ready *)   method  Fabric_Addr  m_plic_addr_lim;

   (* always_ready *)   method  Fabric_Addr  m_debug_module_addr_base;
   (* always_ready *)   method  Fabric_Addr  m_debug_module_addr_size;
   (* always_ready *)   method  Fabric_Addr  m_debug_module_addr_lim;

   (* always_ready *)   method  Fabric_Addr  m_near_mem_io_addr_base;
   (* always_ready *)   method  Fabric_Addr  m_near_mem_io_addr_size;
   (* always_ready *)   method  Fabric_Addr  m_near_mem_io_addr_lim;

   (* always_ready *)   method  Fabric_Addr  m_flash_mem_addr_base;
   (* always_ready *)   method  Fabric_Addr  m_flash_mem_addr_size;
   (* always_ready *)   method  Fabric_Addr  m_flash_mem_addr_lim;

   (* always_ready *)   method  Fabric_Addr  m_ethernet_0_addr_base;
   (* always_ready *)   method  Fabric_Addr  m_ethernet_0_addr_size;
   (* always_ready *)   method  Fabric_Addr  m_ethernet_0_addr_lim;

   (* always_ready *)   method  Fabric_Addr  m_dma_0_addr_base;
   (* always_ready *)   method  Fabric_Addr  m_dma_0_addr_size;
   (* always_ready *)   method  Fabric_Addr  m_dma_0_addr_lim;

   (* always_ready *)   method  Fabric_Addr  m_uart16550_0_addr_base;
   (* always_ready *)   method  Fabric_Addr  m_uart16550_0_addr_size;
   (* always_ready *)   method  Fabric_Addr  m_uart16550_0_addr_lim;

   (* always_ready *)   method  Fabric_Addr  m_gpio_0_addr_base;
   (* always_ready *)   method  Fabric_Addr  m_gpio_0_addr_size;
   (* always_ready *)   method  Fabric_Addr  m_gpio_0_addr_lim;

   (* always_ready *)   method  Fabric_Addr  m_boot_rom_addr_base;
   (* always_ready *)   method  Fabric_Addr  m_boot_rom_addr_size;
   (* always_ready *)   method  Fabric_Addr  m_boot_rom_addr_lim;

   (* always_ready *)   method  Fabric_Addr  m_ddr4_0_uncached_addr_base;
   (* always_ready *)   method  Fabric_Addr  m_ddr4_0_uncached_addr_size;
   (* always_ready *)   method  Fabric_Addr  m_ddr4_0_uncached_addr_lim;

   (* always_ready *)   method  Fabric_Addr  m_ddr4_0_cached_addr_base;
   (* always_ready *)   method  Fabric_Addr  m_ddr4_0_cached_addr_size;
   (* always_ready *)   method  Fabric_Addr  m_ddr4_0_cached_addr_lim;

   (* always_ready *)   method  Fabric_Addr  m_host_access_addr_base;
   (* always_ready *)   method  Fabric_Addr  m_host_access_addr_size;
   (* always_ready *)   method  Fabric_Addr  m_host_access_addr_lim;

   (* always_ready *)
   method  Bool  m_is_mem_addr (Fabric_Addr addr);

   (* always_ready *)
   method  Bool  m_is_IO_addr (Fabric_Addr addr);

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
   // PLIC

   Fabric_Addr plic_addr_base = 'h_0C00_0000;
   Fabric_Addr plic_addr_size = 'h_0040_0000;    // 4M
   Fabric_Addr plic_addr_lim  = plic_addr_base + plic_addr_size;

   function Bool fn_is_plic_addr (Fabric_Addr addr);
      return ((plic_addr_base <= addr) && (addr < plic_addr_lim));
   endfunction

   // ----------------------------------------------------------------
   // DEBUG_MODULE

   Fabric_Addr debug_module_addr_base = 'h_1001_0000;
   Fabric_Addr debug_module_addr_size = 'h_0001_0000;    // 64K
   Fabric_Addr debug_module_addr_lim  = debug_module_addr_base + debug_module_addr_size;

   function Bool fn_is_debug_module_addr (Fabric_Addr addr);
      return ((debug_module_addr_base <= addr) && (addr < debug_module_addr_lim));
   endfunction

   // ----------------------------------------------------------------
   // Near_Mem_IO (CLINT)

   Fabric_Addr near_mem_io_addr_base = 'h_1000_0000;
   Fabric_Addr near_mem_io_addr_size = 'h_0001_0000;    // 64K
   Fabric_Addr near_mem_io_addr_lim  = near_mem_io_addr_base + near_mem_io_addr_size;

   function Bool fn_is_near_mem_io_addr (Fabric_Addr addr);
      return ((near_mem_io_addr_base <= addr) && (addr < near_mem_io_addr_lim));
   endfunction

   // ----------------------------------------------------------------
   // AWS host access

   Fabric_Addr host_access_addr_base = 'h4000_0000;
   Fabric_Addr host_access_addr_size = 'h0000_4000;    // 16K
   Fabric_Addr host_access_addr_lim  = host_access_addr_base + host_access_addr_size;

   function Bool fn_is_host_access_addr (Fabric_Addr addr);
      return ((host_access_addr_base <= addr) && (addr < host_access_addr_lim));
   endfunction

   // ----------------------------------------------------------------
   // Flash Mem

   Fabric_Addr flash_mem_addr_base = 'h_5000_0000;    // GFE was 4000_0000; TODO: FIXME
   Fabric_Addr flash_mem_addr_size = 'h_0800_0000;    // 128M
   Fabric_Addr flash_mem_addr_lim  = flash_mem_addr_base + flash_mem_addr_size;

   function Bool fn_is_flash_mem_addr (Fabric_Addr addr);
      return ((flash_mem_addr_base <= addr) && (addr < flash_mem_addr_lim));
   endfunction

   // ----------------------------------------------------------------
   // Ethernet 0

   Fabric_Addr ethernet_0_addr_base = 'h_6210_0000;
   Fabric_Addr ethernet_0_addr_size = 'h_0004_0000;    // 256K
   Fabric_Addr ethernet_0_addr_lim  = ethernet_0_addr_base + ethernet_0_addr_size;

   function Bool fn_is_ethernet_0_addr (Fabric_Addr addr);
      return ((ethernet_0_addr_base <= addr) && (addr < ethernet_0_addr_lim));
   endfunction

   // ----------------------------------------------------------------
   // DMA 0

   Fabric_Addr dma_0_addr_base = 'h_6220_0000;
   Fabric_Addr dma_0_addr_size = 'h_0001_0000;    // 64K
   Fabric_Addr dma_0_addr_lim  = dma_0_addr_base + dma_0_addr_size;

   function Bool fn_is_dma_0_addr (Fabric_Addr addr);
      return ((dma_0_addr_base <= addr) && (addr < dma_0_addr_lim));
   endfunction

   // ----------------------------------------------------------------
   // UART 0

   Fabric_Addr uart16550_0_addr_base = 'h_6230_0000;
   Fabric_Addr uart16550_0_addr_size = 'h_0000_1000;    // 4K
   Fabric_Addr uart16550_0_addr_lim  = uart16550_0_addr_base + uart16550_0_addr_size;

   function Bool fn_is_uart16550_0_addr (Fabric_Addr addr);
      return ((uart16550_0_addr_base <= addr) && (addr < uart16550_0_addr_lim));
   endfunction

   // ----------------------------------------------------------------
   // GPIO 0

   Fabric_Addr gpio_0_addr_base = 'h_6FFF_0000;
   Fabric_Addr gpio_0_addr_size = 'h_0001_0000;    // 64K
   Fabric_Addr gpio_0_addr_lim  = gpio_0_addr_base + gpio_0_addr_size;

   function Bool fn_is_gpio_0_addr (Fabric_Addr addr);
      return ((gpio_0_addr_base <= addr) && (addr < gpio_0_addr_lim));
   endfunction

   // ----------------------------------------------------------------
   // Boot ROM

   Fabric_Addr boot_rom_addr_base = 'h_7000_0000;
   Fabric_Addr boot_rom_addr_size = 'h_0000_1000;    // 4K
   Fabric_Addr boot_rom_addr_lim  = boot_rom_addr_base + boot_rom_addr_size;

   function Bool fn_is_boot_rom_addr (Fabric_Addr addr);
      return ((boot_rom_addr_base <= addr) && (addr < boot_rom_addr_lim));
   endfunction

   // ----------------------------------------------------------------
   // DDR memory 0 uncached

   Fabric_Addr ddr4_0_uncached_addr_base = 'h_8000_0000;
   Fabric_Addr ddr4_0_uncached_addr_size = 'h_4000_0000;    // 1G
   Fabric_Addr ddr4_0_uncached_addr_lim  = ddr4_0_uncached_addr_base + ddr4_0_uncached_addr_size;

   function Bool fn_is_ddr4_0_uncached_addr (Fabric_Addr addr);
      return ((ddr4_0_uncached_addr_base <= addr) && (addr < ddr4_0_uncached_addr_lim));
   endfunction

   // ----------------------------------------------------------------
   // DDR memory 0 cached

   Fabric_Addr ddr4_0_cached_addr_base = 'h_C000_0000;
   Fabric_Addr ddr4_0_cached_addr_size = 'h_4000_0000;    // 1G
   Fabric_Addr ddr4_0_cached_addr_lim  = ddr4_0_cached_addr_base + ddr4_0_cached_addr_size;

   function Bool fn_is_ddr4_0_cached_addr (Fabric_Addr addr);
      return ((ddr4_0_cached_addr_base <= addr) && (addr < ddr4_0_cached_addr_lim));
   endfunction

   // ----------------------------------------------------------------
   // Memory address predicate
   // Identifies memory addresses in the Fabric.
   // (Caches needs this information to cache these addresses.)

   function Bool fn_is_mem_addr (Fabric_Addr addr);
      return (   fn_is_ddr4_0_cached_addr (addr)
	      );
   endfunction

   // ----------------------------------------------------------------
   // I/O address predicate
   // Identifies I/O addresses in the Fabric.
   // (Caches needs this information to avoid cacheing these addresses.)

   function Bool fn_is_IO_addr (Fabric_Addr addr);
      return (   fn_is_plic_addr (addr)
	      || fn_is_debug_module_addr (addr)
	      || fn_is_near_mem_io_addr (addr)
	      || fn_is_host_access_addr (addr)
	   // || fn_is_pcie_ecam_slave_bridge_addr (addr)
	      || fn_is_flash_mem_addr (addr)
	   // || fn_is_pcie_block_registers_addr (addr)
	      || fn_is_ethernet_0_addr (addr)
	      || fn_is_dma_0_addr (addr)
	      || fn_is_uart16550_0_addr  (addr)
	      || fn_is_gpio_0_addr (addr)
	      || fn_is_boot_rom_addr (addr)
	      || fn_is_ddr4_0_uncached_addr (addr)
	      );
   endfunction

   // ----------------------------------------------------------------
   // PC, MTVEC and NMIVEC reset values

   Bit #(64) pc_reset_value     = boot_rom_addr_base;
   Bit #(64) mtvec_reset_value  = 'h1000;    // TODO
   Bit #(64) nmivec_reset_value = ?;         // TODO

   // ================================================================
   // INTERFACE

   method  Fabric_Addr  m_plic_addr_base = plic_addr_base;
   method  Fabric_Addr  m_plic_addr_size = plic_addr_size;
   method  Fabric_Addr  m_plic_addr_lim  = plic_addr_lim;

   method  Fabric_Addr  m_debug_module_addr_base = debug_module_addr_base;
   method  Fabric_Addr  m_debug_module_addr_size = debug_module_addr_size;
   method  Fabric_Addr  m_debug_module_addr_lim  = debug_module_addr_lim;

   method  Fabric_Addr  m_near_mem_io_addr_base = near_mem_io_addr_base;
   method  Fabric_Addr  m_near_mem_io_addr_size = near_mem_io_addr_size;
   method  Fabric_Addr  m_near_mem_io_addr_lim  = near_mem_io_addr_lim;

   method  Fabric_Addr  m_flash_mem_addr_base = flash_mem_addr_base;
   method  Fabric_Addr  m_flash_mem_addr_size = flash_mem_addr_size;
   method  Fabric_Addr  m_flash_mem_addr_lim  = flash_mem_addr_lim;

   method  Fabric_Addr  m_ethernet_0_addr_base = ethernet_0_addr_base;
   method  Fabric_Addr  m_ethernet_0_addr_size = ethernet_0_addr_size;
   method  Fabric_Addr  m_ethernet_0_addr_lim  = ethernet_0_addr_lim;

   method  Fabric_Addr  m_dma_0_addr_base = dma_0_addr_base;
   method  Fabric_Addr  m_dma_0_addr_size = dma_0_addr_size;
   method  Fabric_Addr  m_dma_0_addr_lim  = dma_0_addr_lim;

   method  Fabric_Addr  m_uart16550_0_addr_base = uart16550_0_addr_base;
   method  Fabric_Addr  m_uart16550_0_addr_size = uart16550_0_addr_size;
   method  Fabric_Addr  m_uart16550_0_addr_lim  = uart16550_0_addr_lim;

   method  Fabric_Addr  m_host_access_addr_base = host_access_addr_base;
   method  Fabric_Addr  m_host_access_addr_size = host_access_addr_size;
   method  Fabric_Addr  m_host_access_addr_lim  = host_access_addr_lim;

   method  Fabric_Addr  m_gpio_0_addr_base = gpio_0_addr_base;
   method  Fabric_Addr  m_gpio_0_addr_size = gpio_0_addr_size;
   method  Fabric_Addr  m_gpio_0_addr_lim  = gpio_0_addr_lim;

   method  Fabric_Addr  m_boot_rom_addr_base = boot_rom_addr_base;
   method  Fabric_Addr  m_boot_rom_addr_size = boot_rom_addr_size;
   method  Fabric_Addr  m_boot_rom_addr_lim  = boot_rom_addr_lim;

   method  Fabric_Addr  m_ddr4_0_uncached_addr_base = ddr4_0_uncached_addr_base;
   method  Fabric_Addr  m_ddr4_0_uncached_addr_size = ddr4_0_uncached_addr_size;
   method  Fabric_Addr  m_ddr4_0_uncached_addr_lim  = ddr4_0_uncached_addr_lim;

   method  Fabric_Addr  m_ddr4_0_cached_addr_base = ddr4_0_cached_addr_base;
   method  Fabric_Addr  m_ddr4_0_cached_addr_size = ddr4_0_cached_addr_size;
   method  Fabric_Addr  m_ddr4_0_cached_addr_lim  = ddr4_0_cached_addr_lim;

   method  Bool  m_is_mem_addr (Fabric_Addr addr) = fn_is_mem_addr (addr);

   method  Bool  m_is_IO_addr (Fabric_Addr addr) = fn_is_IO_addr (addr);

   method  Bool  m_is_near_mem_IO_addr (Fabric_Addr addr) = fn_is_near_mem_io_addr (addr);

   method  Bit #(64)  m_pc_reset_value     = pc_reset_value;
   method  Bit #(64)  m_mtvec_reset_value  = mtvec_reset_value;
   method  Bit #(64)  m_nmivec_reset_value = nmivec_reset_value;
endmodule

// ================================================================

endpackage
