// Copyright (c) 2021 Bluespec, Inc.  All Rights Reserved.
// Author: Rishiyur S. Nikhil

package AWSteria_HW;

// ================================================================
// This package contains the AWSteria_RISCV_Virtio top-level
// which, in turn, fits into AWSteria_Infra.
// It implements
//     module mkAWSteria_HW #(...) (AWSteria_HW_IFC #(...))
// expected by AWSteria_Infra.

// ================================================================
// BSV library imports

import FIFOF        :: *;
import GetPut       :: *;
import ClientServer :: *;
import Connectable  :: *;

// ----------------
// BSV additional libs

import Cur_Cycle  :: *;
import Semi_FIFOF :: *;
import GetPut_Aux :: *;

// ----------------
// AXI

import AXI4_Types           :: *;
import AXI4_Fabric          :: *;
import AXI4_Lite_Types      :: *;
import AXI4_Widener         :: *;

// ================================================================
// Project imports

import AWSteria_HW_IFC :: *;
import AXI4_Lite_Fabric :: *;

import AWS_BSV_Top_Defs        :: *;
import AWS_Host_AXI4L_Channels :: *;
import AWS_SoC_Top             :: *;
import AWS_DDR_Fabric          :: *;

`ifdef INCLUDE_PC_TRACE
import PC_Trace :: *;
`endif

`ifdef INCLUDE_GDB_CONTROL
import External_Control :: *;
`endif

`ifdef INCLUDE_TANDEM_VERIF
import TV_Info :: *;
import C_Imports :: *;
`endif

// ================================================================

export mkAWSteria_HW;
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
// Channel numbers that are multiplexed on host AXI4-Lite

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

// ****************************************************************
// Module: synthesized instance of AXI4-Lite 1x2 fabric connecting
// host AXI4 to DRM (targe 0) and AXI4-Lite adapter (target 1)

// ----------------
// Address-Decode function to route requests to appropriate target

Bit #(32) adapter_addr_min = 'h_0000_0000;    // 0
Bit #(32) adapter_addr_max = 'h_000F_FFFF;    // 1 MB

Bit #(32) drm_addr_min     = 'h_0010_0000;    // 1  MB
Bit #(32) drm_addr_max     = 'h_0010_3FFF;    // 16 KB


function Tuple2 #(Bool, Bit #(1))  fn_addr_to_AXI4L_target_num (Bit #(32) addr);
   if ((drm_addr_min <= addr) && (addr <= drm_addr_max))
      return tuple2 (True, 0);

   else if ((adapter_addr_min <= addr) && (addr <= adapter_addr_max))
      return tuple2 (True, 1);

   else
      return tuple2 (False, ?);
endfunction

// ----------------
// The fabric

typedef AXI4_Lite_Fabric_IFC #(1,     // num M ports
			       2,     // num S ports
			       32,    // wd_addr
			       32,    // wd_data
			       0)
        AXI4L_32_32_0_Fabric_1_2_IFC;

(* synthesize *)
module mkAXI4L_32_32_0_Fabric_1_2 (AXI4L_32_32_0_Fabric_1_2_IFC);
   let fabric <- mkAXI4_Lite_Fabric (fn_addr_to_AXI4L_target_num);
   return fabric;
endmodule

// ****************************************************************
// Module: Dummy DRM module

interface DRM_IFC;
   interface AXI4_Lite_Slave_IFC #(32, 32, 0) axi4L_S;
   method    Bool                             ip_enable;
   interface Clock                            clock_for_app;
endinterface

(* synthesize *)
module mkDRM (DRM_IFC);
   // Instantiate slave transactor
   AXI4_Lite_Slave_Xactor_IFC #(32, 32, 0) axi4L_S_xactor <- mkAXI4_Lite_Slave_Xactor;

   Reg #(Bit #(32)) rg_data   <- mkReg (0);

   // GatedClockIfc gated_clock <- mkGatedClockFromCC (False);

   // ================================================================
   // Write transactions

   rule rl_wr_xaction;
      let wra <- pop_o (axi4L_S_xactor.o_wr_addr);
      let wrd <- pop_o (axi4L_S_xactor.o_wr_data);

      $display ("DRM: WR xaction:\n  ", fshow (wra), "\n  ", fshow (wrd));

      AXI4_Lite_Resp resp = (  ((wra.awaddr & 'h3) == 0)
			     ? AXI4_LITE_OKAY
			     : AXI4_LITE_SLVERR);

      if (resp == AXI4_LITE_OKAY) begin
	 $display ("  rg_data old %0x", rg_data);
	 $display ("  rg_data new %0x", wrd.wdata);
	 rg_data <= wrd.wdata;

	 if ((rg_data[0] == 1'b0)  &&  (wrd.wdata[0] == 1'b1))
	    $display ("  Enabling clock");
	 if ((rg_data[0] == 1'b1)  &&  (wrd.wdata[0] == 1'b0))
	    $display ("  Disabling clock");

	 // gated_clock.setGateCond (wrd.wdata != 0);
      end

      let wrr = AXI4_Lite_Wr_Resp {bresp: resp,
				   buser: wra.awuser};

      axi4L_S_xactor.i_wr_resp.enq (wrr);
      $display ("  ", fshow (wrr));
   endrule

   // ================================================================
   // Read transactions

   rule rl_rd_xaction;
      let rda <- pop_o (axi4L_S_xactor.o_rd_addr);

      $display ("DRM: RD xaction:\n  ", fshow (rda));

      AXI4_Lite_Resp resp = (  ((rda.araddr & 'h3) != 0)
			     ? AXI4_LITE_SLVERR
			     : AXI4_LITE_OKAY);

      let rdd = AXI4_Lite_Rd_Data {rresp: resp,
				   rdata: (  (resp == AXI4_LITE_OKAY)
					   ? rg_data
					   : 32'h_89AB_CDEF),
				   ruser: rda.aruser};

      axi4L_S_xactor.i_rd_data.enq (rdd);
      $display ("  ", fshow (rdd));
   endrule

   // ================================================================
   // INTERFACE

   interface axi4L_S       = axi4L_S_xactor.axi_side;
   method    ip_enable     = (rg_data [0] == 1);
   interface clock_for_app = noClock;    // gated_clock.new_clk;
endmodule


(* synthesize *)
module mkAWSteria_HW #(Clock b_CLK, Reset b_RST_N)
                     (AWSteria_HW_IFC #(AXI4_Slave_IFC #(16, 64, 512, 0),
					AXI4_Lite_Slave_IFC #(32, 32, 0),
					AXI4_Master_IFC #(16, 64, 512, 0)));
   // 0: quiet    1: rules
   Integer verbosity      = 0;
   Integer verbosity_uart = 0;


   // ----------------
   // DRM
   DRM_IFC drm <- mkDRM;
   // AXI4-Lite 1x2 switch
   AXI4L_32_32_0_Fabric_1_2_IFC axi4L_switch <- mkAXI4L_32_32_0_Fabric_1_2;

   // ----------------
   // SoC containing RISC-V CPU
   AWS_SoC_Top_IFC soc_top <- mkAWS_SoC_Top;

   // Adapter towards AXI4-Lite
   Host_AXI4L_Channels_IFC  host_AXI4L_channels <- mkHost_AXI4L_Channels;

   // Widener for uncached mem accesses, from 64b (like I/O) to 512b (to DDR fabric)
   AXI4_Widener_IFC #(Wd_Id_16,
		      Wd_Addr_64,
		      Wd_Data_64,
		      Wd_Data_512,
		      Wd_User_0) uncached_mem_widener <- mkAXI4_Widener;

   // DDR fabric
   AXI4_16_64_512_0_Fabric_2_N_IFC ddr_fabric <- mkAXI4_16_64_512_0_Fabric_2_N;

   // ----------------
   // AWS control and status

   Reg #(Bit #(4)) rg_ddr4_ready <- mkReg (0);

   Reg #(Bool)     rg_ddr4_is_loaded    <- mkReg (False);    // AWS says ddr4 is ready
   Reg #(Bool)     rg_initialized_1     <- mkReg (False);    // Relayed ddr4_ready to core
   Reg #(Bool)     rg_initialized_2     <- mkReg (False);    // Start SoC
   Reg #(Bool)     rg_shutdown_received <- mkReg (False);    // For simulation shutdown

   // ----------------
   // AWS Debug and Trace

`ifdef INCLUDE_PC_TRACE
   Reg #(Bool)       rg_pc_trace_on           <- mkReg (False);
   Reg #(Bit #(64))  rg_pc_trace_interval_max <- mkRegU;
`endif


   // Connect AXI4-Lite switch to AXI4-Lite-to-AXI4-adapter and DRM
   mkConnection (axi4L_switch.v_to_slaves [0], drm.axi4L_S);
   mkConnection (axi4L_switch.v_to_slaves [1], host_AXI4L_channels.axi4L_S);

   // ================================================================
   // Connect SoC DDR ports to DDR fabric

   // SoC 512b port (from last-level cache) to DDR fabric
   mkConnection (soc_top.to_ddr4,               ddr_fabric.v_from_masters [0]);

   // SoC 64b port (uncached, IO-like) to widener; then to DDR fabric
   mkConnection (soc_top.to_ddr4_0_uncached,    uncached_mem_widener.from_master);
   mkConnection (uncached_mem_widener.to_slave, ddr_fabric.v_from_masters [1]);

   // ================================================================
   // Connect host AXI4L channels to SoC control
   // Writes are coded as follows: (ad hoc; we may evolve this as needed)
   // wdata [3:0] is a tag; [31:4] gives more info

   Bit #(4) tag_ddr4_is_loaded  = 0;    // ddr4 has been loaded from host
   Bit #(4) tag_verbosity       = 1;    // set verbosity
   Bit #(4) tag_no_watch_tohost = 2;    // set 'watch_tohost' to False
   Bit #(4) tag_watch_tohost    = 3;    // set 'watch_tohost' to True
   Bit #(4) tag_shutdown        = 4;    // stop simulation
   Bit #(4) tag_pc_trace        = 5;    // set pc trace subsampling interval

   rule rl_host_to_hw_control;
      Bit #(32) data <- pop_o (host_AXI4L_channels.v_from_host [host_to_hw_chan_control]);
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
	 rg_shutdown_received <= True;
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
      host_AXI4L_channels.v_to_host [hw_to_host_chan_status].enq (status);
      if ((verbosity > 0) && ((tohost_value != 0) || (status [7:0] != 0)))
	 $display ("%0d: %m.rl_hw_to_host_status: %0h", cur_cycle, status);
   endrule

   // ================================================================
   // Connect Host AXI4L Channels and UART

   // ----------------
   // keyboard to UART

   rule rl_console_to_UART;
      Bit #(32) ch <- pop_o (host_AXI4L_channels.v_from_host [host_to_hw_chan_UART]);
      soc_top.put_from_console.put (truncate (ch));

      if (verbosity_uart > 0)
	 $display ("%0d: AWSteria_HW.rl_console_to_UART: %02h", cur_cycle, ch);
   endrule

   // ----------------
   // UART to console
   // Use buffering to send up to 4 chars at a
   // time in the available 32 bits.

   // This FIFO allows deeper buffering of UART output
   FIFOF #(Bit #(32)) f_uart_to_console <- mkSizedFIFOF (8);

   rule rl_UART_to_console;
      let x <- pop (f_uart_to_console);
      host_AXI4L_channels.v_to_host [hw_to_host_chan_UART].enq (x);
   endrule

   // The following are for accumulating chars into 4-char chunks

   Reg #(Bit #(32)) rg_uart_buf <- mkReg (0);
   Reg #(Bit #(16)) rg_uart_timeout  <- mkReg (0);
   Bit #(16)        uart_timeout_max = 'h2000;

   rule rl_UART_to_console_accum;
      let ch <- soc_top.get_to_console.get;
      if (verbosity_uart > 0)
	 $write ("%0d: AWSteria_HW.rl_UART_to_console_accum:", cur_cycle);

      // If rg_uart_buf is full, send it
      Bit #(32) buf_val = rg_uart_buf;
      if (buf_val [31] == 1'b1) begin
	 f_uart_to_console.enq (buf_val);
	 if (verbosity_uart > 0) begin
	    $write (" [send");
	    if (buf_val [31] == 1) $write (" %02h", buf_val [30:24]);
	    if (buf_val [23] == 1) $write (" %02h", buf_val [22:16]);
	    if (buf_val [15] == 1) $write (" %02h", buf_val [14: 8]);
	    if (buf_val [ 7] == 1) $write (" %02h", buf_val [ 6: 0]);
	    $write (" rg_uart_timeout 0x%0h/%0h]",
		      rg_uart_timeout, uart_timeout_max);
	 end

	 buf_val = 0;
      end

      if (verbosity_uart > 0)
	 $display (" buffer %02h", ch);

      // Shift in the new char, and refill timeout
      rg_uart_buf     <= { buf_val [23:0], (8'h80 | ch) };
      rg_uart_timeout <= uart_timeout_max;
   endrule

   // Send accumulated chars after sufficient no-activity delay

   (* descending_urgency = "rl_UART_to_console_accum, rl_UART_timeout" *)
   rule rl_UART_timeout (rg_uart_buf != 0);
      Bit #(32) buf_val = rg_uart_buf;
      if (rg_uart_timeout == 0) begin
	 host_AXI4L_channels.v_to_host [hw_to_host_chan_UART].enq (buf_val);
	 rg_uart_buf <= 0;

	 if (verbosity_uart > 0) begin
	    $write ("%0d: AWSteria_HW.rl_UART_timeout: send",
		    cur_cycle, uart_timeout_max);
	    if (buf_val [31] == 1) $write (" %02h", buf_val [30:24]);
	    if (buf_val [23] == 1) $write (" %02h", buf_val [22:16]);
	    if (buf_val [15] == 1) $write (" %02h", buf_val [14: 8]);
	    if (buf_val [ 7] == 1) $write (" %02h", buf_val [ 6: 0]);
	    $display (" (max 0x%0h cycles)", uart_timeout_max);
	 end
      end
      else
	 rg_uart_timeout <= rg_uart_timeout - 1;
   endrule

   // ================================================================
   // Connect Host AXI4L Channels hw-to-host memory request and host-to-hw memory response

   rule rl_hw_to_aws_host_mem_req;
      Bit #(32) x <- soc_top.to_aws_host.get;
      host_AXI4L_channels.v_to_host [hw_to_host_chan_mem_req].enq (x);

      if (verbosity > 0)
	 $display ("%0d: AWSteria_HW.rl_hw_to_aws_host_mem_req: %02h", cur_cycle, x);
   endrule

   rule rl_aws_host_to_hw_mem_rsp;
      Bit #(32) x <- pop_o (host_AXI4L_channels.v_from_host [host_to_hw_chan_mem_rsp]);
      soc_top.from_aws_host.put (x);

      if (verbosity > 0)
	 $display ("%0d: AWSteria_HW.rl_aws_host_to_hw_mem_rsp: %02h", cur_cycle, x);
   endrule

   // ================================================================
   // Connect Host AXI4L Channels host-to-hw interrupt line

   rule rl_aws_host_to_hw_interrupt;
      Bit #(32) x <- pop_o (host_AXI4L_channels.v_from_host [host_to_hw_chan_interrupt]);

      if (verbosity > 0) begin
	 $display ("%0d: AWSteria_HW.rl_aws_host_to_hw_interrupt: %08h", cur_cycle, x);
      end

      soc_top.ma_aws_host_to_hw_interrupt (x);
   endrule

   // ================================================================
   // Connection Host AXI4L Channels to Debug Module
   // First word [31:24] specifies rd or wr; lsbs specify DM address
   // If write, second word specifies DMI write-data

`ifdef INCLUDE_GDB_CONTROL

   Bit #(2) state_dm_idle   = 0;
   Bit #(2) state_dm_rd_rsp = 1;
   Bit #(2) state_dm_wr_req = 2;

   Reg #(Bit #(2)) rg_state_dm <- mkReg (state_dm_idle);
   Reg #(Bit #(7)) rg_dm_addr  <- mkRegU;

   rule rl_control_to_DM_idle (rg_state_dm == state_dm_idle);
      Bit #(32) x <- pop_o (host_AXI4L_channels.v_from_host [host_to_hw_chan_debug_module]);
      Bool     is_read = (x [31:24] == 0);
      Bit #(7) dm_addr = truncate (x);

      if (is_read) begin
	 let control_req = Control_Req {op:   external_control_req_op_read_control_fabric,
					arg1: zeroExtend (dm_addr),
					arg2: 0};                      // DMI data
	 soc_top.server_external_control.request.put (control_req);
	 rg_state_dm <= state_dm_rd_rsp;
	 if (verbosity != 0)
	    $display ("AWSteria_HW.rl_control_to_DM_idle: read request: dm_addr %0h", dm_addr);
      end
      else begin
	 rg_dm_addr  <= dm_addr;
	 rg_state_dm <= state_dm_wr_req;
      end
   endrule

   rule rl_control_to_DM_rd_rsp (rg_state_dm == state_dm_rd_rsp);
      let control_rsp <- pop (soc_top.server_external_control.response.get);
      host_AXI4L_channels.v_to_host [hw_to_host_chan_debug_module].enq (truncate (control_rsp.result));
      rg_state_dm <= state_dm_idle;
      if (verbosity != 0)
	 $display ("AWSteria_HW.rl_control_to_DM_rd_rsp: data %0h", control_rsp.result);
   endrule


   rule rl_control_to_DM_wr_req (rg_state_dm == state_dm_wr_req);
      Bit #(32) data <- pop_o (host_AXI4L_channels.v_from_host [host_to_hw_chan_debug_module]);
      let control_req = Control_Req {op:   external_control_req_op_write_control_fabric,
				     arg1: zeroExtend (rg_dm_addr),
				     arg2: zeroExtend (data)};
      soc_top.server_external_control.request.put (control_req);
      rg_state_dm <= state_dm_idle;
      if (verbosity != 0)
	 $display ("AWSteria_HW.rl_control_to_DM_wr_req: dm_addr %0h data %0h", rg_dm_addr, data);
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
	 host_AXI4L_channels.v_to_host [hw_to_host_chan_pc_trace].enq (pc_trace.cycle [31:0]);
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
      host_AXI4L_channels.v_to_host [hw_to_host_chan_pc_trace].enq (rg_pc_trace.cycle [63:32]);
      rg_pc_trace_serialize_state <= 2;
   endrule

   rule rl_pc_trace_2 (rg_pc_trace_serialize_state == 2);
      host_AXI4L_channels.v_to_host [hw_to_host_chan_pc_trace].enq (rg_pc_trace.instret [31:0]);
      rg_pc_trace_serialize_state <= 3;
   endrule

   rule rl_pc_trace_3 (rg_pc_trace_serialize_state == 3);
      host_AXI4L_channels.v_to_host [hw_to_host_chan_pc_trace].enq (rg_pc_trace.instret [63:32]);
      rg_pc_trace_serialize_state <= 4;
   endrule

   rule rl_pc_trace_4 (rg_pc_trace_serialize_state == 4);
      host_AXI4L_channels.v_to_host [hw_to_host_chan_pc_trace].enq (rg_pc_trace.pc [31:0]);
      rg_pc_trace_serialize_state <= 5;
   endrule

   rule rl_pc_trace_5 (rg_pc_trace_serialize_state == 5);
      host_AXI4L_channels.v_to_host [hw_to_host_chan_pc_trace].enq (rg_pc_trace.pc [63:32]);
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
   // INTERFACE

   // Facing Host
   interface AXI4_Slave_IFC      host_AXI4_S  = soc_top.dma_server;
   interface AXI4_Lite_Slave_IFC host_AXI4L_S = axi4L_switch.v_from_masters [0];

   // Facing DDR
   interface AXI4_Master_IFC ddr_A_M = ddr_fabric.v_to_slaves [0];

`ifdef INCLUDE_DDR_B
   interface AXI4_Master_IFC ddr_B_M = ddr_fabric.v_to_slaves [1];
`endif

`ifdef INCLUDE_DDR_C
   interface AXI4_Master_IFC ddr_C_M = ddr_fabric.v_to_slaves [2];
`endif

`ifdef INCLUDE_DDR_D
   interface AXI4_Master_IFC ddr_D_M = ddr_fabric.v_to_slaves [3];
`endif

   // ================
   // Status signals

   // The AWSteria environment asserts this to inform the DUT that it is ready
   method Action m_env_ready (Bool env_ready);
      rg_ddr4_ready <= (env_ready ? '1 : 0);
   endmethod

   // The DUT asserts this to inform the AWSteria environment that it has "halted"
   method Bool m_halted;
      return rg_shutdown_received;
   endmethod

   // ================
   // Real-time counter (in AWS and VCU118: 4ns period, irrespective of DUT clock)

   method Action m_glcount (Bit #(64) glcount);
      noAction;
   endmethod
endmodule

// ================================================================

endpackage
