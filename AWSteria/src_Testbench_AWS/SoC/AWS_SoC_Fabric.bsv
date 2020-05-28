// Copyright (c) 2013-2020 Bluespec, Inc. All Rights Reserved

package AWS_SoC_Fabric;

// ================================================================
// Defines a SoC Fabric that is a specialization of AXI4_Lite_Fabric
// for this particular SoC.

// ================================================================
// Project imports

import AXI4_Types  :: *;
import AXI4_Fabric :: *;

import Fabric_Defs :: *;    // for Wd_Addr, Wd_Data, Wd_User
import SoC_Map     :: *;    // for Num_Masters, Num_Slaves

// ================================================================
// Slave address decoder
// Identifies whether a given addr is legal and, if so, which  slave services it.

typedef Bit #(TLog #(Num_Slaves))  Slave_Num;

// ================================================================
// Extra definitions for the fabric

// Count and master-numbers of masters in the fabric.

Integer imem_master_num   = 0;
Integer dmem_master_num   = 1;
Integer accel0_master_num = 2;

`ifdef INCLUDE_ACCEL0
typedef 3 Num_Masters;
`else
typedef 2 Num_Masters;
`endif

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
// Interrupt request numbers (== index in to vector of
// interrupt-request lines in Core)

typedef  16  N_External_Interrupt_Sources;
Integer  n_external_interrupt_sources = valueOf (N_External_Interrupt_Sources);

Integer irq_num_uart16550_0 = 0;
Integer irq_num_host_to_hw  = 1;
Integer irq_num_accel0      = 2;

// ================================================================
// Specialization of parameterized AXI4 fabric for this SoC.

typedef AXI4_Fabric_IFC #(Num_Masters,
			  Num_Slaves,
			  Wd_Id,
			  Wd_Addr,
			  Wd_Data,
			  Wd_User)  AWS_SoC_Fabric_IFC;

// ----------------

(* synthesize *)
module mkAWS_SoC_Fabric (AWS_SoC_Fabric_IFC);

   SoC_Map_IFC soc_map <- mkSoC_Map;

   function Tuple2 #(Bool, Slave_Num) fn_addr_to_slave_num  (Fabric_Addr addr);

      // Main Mem
      if (   (soc_map.m_mem0_controller_addr_base <= addr)
	  && (addr < soc_map.m_mem0_controller_addr_lim))
	 return tuple2 (True, fromInteger (mem0_controller_slave_num));

      // Boot ROM
      else if (   (soc_map.m_boot_rom_addr_base <= addr)
	  && (addr < soc_map.m_boot_rom_addr_lim))
	 return tuple2 (True, fromInteger (boot_rom_slave_num));

`ifdef Near_Mem_TCM
      // TCM
      else if (   (soc_map.m_tcm_addr_base <= addr)
	       && (addr < soc_map.m_tcm_addr_lim))
	 return tuple2 (True, fromInteger (tcm_back_door_slave_num));
`endif

      // UART
      else if (   (soc_map.m_uart16550_0_addr_base <= addr)
	       && (addr < soc_map.m_uart16550_0_addr_lim))
	 return tuple2 (True, fromInteger (uart16550_0_slave_num));

      // AWS host mem access
      else if (   (soc_map.m_host_access_addr_base <= addr)
	       && (addr < soc_map.m_host_access_addr_lim))
	 return tuple2 (True, fromInteger (host_access_slave_num));

`ifdef HTIF_MEMORY
      else if (   (soc_map.m_htif_addr_base <= addr)
	       && (addr < soc_map.m_htif_addr_lim))
	 return tuple2 (True, fromInteger (htif_slave_num));
`endif

`ifdef INCLUDE_ACCEL0
      // Accelerator 0
      else if (   (soc_map.m_accel0_addr_base <= addr)
	       && (addr < soc_map.m_accel0_addr_lim))
	 return tuple2 (True, fromInteger (accel0_slave_num));
`endif

      else
	 return tuple2 (False, ?);
   endfunction

   AXI4_Fabric_IFC #(Num_Masters, Num_Slaves, Wd_Id, Wd_Addr, Wd_Data, Wd_User)
       fabric <- mkAXI4_Fabric (fn_addr_to_slave_num);

   return fabric;
endmodule

// ================================================================

endpackage
