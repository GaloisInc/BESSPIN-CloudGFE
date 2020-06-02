// Copyright (c) 2020 Bluespec, Inc.  All Rights Reserved.
// Author: Rishiyur S. Nikhil

package AWS_BSV_Top_Defs;

// ================================================================
// This package contains AXI4 and AXI4-Lite definitions for various
// AWS interfaces, and the interface def for the AWS_BSV_Top module.

// ================================================================

import AXI4 :: *;
import AXI4Lite :: *;

// ================================================================
// AXI4 and AXI4-Lite widths of interest

typedef 4    Wd_Id_4;
typedef 6    Wd_Id_6;
typedef 15   Wd_Id_15;
typedef 16   Wd_Id_16;

typedef 32   Wd_Addr_32;
typedef 64   Wd_Addr_64;

typedef 32   Wd_Data_32;
typedef 64   Wd_Data_64;
typedef 512  Wd_Data_512;

typedef 0    Wd_AWUser_0;
typedef 0    Wd_WUser_0;
typedef 0    Wd_BUser_0;
typedef 0    Wd_ARUser_0;
typedef 0    Wd_RUser_0;

// ================================================================
// AXI4 defs for cl_ports interface for DMA_PCIS

typedef AXI4_Master_Synth#( Wd_Id_6, Wd_Addr_64, Wd_Data_512
                          , Wd_AWUser_0, Wd_WUser_0, Wd_BUser_0, Wd_ARUser_0, Wd_RUser_0)
        AXI4_6_64_512_0_0_0_0_0_Master_Synth;
typedef AXI4_Slave_Synth#( Wd_Id_6, Wd_Addr_64, Wd_Data_512
                         , Wd_AWUser_0, Wd_WUser_0, Wd_BUser_0, Wd_ARUser_0, Wd_RUser_0)
        AXI4_6_64_512_0_0_0_0_0_Slave_Synth;
typedef AXI4_Master_Xactor#( Wd_Id_6, Wd_Addr_64, Wd_Data_512
                           , Wd_AWUser_0, Wd_WUser_0, Wd_BUser_0, Wd_ARUser_0, Wd_RUser_0)
        AXI4_6_64_512_0_0_0_0_0_Master_Xactor;
typedef AXI4_Slave_Xactor#( Wd_Id_6, Wd_Addr_64, Wd_Data_512
                          , Wd_AWUser_0, Wd_WUser_0, Wd_BUser_0, Wd_ARUser_0, Wd_RUser_0)
        AXI4_6_64_512_0_0_0_0_0_Slave_Xactor;

// ================================================================
// AXI4 defs for sh_ddr interfaces for DDR4 access

typedef AXI4_Master_Synth#( Wd_Id_15, Wd_Addr_64, Wd_Data_512
                          , Wd_AWUser_0, Wd_WUser_0, Wd_BUser_0, Wd_ARUser_0, Wd_RUser_0)
        AXI4_15_64_512_0_0_0_0_0_Master_Synth;
typedef AXI4_Master_Synth#( Wd_Id_16, Wd_Addr_64, Wd_Data_512
                          , Wd_AWUser_0, Wd_WUser_0, Wd_BUser_0, Wd_ARUser_0, Wd_RUser_0)
        AXI4_16_64_512_0_0_0_0_0_Master_Synth;
typedef AXI4_Slave_Synth#( Wd_Id_15, Wd_Addr_64, Wd_Data_512
                         , Wd_AWUser_0, Wd_WUser_0, Wd_BUser_0, Wd_ARUser_0, Wd_RUser_0)
        AXI4_15_64_512_0_0_0_0_0_Slave_Synth;
typedef AXI4_Slave_Synth#( Wd_Id_16, Wd_Addr_64, Wd_Data_512
                         , Wd_AWUser_0, Wd_WUser_0, Wd_BUser_0, Wd_ARUser_0, Wd_RUser_0)
        AXI4_16_64_512_0_0_0_0_0_Slave_Synth;
typedef AXI4_Master_Xactor#( Wd_Id_15, Wd_Addr_64, Wd_Data_512
                           , Wd_AWUser_0, Wd_WUser_0, Wd_BUser_0, Wd_ARUser_0, Wd_RUser_0)
        AXI4_15_64_512_0_0_0_0_0_Master_Xactor;
typedef AXI4_Slave_Xactor#( Wd_Id_15, Wd_Addr_64, Wd_Data_512
                          , Wd_AWUser_0, Wd_WUser_0, Wd_BUser_0, Wd_ARUser_0, Wd_RUser_0)
        AXI4_15_64_512_0_0_0_0_0_Slave_Xactor;

// ================================================================
// AXI4-Lite defs for OCL and other interfaces

typedef AXI4Lite_Master_Synth#( Wd_Addr_32, Wd_Addr_32
                              , Wd_AWUser_0, Wd_WUser_0, Wd_BUser_0, Wd_ARUser_0, Wd_RUser_0)
        AXI4L_32_32_0_0_0_0_0_Master_Synth;
typedef AXI4Lite_Slave_Synth#( Wd_Addr_32, Wd_Addr_32
                             , Wd_AWUser_0, Wd_WUser_0, Wd_BUser_0, Wd_ARUser_0, Wd_RUser_0)
        AXI4L_32_32_0_0_0_0_0_Slave_Synth;
typedef AXI4Lite_Master_Xactor#( Wd_Addr_32, Wd_Addr_32
                               , Wd_AWUser_0, Wd_WUser_0, Wd_BUser_0, Wd_ARUser_0, Wd_RUser_0)
        AXI4L_32_32_0_0_0_0_0_Master_Xactor;
typedef AXI4Lite_Slave_Xactor#( Wd_Addr_32, Wd_Addr_32
                              , Wd_AWUser_0, Wd_WUser_0, Wd_BUser_0, Wd_ARUser_0, Wd_RUser_0)
        AXI4L_32_32_0_0_0_0_0_Slave_Xactor;

// ================================================================
// The top-level interface for the BSV design

interface AWS_BSV_Top_IFC;
   // Facing SH: DMA_PCIS
   // WARNING: Actual DMA_PCIS is AXI4_6_64_512_0 and is missing the 'wid' bus
   //          The top-level SV shim should adapt these.
   interface AXI4_15_64_512_0_0_0_0_0_Slave_Synth  dma_pcis_slave;

   // Facing SH: OCL
   interface AXI4L_32_32_0_0_0_0_0_Slave_Synth     ocl_slave;

   // Facing DDR4
   interface AXI4_16_64_512_0_0_0_0_0_Master_Synth  ddr4_A_master;
   interface AXI4_16_64_512_0_0_0_0_0_Master_Synth  ddr4_B_master;
   interface AXI4_16_64_512_0_0_0_0_0_Master_Synth  ddr4_C_master;
   interface AXI4_16_64_512_0_0_0_0_0_Master_Synth  ddr4_D_master;

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
endinterface

// ================================================================

endpackage
