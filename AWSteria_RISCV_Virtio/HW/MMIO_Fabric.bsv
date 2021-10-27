// Copyright (c) 2013-2021 Bluespec, Inc. All Rights Reserved
// Author: Rishiyur S. Nikhil

package MMIO_Fabric;

// ================================================================
// Defines an AXI4 fabric for MMIO in AWSteria_RISCV_Virtio.

// ================================================================
// BSV library imports

// None

// ----------------
// AXI

import AXI4_Types  :: *;
import AXI4_Fabric :: *;

// ----------------
// Project imports

import SoC_Map        :: *;    // For address map of MMIO IPs
import AXI_Param_Defs :: *;    // For AXI bus widths

// ================================================================
// Definitions for the fabric

// Count and initiator-numbers of initiators in the fabric.

typedef 1 Num_Initiators;

Integer core_initiator_num = 0;

// Count and target-numbers of targets in the fabric.

typedef 4 Num_Targets;

Integer boot_rom_target_num        = 0;
Integer ddr4_0_uncached_target_num = 1;
Integer uart16550_0_target_num     = 2;
Integer host_access_target_num     = 3;

// ================================================================
// Specialization of AXI4 fabric for MMIO fabric

typedef AXI4_Fabric_IFC #(Num_Initiators,
			  Num_Targets,
			  AXI4_Wd_Id,
			  AXI4_Wd_Addr,
			  AXI4_Wd_Data_B,
			  AXI4_Wd_User)  MMIO_Fabric_IFC;

// ----------------

(* synthesize *)
module mkMMIO_Fabric (MMIO_Fabric_IFC);

   SoC_Map_IFC soc_map <- mkSoC_Map;

   // ----------------
   // Address decoder

   function Tuple2 #(Bool, Bit #(TLog #(Num_Targets)))
      fn_addr_to_target_num (Bit #(AXI4_Wd_Addr) addr);

      // Boot ROM
      if (   (soc_map.m_boot_rom_addr_base <= addr)
	 && (addr < soc_map.m_boot_rom_addr_lim))
	 return tuple2 (True, fromInteger (boot_rom_target_num));

      // UART
      else if (   (soc_map.m_uart16550_0_addr_base <= addr)
	       && (addr < soc_map.m_uart16550_0_addr_lim))
	 return tuple2 (True, fromInteger (uart16550_0_target_num));

      // MMIO serviced by AWSteria host
      else if (   (soc_map.m_host_access_addr_base <= addr)
	       && (addr < soc_map.m_host_access_addr_lim))
	 return tuple2 (True, fromInteger (host_access_target_num));

      // Uncached DDR4 and dma_0 both go to same target
      else if (   (soc_map.m_ddr4_0_uncached_addr_base <= addr)
	       && (addr < soc_map.m_ddr4_0_uncached_addr_lim))
	 return tuple2 (True, fromInteger (ddr4_0_uncached_target_num));

      else if (   (soc_map.m_dma_0_addr_base <= addr)
	       && (addr < soc_map.m_dma_0_addr_lim))
	 return tuple2 (True, fromInteger (ddr4_0_uncached_target_num));

      else
	 return tuple2 (False, ?);
   endfunction

   // ----------------
   // The fabric

   AXI4_Fabric_IFC #(Num_Initiators,
		     Num_Targets,
		     AXI4_Wd_Id,
		     AXI4_Wd_Addr,
		     AXI4_Wd_Data_B,
		     AXI4_Wd_User)
       fabric <- mkAXI4_Fabric (fn_addr_to_target_num);

   return fabric;
endmodule

// ================================================================

endpackage
