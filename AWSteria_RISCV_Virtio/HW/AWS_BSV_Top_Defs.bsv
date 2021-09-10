// Copyright (c) 2021 Bluespec, Inc.  All Rights Reserved.
// Author: Rishiyur S. Nikhil

package AWS_BSV_Top_Defs;

// ================================================================
// This package contains AXI4 and AXI4-Lite definitions for various
// AWS interfaces, and the interface def for the AWS_BSV_Top module.

// ================================================================

import AXI4_Types      :: *;
import AXI4_Lite_Types :: *;

// ================================================================
// AXI4 and AXI4-Lite widths of interest

typedef 4    Wd_Id_4;
typedef 6    Wd_Id_6;
typedef 16   Wd_Id_16;

typedef 32   Wd_Addr_32;
typedef 64   Wd_Addr_64;

typedef 32   Wd_Data_32;
typedef 64   Wd_Data_64;
typedef 512  Wd_Data_512;

typedef 0    Wd_User_0;

// ================================================================
// AXI4 defs for cl_ports interface for DMA_PCIS

typedef AXI4_Master_IFC #(Wd_Id_6, Wd_Addr_64, Wd_Data_512, Wd_User_0)  AXI4_6_64_512_0_Master_IFC;
typedef AXI4_Slave_IFC  #(Wd_Id_6, Wd_Addr_64, Wd_Data_512, Wd_User_0)  AXI4_6_64_512_0_Slave_IFC;

typedef AXI4_Master_Xactor_IFC #(Wd_Id_6,
				 Wd_Addr_64,
				 Wd_Data_512,
				 Wd_User_0)  AXI4_6_64_512_0_Master_Xactor_IFC;

typedef AXI4_Slave_Xactor_IFC #(Wd_Id_6,
				Wd_Addr_64,
				Wd_Data_512,
				Wd_User_0)  AXI4_6_64_512_0_Slave_Xactor_IFC;

// ================================================================
// AXI4 defs for sh_ddr interfaces for DDR4 access

typedef AXI4_Master_IFC #(Wd_Id_16, Wd_Addr_64, Wd_Data_512, Wd_User_0)  AXI4_16_64_512_0_Master_IFC;
typedef AXI4_Slave_IFC  #(Wd_Id_16, Wd_Addr_64, Wd_Data_512, Wd_User_0)  AXI4_16_64_512_0_Slave_IFC;

typedef AXI4_Master_Xactor_IFC #(Wd_Id_16,
				 Wd_Addr_64,
				 Wd_Data_512,
				 Wd_User_0)  AXI4_16_64_512_0_Master_Xactor_IFC;

typedef AXI4_Slave_Xactor_IFC #(Wd_Id_16,
				Wd_Addr_64,
				Wd_Data_512,
				Wd_User_0)  AXI4_16_64_512_0_Slave_Xactor_IFC;

// ================================================================
// AXI4 defs for sh_ddr interfaces for uncached DDR4 access

typedef AXI4_Master_IFC #(Wd_Id_16, Wd_Addr_64, Wd_Data_64, Wd_User_0)  AXI4_16_64_64_0_Master_IFC;
typedef AXI4_Slave_IFC  #(Wd_Id_16, Wd_Addr_64, Wd_Data_64, Wd_User_0)  AXI4_16_64_64_0_Slave_IFC;

typedef AXI4_Master_Xactor_IFC #(Wd_Id_16,
				 Wd_Addr_64,
				 Wd_Data_64,
				 Wd_User_0)  AXI4_4_64_64_0_Master_Xactor_IFC;

typedef AXI4_Slave_Xactor_IFC #(Wd_Id_16,
				Wd_Addr_64,
				Wd_Data_64,
				Wd_User_0)  AXI4_4_64_64_0_Slave_Xactor_IFC;

// ================================================================
// AXI4-Lite defs for OCL and other interfaces

typedef AXI4_Lite_Master_IFC #(Wd_Addr_32, Wd_Data_32, Wd_User_0)  AXI4L_32_32_0_Master_IFC;
typedef AXI4_Lite_Slave_IFC  #(Wd_Addr_32, Wd_Data_32, Wd_User_0)  AXI4L_32_32_0_Slave_IFC;

typedef AXI4_Lite_Master_Xactor_IFC #(Wd_Addr_32,
				      Wd_Data_32,
				      Wd_User_0)  AXI4L_32_32_0_Master_Xactor_IFC;

typedef AXI4_Lite_Slave_Xactor_IFC #(Wd_Addr_32,
				     Wd_Data_32,
				     Wd_User_0)  AXI4L_32_32_0_Slave_Xactor_IFC;

// ================================================================
// The top-level interface for the BSV design

interface AWS_BSV_Top_IFC;
   // Facing SH: DMA_PCIS
   // WARNING: Actual DMA_PCIS is AXI4_6_64_512_0 and is missing the 'wid' bus
   //          The top-level SV shim should adapt these.
   interface AXI4_16_64_512_0_Slave_IFC  dma_pcis_slave;

   // Facing SH: OCL
   interface AXI4L_32_32_0_Slave_IFC     ocl_slave;

   // Facing DDR4
   interface AXI4_16_64_512_0_Master_IFC  ddr4_A_master;
   interface AXI4_16_64_512_0_Master_IFC  ddr4_B_master;
   interface AXI4_16_64_512_0_Master_IFC  ddr4_C_master;
   interface AXI4_16_64_512_0_Master_IFC  ddr4_D_master;

   // DDR4 ready signals
   // The SystemVerilog top-level invokes this to signal readiness of AWS DDR4 A, B, C, D

   (* always_ready, always_enabled *)
   method Action m_ddr4_ready (Bit #(4) ddr4_A_B_C_D_ready);

   // Global counters
   // The SystemVerilog top-level provides these 4 nsec counters
   // Note: they tick at 4ns even if the DUT is synthesized at a different clock speed
   // (so, may increment by more than 1 on DUT clock ticks)

   (* always_ready, always_enabled *)
   method Action m_glcount0 (Bit #(64) glcount0);
   (* always_ready, always_enabled *)
   method Action m_glcount1 (Bit #(64) glcount1);

   // Virtual LEDs
   (* always_ready *)
   method Bit #(16) m_vled;

   // Virtual DIP Switches
   (* always_enabled, always_ready *)
   method Action m_vdip (Bit #(16) vdip);

   // Final shutdown (useful in shutting down simulation)
   method Bool m_shutdown_received;
endinterface

// ================================================================

endpackage
