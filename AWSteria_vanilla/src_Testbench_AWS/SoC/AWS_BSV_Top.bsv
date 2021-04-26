// Copyright (c) 2021 Bluespec, Inc.  All Rights Reserved.
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

import AXI4_Types           :: *;
import AXI4_Fabric          :: *;
import AXI4_Lite_Types      :: *;
import AXI4_Widener         :: *;
import AXI4_Addr_Translator :: *;

import AWS_BSV_Top_Defs :: *;
import AWS_SoC_Top      :: *;
import AWS_OCL_Adapter  :: *;

`ifdef INCLUDE_PC_TRACE
import PC_Trace :: *;
`endif

`ifdef INCLUDE_TANDEM_VERIF
import TV_Info :: *;
`endif

import C_Imports :: *;

// ================================================================

export mkAWS_BSV_Top;
export host_to_hw_chan_control;
export host_to_hw_chan_UART;
export host_to_hw_chan_mem_rsp;
export host_to_hw_chan_debug_module;
export host_to_hw_chan_interrupt;

export hw_to_host_chan_status;
export hw_to_host_chan_UART;
export hw_to_host_chan_mem_req;
export hw_to_host_chan_debug_module;
export hw_to_host_chan_pc_trace;

// ================================================================
// OCL channel numbers

Integer host_to_hw_chan_control      = 0;
Integer host_to_hw_chan_UART         = 1;
Integer host_to_hw_chan_mem_rsp      = 2;
Integer host_to_hw_chan_debug_module = 3;
Integer host_to_hw_chan_interrupt    = 4;

Integer hw_to_host_chan_status       = 0;
Integer hw_to_host_chan_UART         = 1;
Integer hw_to_host_chan_mem_req      = 2;
Integer hw_to_host_chan_debug_module = 3;
Integer hw_to_host_chan_pc_trace     = 4;

// ================================================================

(* synthesize *)
module mkAWS_BSV_Top (AWS_BSV_Top_IFC);

   // 0: quiet    1: rules
   Integer verbosity = 0;

   // WindSoC
   AWS_SoC_Top_IFC soc_top <- mkAWS_SoC_Top;

   // Adapter towards OCL
   OCL_Adapter_IFC  ocl_adapter <- mkOCL_Adapter;

   // Widener to connect to uncached mem
   AXI4_Widener_IFC #(Wd_Id_16,
		      Wd_Addr_64,
		      Wd_Data_64,
		      Wd_Data_512,
		      Wd_User_0) uncached_mem_widener<- mkAXI4_Widener;

   // AWS signal
   Reg #(Bit #(4)) rg_ddr4_ready     <- mkReg (0);

   Reg #(Bool)     rg_ddr4_is_loaded <- mkReg (False);    // AWS says ddr4 is ready
   Reg #(Bool)     rg_initialized_1  <- mkReg (False);    // Relayed ddr4_ready to core
   Reg #(Bool)     rg_initialized_2  <- mkReg (False);    // Start SoC

`ifdef INCLUDE_PC_TRACE
   Reg #(Bool)       rg_pc_trace_on           <- mkReg (False);
   Reg #(Bit #(64))  rg_pc_trace_interval_max <- mkRegU;
`endif

   // ================================================================
   // Connect OCL Adapter and SoC control
   // Writes are coded as follows: (ad hoc; we may evolve this as needed)
   // [3:0] is a tag; [31:4] gives more info

   Bit #(4) tag_ddr4_is_loaded  = 0;    // ddr4 has been loaded from host
   Bit #(4) tag_verbosity       = 1;    // set verbosity
   Bit #(4) tag_no_watch_tohost = 2;    // set 'watch_tohost' to False
   Bit #(4) tag_watch_tohost    = 3;    // set 'watch_tohost' to True
   Bit #(4) tag_shutdown        = 4;    // stop simulation
   Bit #(4) tag_pc_trace        = 5;    // set pc trace subsampling interval

   rule rl_host_to_hw_control;
      Bit #(32) data <- pop_o (ocl_adapter.v_from_host [host_to_hw_chan_control]);
      Bit #(4)  tag = data [3:0];
      if (tag == tag_ddr4_is_loaded) begin
	 // data [31:4] ignored
	 $display ("%0d: %m.rl_host_to_hw_control: ddr4 loaded", cur_cycle);
	 rg_ddr4_is_loaded <= True;
      end
      else if (tag == tag_verbosity) begin
	 // data [31:8]  = logdelay, [7:4] = verbosity
	 Bit #(4)  verbosity = data [7:4];
	 Bit #(64) logdelay  = zeroExtend (data [31:8]);
	 $display ("%0d: %m.rl_host_to_hw_control: verbosity %0d, logdelay %0h",
		   cur_cycle, verbosity, logdelay);
	 soc_top.ma_set_verbosity (verbosity, logdelay);
      end
      else if (tag == tag_no_watch_tohost) begin
	 // data [31:4] ignored
	 $display ("%0d: %m.rl_host_to_hw_control: do not watch tohost", cur_cycle);
	 soc_top.ma_set_watch_tohost (False, ?);
      end
      else if (tag == tag_watch_tohost) begin
	 // (data [31:4] << 4) = tohost_addr
	 Bit #(64) tohost_addr = zeroExtend ({ data [31:4], 4'b00 });
	 $display ("%0d: %m.rl_host_to_hw_control: watch tohost at addr %0h",
		   cur_cycle, tohost_addr);
	 soc_top.ma_set_watch_tohost (True, tohost_addr);
      end
      else if (tag == tag_shutdown) begin
	 // data [31:4] ignored
	 $display ("%0d: %m.rl_host_to_hw_control: SHUTDOWN", cur_cycle);
	 // TODO: RETURN THIS OUT OF THE INTERFACE, DON'T $FINISH HERE
	 $finish (0);
      end
      else if (tag == tag_pc_trace) begin
	 // data [7:4]  = (0 ? switch off PC tracing : switch on)
	 // data [31:8] = max of interval countdown (0 means every instruction)
	 if (data [7:4] == 0) begin
	    rg_pc_trace_on <= False;
	    $display ("%0d: %m.rl_host_to_hw_control: set PC trace off", cur_cycle);
	 end
	 else begin
	    rg_pc_trace_on           <= True;
	    rg_pc_trace_interval_max <= zeroExtend (data [31:8]);
	    $display ("%0d: %m.rl_host_to_hw_control: set PC trace on, interval max = %0h",
		      cur_cycle, data [31:8]);
	 end
      end
      else begin
	 $display ("%0d: %m.rl_host_to_hw_control: ERROR: unrecognized control command %0h",
		   cur_cycle, data);
      end
   endrule

   // Return hw status to host
   // Encoding: { 16'tohost_value,
   //             4'ddr4_ready, 2'b0, 1'ddr4_is_loaded, 1'initialized_2, 8'soc_status}
   rule rl_hw_to_host_status;
      Bit #(32) status = zeroExtend(soc_top.mv_status);
      if (rg_initialized_2)  status = status | (1 << 8);
      if (rg_ddr4_is_loaded) status = status | (1 << 9);
      status = status | (zeroExtend(rg_ddr4_ready) << 12);

      let tohost_value = soc_top.mv_tohost_value;
      status = status | { tohost_value [15:0], 16'h0 };
      ocl_adapter.v_to_host [hw_to_host_chan_status].enq (status);
      if ((verbosity > 0) && ((tohost_value != 0) || (status [7:0] != 0)))
	 $display ("%0d: %m.rl_hw_to_host_status: %0h", cur_cycle, status);
   endrule

   // ================================================================
   // Connect OCL Adapter and UART

   rule rl_console_to_UART;
      Bit #(32) ch <- pop_o (ocl_adapter.v_from_host [host_to_hw_chan_UART]);
      soc_top.put_from_console.put (truncate (ch));

      if (verbosity > 0)
	 $display ("%0d: AWS_BSV_Top.rl_console_to_UART: %02h", cur_cycle, ch);
   endrule

   rule rl_UART_to_console;
      let ch <- soc_top.get_to_console.get;
      ocl_adapter.v_to_host [hw_to_host_chan_UART].enq (zeroExtend (ch));

      if (verbosity > 0)
	 $display ("%0d: AWS_BSV_Top.rl_UART_to_console: %02h", cur_cycle, ch);
   endrule

   // ================================================================
   // Connect OCL Adapter hw-to-host memory request and host-to-hw memory response

   rule rl_hw_to_aws_host_mem_req;
      Bit #(32) x <- soc_top.to_aws_host.get;
      ocl_adapter.v_to_host [hw_to_host_chan_mem_req].enq (x);

      if (verbosity > 0)
	 $display ("%0d: AWS_BSV_Top.rl_hw_to_aws_host_mem_req: %02h", cur_cycle, x);
   endrule

   rule rl_aws_host_to_hw_mem_rsp;
      Bit #(32) x <- pop_o (ocl_adapter.v_from_host [host_to_hw_chan_mem_rsp]);
      soc_top.from_aws_host.put (x);

      if (verbosity > 0)
	 $display ("%0d: AWS_BSV_Top.rl_aws_host_to_hw_mem_rsp: %02h", cur_cycle, x);
   endrule

   // ================================================================
   // Connect OCL Adapter host-to-hw interrupt line

   rule rl_aws_host_to_hw_interrupt;
      Bit #(32) x <- pop_o (ocl_adapter.v_from_host [host_to_hw_chan_interrupt]);

      if (verbosity > 0) begin
	 $display ("%0d: AWS_BSV_Top.rl_aws_host_to_hw_interrupt: %08h", cur_cycle, x);
      end

      soc_top.ma_aws_host_to_hw_interrupt (x [0]);
   endrule

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
   // PC Trace
   // Serialize each PC_Trace struct into 32-bit words sent to host

`ifdef INCLUDE_PC_TRACE
   Reg #(Bit #(3))   rg_pc_trace_serialize_state <- mkReg (0);
   Reg #(PC_Trace)   rg_pc_trace                 <- mkRegU;
   Reg #(Bit #(64))  rg_pc_trace_interval_ctr    <- mkReg (0);

   rule rl_pc_trace_0 (rg_pc_trace_serialize_state == 0);
      PC_Trace pc_trace <- soc_top.g_pc_trace.get;

      if (rg_pc_trace_on && (rg_pc_trace_interval_ctr == 0)) begin
	 // Send sample to host (in next few rules); re-init sub-sample counter
	 ocl_adapter.v_to_host [hw_to_host_chan_pc_trace].enq (pc_trace.cycle [31:0]);
	 rg_pc_trace                 <= pc_trace;
	 rg_pc_trace_interval_ctr    <= rg_pc_trace_interval_max;
	 rg_pc_trace_serialize_state <= 1;
	 $display ("PC Trace: cycle %0d  instret %0d  pc %0h (sending)",
		   pc_trace.cycle, pc_trace.instret, pc_trace.pc);
      end
      else begin
	 // Discard sample; just do sub-sample counter
	 rg_pc_trace_interval_ctr <= rg_pc_trace_interval_ctr - 1;
	 // $display ("PC Trace: cycle %0d  instret %0d  pc %0h",
	 //	   pc_trace.cycle, pc_trace.instret, pc_trace.pc);
      end
   endrule

   rule rl_pc_trace_1 (rg_pc_trace_serialize_state == 1);
      ocl_adapter.v_to_host [hw_to_host_chan_pc_trace].enq (rg_pc_trace.cycle [63:32]);
      rg_pc_trace_serialize_state <= 2;
   endrule

   rule rl_pc_trace_2 (rg_pc_trace_serialize_state == 2);
      ocl_adapter.v_to_host [hw_to_host_chan_pc_trace].enq (rg_pc_trace.instret [31:0]);
      rg_pc_trace_serialize_state <= 3;
   endrule

   rule rl_pc_trace_3 (rg_pc_trace_serialize_state == 3);
      ocl_adapter.v_to_host [hw_to_host_chan_pc_trace].enq (rg_pc_trace.instret [63:32]);
      rg_pc_trace_serialize_state <= 4;
   endrule

   rule rl_pc_trace_4 (rg_pc_trace_serialize_state == 4);
      ocl_adapter.v_to_host [hw_to_host_chan_pc_trace].enq (rg_pc_trace.pc [31:0]);
      rg_pc_trace_serialize_state <= 5;
   endrule

   rule rl_pc_trace_5 (rg_pc_trace_serialize_state == 5);
      ocl_adapter.v_to_host [hw_to_host_chan_pc_trace].enq (rg_pc_trace.pc [63:32]);
      rg_pc_trace_serialize_state <= 0;
   endrule
`endif

   // ================================================================
   // Tandem verifier: drain and output vectors of bytes

`ifdef INCLUDE_TANDEM_VERIF
   rule rl_tv_vb_out;
      let tv_info <- soc_top.tv_verifier_info_get.get;
      let n  = tv_info.num_bytes;
      let vb = tv_info.vec_bytes;

      Bit #(32) success = 1;

      for (Bit #(32) j = 0; j < fromInteger (valueOf (TV_VB_SIZE)); j = j + 8) begin
	 Bit #(64) w64 = { vb [j+7], vb [j+6], vb [j+5], vb [j+4], vb [j+3], vb [j+2], vb [j+1], vb [j] };
	 let success1 <- c_trace_file_load_word64_in_buffer (j, w64);
	 success = (success & success1);
      end

      if (success == 0) begin
	 $display ("ERROR: Top_HW_Side.rl_tv_vb_out: error loading %0d bytes into buffer", n);
	 $finish (1);
      end
      else begin
	 // Send the data
	 success <- c_trace_file_write_buffer (n);
	 if (success == 0)
	    $display ("ERROR: Top_HW_Side.rl_tv_vb_out: error writing bytevec data buffer (%0d bytes)", n);
      end
   endrule
`endif

   // ================================================================
   // Initializations

   rule rl_initialize_1 ((! rg_initialized_1) && (rg_ddr4_ready[3:0] == 4'b1111));
      $display ("%0d: %m.rl_initialize_1", cur_cycle);
      $display ("    DDRs ready, mem access enabled");

      soc_top.ma_ddr4_ready;
      rg_initialized_1 <= True;

`ifdef INCLUDE_TANDEM_VERIF
      // ----------------
      // Open file for Tandem Verification trace output
      let success <- c_trace_file_open ('h_AA);
      if (success == 0) begin
	 $display ("    ERROR: Top_HW_Side.rl_step0: error opening trace file.");
	 $display ("    Aborting.");
	 $finish (1);
      end
      else
	 $display ("    opened trace file.");
`endif
   endrule

   rule rl_initialize_2 (rg_initialized_1
			 && (! rg_initialized_2)
			 && rg_ddr4_is_loaded);
      soc_top.ma_ddr4_is_loaded;
      rg_initialized_2 <= True;

      $display ("%0d: %m.rl_initialize_2: DDRs loaded", cur_cycle);
   endrule

   // ================================================================
   // Widener for uncached memory access

   mkConnection (soc_top.to_ddr4_0_uncached, uncached_mem_widener.from_master);

   // ================================================================
   // INTERFACE

   AXI4_16_64_512_0_Master_IFC dummy_ddr4_master = dummy_AXI4_Master_ifc;

   // Facing SH
   interface AWS_AXI4_Slave_IFC       dma_pcis_slave = soc_top.dma_server;
   interface AWS_AXI4_Lite_Slave_IFC  ocl_slave      = ocl_adapter.ocl_slave;

   // Facing DDR4
   interface AWS_AXI4_Master_IFC  ddr4_A_master = soc_top.to_ddr4;
   interface AWS_AXI4_Master_IFC  ddr4_B_master = fv_AXI4_Master_Address_Translator (True, // add, not subtract
										     'h_4_0000_0000,  // addr offset
										     uncached_mem_widener.to_slave);
   interface AWS_AXI4_Master_IFC  ddr4_C_master = dummy_ddr4_master;
   interface AWS_AXI4_Master_IFC  ddr4_D_master = dummy_ddr4_master;

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
