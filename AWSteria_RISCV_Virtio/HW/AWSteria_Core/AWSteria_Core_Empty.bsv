// Copyright (c) 2021 Bluespec, Inc. All Rights Reserved.

package AWSteria_Core_Empty;

// ================================================================
// This package defines the interface for an 'mkAWSteria_Core' module
// which may contain one or more of the following:
//   - one or more CPUs (of RISC-V ISA or other ISA)
//   - a PLIC (RISC-V platform level interrupt controller or other)
//   - a Debug Module (RISC-V Debug Module or other)
//   - a TV encoder (RISC-V or other)

// Each of possibly many modules 'mkAWSteria_Core' will be written in BSV.
// It can directly contain BSV code,

// ================================================================
// Lib imports

// BSV libs
import Vector :: *;
import Clocks :: *;

// ----------------
// BSV additional libs

import Semi_FIFOF :: *;

// ----------------
// AXI
import AXI4_Types      :: *;
import AXI4_Lite_Types :: *;

// ================================================================
// Project imports

// Debug Module interface
import DMI :: *;

// Trace and Tandem Verification
import PC_Trace :: *;
import TV_Info  :: *;

// Interface for this module
import AWSteria_Core_IFC :: *;

// ================================================================
// Interface specialization to non-polymorphic type

// These parameter values are used in AWSteria_RISCV_Virtio with Flute
// or Toooba CPUs.

typedef AWSteria_Core_IFC #(16,    // numeric type wd_id_mem,
			    64,    // numeric type wd_addr_mem,
			    512,   // numeric type wd_data_mem,
			    0,     // numeric type wd_user_mem,

			    16,    // numeric type wd_id_mmio,
			    64,    // numeric type wd_addr_mmio,
			    64,    // numeric type wd_data_mmio,
			    0,     // numeric type wd_user_mmio,

			    16,    // numeric type wd_id_dma,
			    64,    // numeric type wd_addr_dma,
			    512,   // numeric type wd_data_dma,
			    0,     // numeric type wd_user_dma,

			    5     // numeric type t_n_interrupt_sources (from UART, from host virtio)
			    ) AWSteria_Core_IFC_Specialized;

// ================================================================
// An empty module that can be filled with BSV code
// or substituted by Verilog (hand-written, Chisel-generated, ...)

// The extra clocks are typically slower clocks for some components
// that may need them.

(* synthesize *)
module mkAWSteria_Core #(Reset dm_reset,                // reset for Debug Module
			 Clock b_CLK, Reset b_RST_N,    // extra clock b
			 Clock c_CLK, Reset c_RST_N)    // extra clock c
                       (AWSteria_Core_IFC_Specialized);

   // TO BE FILLED IN WITH SPECIFIC CORE(s)

endmodule

// ================================================================

endpackage
