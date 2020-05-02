// Copyright (c) 2020 Bluespec, Inc.  All Rights Reserved.
// Author: Rishiyur S. Nikhil

package AWS_BSV_Top;

// ================================================================
// This package contains an example AWS_BSV_Top module for AWS.
// It contains a AXI4 fabric (64b addrs, 512b data):
//    Master 0: taken straight out as the DMA_PCIS interface
//    Master 1: services memory-requests from DUT.
//              (the other side of the DUT talks to other SH interfaces like OCL).
//    Slaves: Connect to the AWS DDR4s (DDR A, B, C, D).

// ================================================================
// BSV library imports

import Connectable :: *;
import FIFOF       :: *;

// ----------------
// BSV additional libs

import Cur_Cycle  :: *;
import Semi_FIFOF :: *;
import GetPut_Aux :: *;

// ================================================================
// Project imports

import AXI4_Types      :: *;
import AXI4_Fabric     :: *;
import AXI4_Lite_Types :: *;

import AWS_BSV_Top_Defs :: *;
import AWS_SoC_Top      :: *;
import AWS_DDR4_Adapter :: *;
import AWS_AXI_Fabrics  :: *;
import AWS_OCL_Adapter  :: *;

// ================================================================

export mkAWS_BSV_Top;

// ================================================================

(* synthesize *)
module mkAWS_BSV_Top (AWS_BSV_Top_IFC);

   // 0: quiet    1: rules
   Integer verbosity = 0;

   // WindSoC
   AWS_SoC_Top_IFC soc_top <- mkAWS_SoC_Top;

   // Adapter towards OCL
   OCL_Adapter_IFC  ocl_adapter <- mkOCL_Adapter;

   // AXI4 crossbar to connect to the four DDRs
   AXI4_16_64_512_0_Fabric_2_4_IFC  fabric <- mkAXI4_16_64_512_0_Fabric_2_4;

   Reg #(Bool)     rg_initialized <- mkReg (False);
   Reg #(Bit #(4)) rg_ddr4_ready  <- mkReg (0);

   // ================================================================
   // Connections

`ifdef INCLUDE_GDB_CONTROL
   // Connect OCL adapter to SoC external control (Debug Module)
   mkConnection (ocl_adapter.external_control_client,
		 soc_top.server_external_control);
`endif

   // Connect OCL adapter to SoC UART
   mkConnection (ocl_adapter.put_to_console,   soc_top.get_to_console);
   mkConnection (ocl_adapter.get_from_console, soc_top.put_from_console);

   // Connect SoC DDR4 interface to crossbar [1]
   mkConnection (soc_top.to_ddr4, fabric.v_from_masters [1]);

   // ================================================================

   rule rl_initialize ((! rg_initialized)
		       && (rg_ddr4_ready == 4'b_1111)
		       && ocl_adapter.mv_test_control.ddr4_loaded);

      soc_top.set_verbosity (ocl_adapter.mv_test_control.verbosity,
			     ocl_adapter.mv_test_control.logdelay);
      soc_top.set_watch_tohost (ocl_adapter.mv_test_control.watch_tohost,
				ocl_adapter.mv_test_control.tohost_addr);
      rg_initialized <= True;
      $display ("%0d: AWS_BSV_Top.rl_initialize: DDRs ready; start DUT", cur_cycle);
   endrule

   // Relay status from SoC to host via OCL adapter
   rule rl_relay_SoC_status_to_host;
      let status = soc_top.mv_status;
      ocl_adapter.ma_set_status (zeroExtend (status));
   endrule

   // ================================================================
   // INTERFACE

   // Facing SH
   interface AWS_AXI4_Slave_IFC       dma_pcis_slave = fabric.v_from_masters [0];
   interface AWS_AXI4_Lite_Slave_IFC  ocl_slave      = ocl_adapter.ocl_slave;

   // Facing DDR4
   interface AWS_AXI4_Master_IFC  ddr4_A_master = fabric.v_to_slaves [0];
   interface AWS_AXI4_Master_IFC  ddr4_B_master = fabric.v_to_slaves [1];
   interface AWS_AXI4_Master_IFC  ddr4_C_master = fabric.v_to_slaves [2];
   interface AWS_AXI4_Master_IFC  ddr4_D_master = fabric.v_to_slaves [3];

   // DDR4 ready signals
   // The SystemVerilog top-level invokes this to signal readiness of AWS DDR4 A, B, C, D
   method Action m_ddr4_ready (Bit #(4) ddr4_A_B_C_D_ready);
      rg_ddr4_ready <= ddr4_A_B_C_D_ready;
   endmethod

   // Global counters
   // The SystemVerilog top-level provides these 4 nsec counters
   // Note: they tick at 4ns even if the DUT is synthesized at a different clock speed
   // (so, may increment by more than 1 on DUT clock ticks)
   method Action m_glcount0 (Bit #(64) glcount0) = noAction;
   method Action m_glcount1 (Bit #(64) glcount1) = noAction;

   // Virtual LEDs
   method Bit #(16) m_vled = 0;

   // Virtual DIP Switches
   method Action m_vdip (Bit #(16) vdip) = noAction;
endmodule

// ================================================================

endpackage
