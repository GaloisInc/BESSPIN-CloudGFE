// Copyright (c) 2016-2020 Bluespec, Inc. All Rights Reserved.
// Author: Rishiyur S. Nikhil

package AWS_AXI_Fabrics;

// ================================================================
// This package contains various non-polymorphic, separately
// synthesized instantiations of AXI4 and AXI4-Lite fabrics, each
// specifying the exact parameters for the polymorphic mkAXI4_Fabric
// and mkAXI4_Lite_Fabric.

// ================================================================

import AXI4_Types      :: *;
import AXI4_Fabric     :: *;
import AXI4_Lite_Types :: *;

import AWS_BSV_Top_Defs :: *;

// ================================================================
// Switch in front of the four AWS DDR4s

// ----------------
// Address-Decode function to route requests to appropriate slave
//     DDR4 A addr (slave 0): base addr 0x_0_0000_0000
//     DDR4 B addr (slave 1): base addr 0x_4_0000_0000
//     DDR4 C addr (slave 2): base addr 0x_8_0000_0000
//     DDR4 D addr (slave 3): base addr 0x_C_0000_0000    or higher

function Tuple2 #(Bool, Bit #(2))  fn_addr_to_ddr4_num (Bit #(64) addr);
   let      msbs      = addr [63:36];
   Bit #(2) slave_num = addr [35:34];
   Bool     valid     = (   ((msbs == 0) && (slave_num != 2'b11))
			 || (slave_num == 2'b11));
   return tuple2 (valid, slave_num);
endfunction

// ----------------
// The fabric

typedef AXI4_Fabric_IFC #(2,      // num_masters
			  4,      // num_slaves
			  16,     // wd_id
			  64,     // wd_addr
			  512,    // wd_data
			  0)
        AXI4_16_64_512_0_Fabric_2_4_IFC;

(* synthesize *)
module mkAXI4_16_64_512_0_Fabric_2_4 (AXI4_16_64_512_0_Fabric_2_4_IFC);
   let fabric <- mkAXI4_Fabric (fn_addr_to_ddr4_num);
   return fabric;
endmodule

// ================================================================

endpackage
