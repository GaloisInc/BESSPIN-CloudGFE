// Copyright (c) 2016-2020 Bluespec, Inc. All Rights Reserved.
// Author: Rishiyur S. Nikhil

package AWS_DDR4_Model;

// ================================================================
// This package is a model of the AWS DDR4s (at the AXI4 interface)
// for use in simulation.
// WARNING: This is a simplified model: does not support AXI4 bursts.

// ================================================================
// BSV lib imports

import Vector          :: *;
import Connectable     :: *;

// ================================================================
// Project imports

import AXI4_Types     :: *;
import AXI4_Deburster :: *;

import AWS_BSV_Top_Defs :: *;

import Mem_Model :: *;

// ================================================================

export mkAWS_DDR4_Models;

module mkAWS_DDR4_Models (Vector #(2, AXI4_16_64_512_0_Slave_IFC));
   Vector #(2, AXI4_16_64_512_0_Slave_IFC) v_ddr4;
   v_ddr4 [0] <- mkAWS_DDR4_A_Model;
   v_ddr4 [1] <- mkAWS_DDR4_B_Model;
   return v_ddr4;
endmodule

// ================================================================
// DDR4_A
// Supports bursts

(* synthesize *)
module mkAWS_DDR4_A_Model (AXI4_16_64_512_0_Slave_IFC);
   let ifc <- mkMem_Model (0,                       // verbosity
			   0,                       // ddr4_num
			   True,                    // init_with_memhex
			   "DDR4_A.memhex512",      // memhex_filename
			   'h_0_0000_0000,          // byte_addr_base
			   'h_0_8000_0000,          // byte_addr_lim     (2 GB)
			   'h_0_8000_0000);         // bytes_implemented (2 GB)

   AXI4_Deburster_IFC #(16, 64, 512, 0) deburster <- mkAXI4_Deburster;
   mkConnection (deburster.to_slave, ifc);
   return deburster.from_master;
endmodule

// ================================================================
// DDR4_B
// Supports bursts

(* synthesize *)
module mkAWS_DDR4_B_Model (AXI4_16_64_512_0_Slave_IFC);
   let ifc <- mkMem_Model (0,                       // verbosity
			   1,                       // ddr4_num
			   True,                    // init_with_memhex
			   "DDR4_B.memhex512",      // memhex_filename
			   'h_0_8000_0000,          // byte_addr_base
			   'h_1_0000_0000,          // byte_addr_lim     (2 GB)
			   'h_0_8000_0000);         // bytes_implemented (2 GB)
   AXI4_Deburster_IFC #(16, 64, 512, 0) deburster <- mkAXI4_Deburster;
   mkConnection (deburster.to_slave, ifc);
   return deburster.from_master;
endmodule

// ================================================================

endpackage
