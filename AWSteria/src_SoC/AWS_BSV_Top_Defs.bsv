// Copyright (c) 2020 Bluespec, Inc.  All Rights Reserved.
// Author: Rishiyur S. Nikhil

package AWS_BSV_Top_Defs;

// ================================================================
// This package contains AXI4 and AXI4-Lite definitions for various
// AWS interfaces, and the interface def for the AWS_BSV_Top module.

// ================================================================
// BSV library imports

import Vector :: *;

// ================================================================
// Project imports

import AXI4_Types      :: *;
import AXI4_Lite_Types :: *;

import AWS_BSV_Top_Defs_Platform :: *;

// ================================================================
// Export the platform-specific defines on top of everything in
// this package

export AWS_BSV_Top_Defs          :: *;
export AWS_BSV_Top_Defs_Platform :: *;

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
   interface Vector #(Num_DDR4, AXI4_16_64_512_0_Master_IFC)  v_ddr4_master;

   // DDR4 ready signals
   // The SystemVerilog top-level invokes this to signal readiness of AWS DDR4 A, B, C, D

   (* always_ready, always_enabled *)
   method Action m_ddr4_ready (Bit #(Num_DDR4) ddr4_ready);

   // Global counters
   // The SystemVerilog top-level provides these 4 nsec counters
   // Note: they tick at 4ns even if the DUT is synthesized at a different clock speed
   // (so, may increment by more than 1 on DUT clock ticks)

   (* always_ready, always_enabled *)
   method Action m_v_glcount (Vector #(Num_glcount, Bit #(64)) v_glcount);

   // Virtual LEDs
   (* always_ready *)
   method Bit #(Num_vLED) m_vled;

   // Virtual DIP Switches
   (* always_enabled, always_ready *)
   method Action m_vdip (Bit #(Num_vDIP) vdip);
endinterface

// ================================================================

endpackage
