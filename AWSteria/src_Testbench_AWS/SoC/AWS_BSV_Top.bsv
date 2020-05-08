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

import FIFOF       :: *;
import GetPut      :: *;
import Connectable :: *;

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
// OCL channel numbers

Integer host_to_hw_chan_control      = 0;
Integer host_to_hw_chan_UART         = 1;
Integer host_to_hw_chan_ipi          = 2;
Integer host_to_hw_chan_debug_module = 3;

Integer hw_to_host_chan_status       = 0;
Integer hw_to_host_chan_UART         = 1;
Integer hw_to_host_chan_ipi          = 2;
Integer hw_to_host_chan_debug_module = 3;

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

   // AWS signal
   Reg #(Bit #(4)) rg_ddr4_ready     <- mkReg (0);

   Reg #(Bool)     rg_initialized    <- mkReg (False);
   Reg #(Bool)     rg_ddr4_is_loaded <- mkReg (False);

   // ================================================================
   // Connect OCL Adapter and SoC control
   // Writes are coded as follows: (ad hoc; we may evolve this as needed)
   // [1:0] is a tag
   //     tag_ddr4_is_loaded    [31:2]  = ?: 'signal that ddr4 is loaded'
   //     tag_verbosity         [31:8]  = logdelay, [7:2] = verbosity
   //     tag_no_watch_tohost   [31:2]  = ?    set 'watch_tohost' to False
   //     tag_watch_tohost      [31:2]  = x    set 'watch_tohost' to True; tohost_addr = (x << 2)

   Bit #(2) tag_ddr4_is_loaded  = 0;
   Bit #(2) tag_verbosity       = 1;
   Bit #(2) tag_no_watch_tohost = 2;
   Bit #(2) tag_watch_tohost    = 3;

   rule rl_host_to_hw_control;
      Bit #(32) data <- pop_o (ocl_adapter.v_from_host [host_to_hw_chan_control]);
      Bit #(2)  tag = data [1:0];
      if (tag == tag_ddr4_is_loaded) begin
	 rg_ddr4_is_loaded <= True;
	 if (verbosity != 0)
	    $display ("AWS_BSV_Top: control: ddr4 loaded");
      end
      else if (tag == tag_verbosity) begin
	 Bit #(4)  verbosity = truncate   (data [7:2]);
	 Bit #(64) logdelay  = zeroExtend (data [31:8]);
	 soc_top.ma_set_verbosity (verbosity, logdelay);
	 if (verbosity != 0)
	    $display ("    Control: verbosity %0d, logdelay %0h", verbosity, logdelay);
      end
      else if (tag == tag_no_watch_tohost) begin
	 soc_top.ma_set_watch_tohost (False, ?);
	 if (verbosity != 0)
	    $display ("    Control: do not watch tohost");
      end
      else if (tag == tag_watch_tohost) begin
	 Bit #(64) tohost_addr = zeroExtend ({ data [31:2], 2'b00 });
	 soc_top.ma_set_watch_tohost (True, tohost_addr);
	 if (verbosity != 0)
	    $display ("    Control: watch tohost at addr %0h", tohost_addr);
      end
      else begin
	 $display ("AWS_BSV_Top: Control: ERROR: unrecognized control command %0h", data);
      end
   endrule

   rule rl_hw_to_host_status (soc_top.mv_status != 0);
      let status = soc_top.mv_status;
      ocl_adapter.v_to_host [hw_to_host_chan_status].enq (zeroExtend (status));
   endrule

   // ================================================================
   // Connect OCL Adapter and UART

   rule rl_console_to_UART;
      Bit #(32) ch <- pop_o (ocl_adapter.v_from_host [host_to_hw_chan_UART]);
      soc_top.put_from_console.put (truncate (ch));
   endrule

   rule rl_UART_to_console;
      let ch <- soc_top.get_to_console.get;
      ocl_adapter.v_to_host [hw_to_host_chan_UART].enq (zeroExtend (ch));
   endrule

   // ================================================================
   // Connect OCL Adapter and inter-processor interrupts to/from Core

   rule rl_host_to_hw_ipi;
      Bit #(32) x <- pop_o (ocl_adapter.v_from_host [host_to_hw_chan_ipi]);
      soc_top.host_to_hw_interrupt.put (x [0]);
   endrule

   rule rl_hw_to_host_ipi;
      let x <- soc_top.hw_to_host_interrupt.get;
      ocl_adapter.v_to_host [hw_to_host_chan_ipi].enq (zeroExtend (x));
   endrule

   // ================================================================

   // Connect SoC DDR4 interface to crossbar [1]
   mkConnection (soc_top.to_ddr4, fabric.v_from_masters [1]);

   // ================================================================
   // Connection OCL Adapter to Debug Module
   // First word [31:24] specifies rd or wr; lsbs specify DM address
   // If write, second word specifies DMI write-data

`ifdef INCLUDE_GDB_CONTROL

   Bit #(2) state_dm_idle   = 0;
   Bit #(2) state_dm_rd_rsp = 1;
   Bit #(2) state_dm_wr_req = 2;

   Reg #(Bit #(2)) rg_state_dm <- mkReg (state_dm_idle);
   Reg #(Bit #(7)) rg_dm_addr  <- mkRegU;

   rule rl_control_to_DM_idle (rg_state_dm == state_dm_idle);
      Bit #(32) x <- pop_o (ocl_adapter.v_from_host [host_to_hw_chan_debug_module]);
      Bool     is_read = (x [31:24] == 0);
      Bit #(7) dm_addr = truncate (x);

      if (is_read) begin
	 let control_req = Control_Req {op:   external_control_req_op_read_control_fabric,
					arg1: zeroExtend (dm_addr),
					arg2: 0};                      // DMI data
	 server_external_control.request.put (control_req);
	 rg_state_dm <= state_dm_rd_rsp;
	 if (verbosity != 0)
	    $display ("AWS_BSV_Top.rl_control_to_DM_idle: read request: dm_addr %0h", dm_addr);
      end
      else begin
	 rg_dm_addr  <= dm_addr;
	 rg_state_dm <= state_dm_wr_req;
      end
   endrule

   rule rl_control_to_DM_rd_rsp (rg_state_dm == state_dm_rd_rsp);
      let control_rsp <- pop (server_external_control.response.get);
      ocl_adapter.v_to_host [hw_to_host_chan_debug_module].enq (truncate (control_rsp.result));
      if (verbosity != 0)
	 $display ("AWS_BSV_Top.rl_control_to_DM_rd_rsp: data %0h", control_rsp.result);
   endrule


   rule rl_control_to_DM_wr_req (rg_state_dm == state_dm_wr_req);
      Bit #(32) data <- pop_o (ocl_adapter.v_from_host [host_to_hw_chan_debug_module]);
      let control_req = Control_Req {op:   external_control_req_op_write_control_fabric,
				     arg1: zeroExtend (rg_dm_addr),
				     arg2: zeroExtend (data)};
      server_external_control.request.put (control_req);
      if (verbosity != 0)
	 $display ("AWS_BSV_Top.rl_control_to_DM_wr_req: dm_addr %0h data %0h", rg_dm_addr, data);
   endrule

`endif

   // ================================================================

   rule rl_initialize ((! rg_initialized)
		       && (rg_ddr4_ready == 4'b_1111)
		       && rg_ddr4_is_loaded);
      soc_top.ma_ddr4_ready;
      rg_initialized <= True;
      $display ("%0d: AWS_BSV_Top.rl_initialize: DDRs ready, DDRs loaded; start DUT", cur_cycle);
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
