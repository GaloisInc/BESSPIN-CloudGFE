// Copyright (c) 2021 Bluespec, Inc.  All Rights Reserved.
// Author: Rishiyur S. Nikhil

package AXI_Param_Defs;

// ================================================================
// This package contains definitions for various parameters for AXI4
// and AXI4-Lite components in AWSteria_RISCV_Virtio.

// ================================================================
// Imports

// None

// ================================================================
// AXI4 widths (coherent DMA and DDR paths)

typedef 16   AXI4_Wd_Id;

typedef 64   AXI4_Wd_Addr;

typedef 512  AXI4_Wd_Data_A;    // For coherent DMA interfaces
typedef 64   AXI4_Wd_Data_B;    // For MMIO interfaces

typedef 0    AXI4_Wd_User;

// ================================================================
// AXI4-Lite widths (control/status)

typedef 32  AXI4L_Wd_Addr;
typedef 32  AXI4L_Wd_Data;
typedef 0   AXI4L_Wd_User;

// ================================================================

endpackage
