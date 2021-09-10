// Copyright (c) 2013-2021 Bluespec, Inc. All Rights Reserved

package AWS_SoC_Fabric;

// ================================================================
// Defines a SoC Fabric that is a specialization of AXI4_Fabric
// for this particular SoC.

// ================================================================
// Project imports

import AXI4_Types  :: *;
import AXI4_Fabric :: *;

import Fabric_Defs :: *;    // for Wd_Addr, Wd_Data, Wd_User
import SoC_Map     :: *;

// ================================================================
// Extra definitions for the fabric

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
// Target address decoder
// Identifies whether a given addr is legal and, if so, which target services it.

typedef Bit #(TLog #(Num_Targets))  Target_Num;

// ================================================================
// Interrupt request numbers (== index in to vector of
// interrupt-request lines in Core)

typedef  16  N_External_Interrupt_Sources;
Integer  n_external_interrupt_sources = valueOf (N_External_Interrupt_Sources);

Integer irq_num_uart16550_0 = 0;
Integer irq_num_host_to_hw  = 1;

// ================================================================
// Specialization of parameterized AXI4 fabric for this SoC.

typedef AXI4_Fabric_IFC #(Num_Initiators,
			  Num_Targets,
			  Wd_Id,
			  Wd_Addr,
			  Wd_Data,
			  Wd_User)  AWS_SoC_Fabric_IFC;

// ----------------
// Fabric's address decoder

function Tuple2 #(Bool, Target_Num) fn_addr_to_target_num  (SoC_Map_IFC soc_map,
							    Fabric_Addr addr);
   // Boot ROM
   if (   (soc_map.m_boot_rom_addr_base <= addr)
       && (addr < soc_map.m_boot_rom_addr_lim))
      return tuple2 (True, fromInteger (boot_rom_target_num));

   // UART
   else if (   (soc_map.m_uart16550_0_addr_base <= addr)
	    && (addr < soc_map.m_uart16550_0_addr_lim))
      return tuple2 (True, fromInteger (uart16550_0_target_num));

   // AWS host mem access
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

(* synthesize *)
module mkAWS_SoC_Fabric (AWS_SoC_Fabric_IFC);

   SoC_Map_IFC soc_map <- mkSoC_Map;

   AXI4_Fabric_IFC #(Num_Initiators, Num_Targets, Wd_Id, Wd_Addr, Wd_Data, Wd_User)
       fabric <- mkAXI4_Fabric (fn_addr_to_target_num (soc_map));

   return fabric;
endmodule

// ================================================================

endpackage
