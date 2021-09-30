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
// host_AXI4 defs

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
// host AXI4-Lite defs

typedef AXI4_Lite_Master_IFC #(Wd_Addr_32, Wd_Data_32, Wd_User_0)  AXI4L_32_32_0_Master_IFC;
typedef AXI4_Lite_Slave_IFC  #(Wd_Addr_32, Wd_Data_32, Wd_User_0)  AXI4L_32_32_0_Slave_IFC;

typedef AXI4_Lite_Master_Xactor_IFC #(Wd_Addr_32,
				      Wd_Data_32,
				      Wd_User_0)  AXI4L_32_32_0_Master_Xactor_IFC;

typedef AXI4_Lite_Slave_Xactor_IFC #(Wd_Addr_32,
				     Wd_Data_32,
				     Wd_User_0)  AXI4L_32_32_0_Slave_Xactor_IFC;

// ================================================================
// AXI4 defs for DDR4 interface

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
// AXI4 defs for uncached DDR4 interface

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

endpackage
