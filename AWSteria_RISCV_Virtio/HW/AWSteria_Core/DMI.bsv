// Copyright (c) 2021 Bluespec, Inc. All Rights Reserved.

package DMI;

// ================================================================
// This package defines the DMI interface to the Debug Module.

// ================================================================

import Semi_FIFOF :: *;

// ================================================================
// Debug Module Interface (DMI)
// Note: Debug Module register data is 32b even in RV64 and RV128 systems.

typedef struct {
   Bool      is_read;    // True => read; False => Write
   Bit #(7)  addr;       // Debug Module register address
   Bit #(32) wdata;      // Debug Module reqister write-data (relevant only for Writes)
   } DMI_Req
deriving (Bits, FShow);

typedef struct {
   Bit #(32) rdata;   // Debug Module register read-data
   } DMI_Rsp
deriving (Bits, FShow);

// Interface of Debug Module facing remote debugger (e.g. GDB)

typedef Server_Semi_FIFOF #(DMI_Req, DMI_Rsp) DMI;

// A dummy interface to tie off DMI if it is not used.

DMI dummy_DMI_ifc = interface DMI;
		       interface request  = dummy_FIFOF_I;
		       interface response = dummy_FIFOF_O;
		    endinterface;

// ================================================================

endpackage
