// Copyright (c) 2016-2021 Bluespec, Inc. All Rights Reserved.
// Author: Rishiyur S. Nikhil

package AWS_DDR_Fabric;

// ================================================================
// This package contains an instantiation of an AXI4 fabric to sit in
// front of a set of DDRs for AWSteria_HW.

// ================================================================

import AXI4_Types      :: *;
import AXI4_Fabric     :: *;

import AWSteria_HW_IFC      :: *;    // for N_DDRs
import AWSteria_HW_Platform :: *;    // for ddr_{A,B,C,D}_{base,lim}

// ================================================================
// Fabric interface

typedef AXI4_Fabric_IFC #(2,       // num M ports
			  N_DDRs,  // num S ports
			  16,      // wd_id
			  64,      // wd_addr
			  512,     // wd_data
			  0)
        AXI4_16_64_512_0_Fabric_2_N_IFC;

// ================================================================
// Fabric module

(* synthesize *)
module mkAXI4_16_64_512_0_Fabric_2_N (AXI4_16_64_512_0_Fabric_2_N_IFC);

   // ----------------
   // Address-Decode function

   function Tuple2 #(Bool, Bit #(TLog #(N_DDRs)))  fn_addr_to_target_num (Bit #(64) addr);
      if ((ddr_A_base <= addr) && (addr < ddr_A_lim))
	 return tuple2 (True, 0);

`ifdef INCLUDE_DDR_B
      else if ((ddr_B_base <= addr) && (addr < ddr_B_lim))
	 return tuple2 (True, 1);
`endif

`ifdef INCLUDE_DDR_C
      else if ((ddr_C_base <= addr) && (addr < ddr_C_lim))
	 return tuple2 (True, 2);
`endif

`ifdef INCLUDE_DDR_D
      else if ((ddr_D_base <= addr) && (addr < ddr_D_lim))
	 return tuple2 (True, 3);
`endif

      else
	 return tuple2 (False, 0);
   endfunction

   // ----------------

   let fabric <- mkAXI4_Fabric (fn_addr_to_target_num);
   return fabric;
endmodule

// ================================================================

endpackage
