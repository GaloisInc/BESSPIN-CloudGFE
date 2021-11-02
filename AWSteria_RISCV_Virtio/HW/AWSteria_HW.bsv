// Copyright (c) 2021 Bluespec, Inc.  All Rights Reserved.
// Author: Rishiyur S. Nikhil

package AWSteria_HW;

// ================================================================
// This package contains the AWSteria_RISCV_Virtio top-level
// which, in turn, fits into AWSteria_Infra, which requires:
//     module mkAWSteria_HW #(...) (AWSteria_HW_IFC #(...))

// ================================================================

export mkAWSteria_HW;

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

import AXI4_Types      :: *;
import AXI4_Fabric     :: *;
import AXI4_Lite_Types :: *;
import AXI4_Widener    :: *;
import AXI4_Deburster  :: *;

// ================================================================
// Project imports

import AWSteria_HW_IFC :: *;    // Top-level ifc of this module, from AWSteria_Infra

import SoC_Map :: *;    // For address map of MMIO IPs

// Fabrics in this module
import AXI_Param_Defs :: *;    // For AXi widths
import DDR_Fabric     :: *;
import MMIO_Fabric    :: *;

// Interrupts
import Interrupt_Defs :: *;

// AXI4L channelizer
import AXI4L_Channels :: *;

// Local MMIO devices
import Boot_ROM     :: *;
import UART_Model   :: *;
import MMIO_to_Host :: *;

// Debug Module
import DMI :: *;

// PC Trace output
import PC_Trace :: *;

// Tandem Verification output
import TV_Info   :: *;
import C_Imports :: *;    // TODO: Temporarily using C to write TV to file in simulation,
                          // need to write to DDR or to host.

// ----------------
// The RISC-V Core

import AWSteria_Core_IFC :: *;
import AWSteria_Core     :: *;

// ================================================================
// Ids of channels multiplexed on AXI4-Lite

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
module mkAWSteria_HW #(Clock b_CLK, Reset b_RST_N)
                     (AWSteria_HW_IFC #(AXI4_Slave_IFC #(AXI4_Wd_Id,
							 AXI4_Wd_Addr,
							 AXI4_Wd_Data_A,
							 AXI4_Wd_User),
					AXI4_Lite_Slave_IFC #(AXI4L_Wd_Addr,
							      AXI4L_Wd_Data,
							      AXI4L_Wd_User),
					AXI4_Master_IFC #(AXI4_Wd_Id,
							  AXI4_Wd_Addr,
							  AXI4_Wd_Data_A,
							  AXI4_Wd_User)));
   // 0: quiet    1: rules
   Integer verbosity      = 0;
   Integer verbosity_uart = 0;

   // TODO: fix up; c_CLK and c_RST_N should be inputs to this module
   Reset dm_reset <- exposeCurrentReset;
   Clock c_CLK    = b_CLK;
   Reset c_RST_N  = b_RST_N;

   SoC_Map_IFC soc_map <- mkSoC_Map;

   // ================================================================
   // Major state components

   // The Core containing RISC-V CPU, Debug Module, PLIC, CLINT, etc.
   AWSteria_Core_IFC_Specialized
   awsteria_core <- mkAWSteria_Core (dm_reset,           // reset for Debug Module
				     b_CLK, b_RST_N,     // extra clock b
				     c_CLK, c_RST_N);    // extra clock c

   // ----------------
   // MMIO Fabric
   MMIO_Fabric_IFC mmio_fabric <- mkMMIO_Fabric;
   // Deburster between AWSteria_Core and MMIO fabric
   AXI4_Deburster_IFC #(AXI4_Wd_Id,
			AXI4_Wd_Addr,
			AXI4_Wd_Data_B,
			AXI4_Wd_User)    mmio_axi4_deburster <- mkAXI4_Deburster_B;
   // Widener between MMIO fabric (64b) and DDR fabric (512b)
   AXI4_Widener_IFC #(AXI4_Wd_Id,
		      AXI4_Wd_Addr,
		      AXI4_Wd_Data_B,
		      AXI4_Wd_Data_A,
		      AXI4_Wd_User)    mmio_to_ddr_widener <- mkAXI4_Widener;

   // ----------------
   // AXI4-Lite channelizer
   AXI4L_Channels_IFC  axi4L_channels <- mkAXI4L_Channels;

   // ----------------
   // MMIO devices
   UART_IFC          uart0        <- mkUART;
   MMIO_to_Host_IFC  mmio_to_host <- mkMMIO_to_Host;
   Boot_ROM_IFC      boot_rom     <- mkBoot_ROM;

   // ----------------
   // DDR fabric
   DDR_Fabric_IFC ddr_fabric <- mkDDR_Fabric;

   // ----------------
   // AWSteria_Infra signal that it is ready
   // TODO: use this to gate activity
   Reg #(Bool) rg_env_ready      <- mkReg (False);

   // ================================================================
   // Major connections

   // ----------------
   // AWSteria_Core Mem ifc to DDR fabric
   mkConnection (awsteria_core.mem_M, ddr_fabric.v_from_masters [0]);

   // ----------------
   // AWSteria_Core MMIO ifc to MMIO deburster
   mkConnection (awsteria_core.mmio_M,
		 mmio_axi4_deburster.from_master);

   // MMIO deburster to MMIO fabric
   mkConnection (mmio_axi4_deburster.to_slave,
		 mmio_fabric.v_from_masters [core_initiator_num]);

   // MMIO fabric to UART0
   mkConnection (mmio_fabric.v_to_slaves [uart16550_0_target_num],  uart0.slave);
   // MMIO fabric to Boot ROM
   mkConnection (mmio_fabric.v_to_slaves [boot_rom_target_num], boot_rom.slave);
   // MMIO fabric to MMIO Host Access
   mkConnection (mmio_fabric.v_to_slaves [host_access_target_num], mmio_to_host.axi4_S);
   // MMIO fabric to widener
   mkConnection (mmio_fabric.v_to_slaves [ddr4_0_uncached_target_num],
		 mmio_to_ddr_widener.from_master);
   // Widner to DDR fabric
   mkConnection (mmio_to_ddr_widener.to_slave, ddr_fabric.v_from_masters [1]);

   // ================================================================
   // Connect AXI4L Control/Status channels to core

   mkConnection (axi4L_channels.v_from_host [host_to_hw_chan_control],
		 awsteria_core.se_control_status.request);

   mkConnection (awsteria_core.se_control_status.response,
		 axi4L_channels.v_to_host [hw_to_host_chan_status]);

   // ================================================================
   // Connect AXI4L UART channels to UART

   // ----------------
   // keyboard to UART

   rule rl_console_to_UART;
      Bit #(32) ch <- pop_o (axi4L_channels.v_from_host [host_to_hw_chan_UART]);
      uart0.put_from_console.put (truncate (ch));

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
      axi4L_channels.v_to_host [hw_to_host_chan_UART].enq (x);
   endrule

   // The following are for accumulating chars into 4-char chunks

   Reg #(Bit #(32)) rg_uart_buf <- mkReg (0);
   Reg #(Bit #(16)) rg_uart_timeout  <- mkReg (0);
   Bit #(16)        uart_timeout_max = 'h2000;

   rule rl_UART_to_console_accum;
      let ch <- uart0.get_to_console.get;
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

   (* descending_urgency = "rl_UART_to_console,       rl_UART_timeout" *)
   (* descending_urgency = "rl_UART_to_console_accum, rl_UART_timeout" *)
   rule rl_UART_timeout (rg_uart_buf != 0);
      Bit #(32) buf_val = rg_uart_buf;
      if (rg_uart_timeout == 0) begin
	 axi4L_channels.v_to_host [hw_to_host_chan_UART].enq (buf_val);
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
   // Connect AXI4L MMIO-host-access channels to MMIO-to-host IP

   rule rl_hw_to_aws_host_mem_req;
      Bit #(32) x <- mmio_to_host.to_aws_host.get;
      axi4L_channels.v_to_host [hw_to_host_chan_mem_req].enq (x);

      if (verbosity > 0)
	 $display ("%0d: AWSteria_HW.rl_hw_to_aws_host_mem_req: %02h", cur_cycle, x);
   endrule

   rule rl_aws_host_to_hw_mem_rsp;
      Bit #(32) x <- pop_o (axi4L_channels.v_from_host [host_to_hw_chan_mem_rsp]);
      mmio_to_host.from_aws_host.put (x);

      if (verbosity > 0)
	 $display ("%0d: AWSteria_HW.rl_aws_host_to_hw_mem_rsp: %02h", cur_cycle, x);
   endrule

   // ================================================================
   // Connect AXI4L DMI Channels to AWSteria_Core
   // First word [31:24] specifies rd or wr; lsbs specify DM address
   // If write, second word specifies DMI write-data

   Bit #(2) state_dm_idle   = 0;
   Bit #(2) state_dm_rd_rsp = 1;
   Bit #(2) state_dm_wr_req = 2;

   Reg #(Bit #(2)) rg_state_dm <- mkReg (state_dm_idle);
   Reg #(Bit #(7)) rg_dm_addr  <- mkRegU;

   rule rl_control_to_DM_idle (rg_state_dm == state_dm_idle);
      // First word from AXI4L channel
      Bit #(32) x <- pop_o (axi4L_channels.v_from_host [host_to_hw_chan_debug_module]);
      Bool     is_read = (x [31:24] == 0);
      Bit #(7) dm_addr = truncate (x);

      if (is_read) begin
	 let dmi_req = DMI_Req {is_read: True, addr: dm_addr, wdata: ?};
	 awsteria_core.se_dmi.request.enq (dmi_req);
	 rg_state_dm <= state_dm_rd_rsp;
	 if (verbosity != 0)
	    $display ("AWSteria_HW.rl_control_to_DM_idle: read request: dm_addr %0h",
		      dm_addr);
      end
      else begin
	 rg_dm_addr  <= dm_addr;
	 rg_state_dm <= state_dm_wr_req;
      end
   endrule

   rule rl_control_to_DM_wr_req (rg_state_dm == state_dm_wr_req);
      // Second word from AXI4L channel
      Bit #(32) data <- pop_o (axi4L_channels.v_from_host [host_to_hw_chan_debug_module]);
      let dmi_req = DMI_Req {is_read: False,
			     addr:    zeroExtend (rg_dm_addr),
			     wdata:   zeroExtend (data)};
      awsteria_core.se_dmi.request.enq (dmi_req);
      rg_state_dm <= state_dm_idle;
      if (verbosity != 0)
	 $display ("AWSteria_HW.rl_control_to_DM_wr_req: dm_addr %0h data %0h",
		   rg_dm_addr, data);
   endrule

   rule rl_DM_rd_rsp (rg_state_dm == state_dm_rd_rsp);
      DMI_Rsp dmi_rsp <- pop_o (awsteria_core.se_dmi.response);
      axi4L_channels.v_to_host [hw_to_host_chan_debug_module].enq (dmi_rsp.rdata);
      rg_state_dm <= state_dm_idle;
      if (verbosity != 0)
	 $display ("%0d: %m.rl_DM_rd_rsp: data %0h", fshow (dmi_rsp));
   endrule

   // ================================================================
   // Connect AXI4L PC Trace Channel to AWSteria_Core
   // Serialize each PC_Trace struct into 32-bit words sent to host

   Reg #(Bit #(3))   rg_pc_trace_serialize_state <- mkReg (0);
   Reg #(PC_Trace)   rg_pc_trace                 <- mkRegU;

   rule rl_pc_trace_0 (rg_pc_trace_serialize_state == 0);
      PC_Trace pc_trace <- pop_o (awsteria_core.fo_pc_trace);

      // Send sample to host (in next few rules)
      axi4L_channels.v_to_host [hw_to_host_chan_pc_trace].enq (pc_trace.cycle [31:0]);
      rg_pc_trace                 <= pc_trace;
      rg_pc_trace_serialize_state <= 1;
      $display ("PC Trace: cycle %0d  instret %0d  pc %0h (sending)",
		pc_trace.cycle, pc_trace.instret, pc_trace.pc);
   endrule

   rule rl_pc_trace_1 (rg_pc_trace_serialize_state == 1);
      axi4L_channels.v_to_host [hw_to_host_chan_pc_trace].enq (rg_pc_trace.cycle [63:32]);
      rg_pc_trace_serialize_state <= 2;
   endrule

   rule rl_pc_trace_2 (rg_pc_trace_serialize_state == 2);
      axi4L_channels.v_to_host [hw_to_host_chan_pc_trace].enq (rg_pc_trace.instret [31:0]);
      rg_pc_trace_serialize_state <= 3;
   endrule

   rule rl_pc_trace_3 (rg_pc_trace_serialize_state == 3);
      axi4L_channels.v_to_host [hw_to_host_chan_pc_trace].enq (rg_pc_trace.instret [63:32]);
      rg_pc_trace_serialize_state <= 4;
   endrule

   rule rl_pc_trace_4 (rg_pc_trace_serialize_state == 4);
      axi4L_channels.v_to_host [hw_to_host_chan_pc_trace].enq (rg_pc_trace.pc [31:0]);
      rg_pc_trace_serialize_state <= 5;
   endrule

   rule rl_pc_trace_5 (rg_pc_trace_serialize_state == 5);
      axi4L_channels.v_to_host [hw_to_host_chan_pc_trace].enq (rg_pc_trace.pc [63:32]);
      rg_pc_trace_serialize_state <= 0;
   endrule

   // ****************************************************************
   // Interrupt connections to core

   // ----------------
   // UART interrupt
   Reg #(Bool) rg_uart_intr_last <- mkReg (False);

   rule rl_connect_external_interrupt_requests;
      Bool intr = uart0.intr;

      // Posedge
      if (intr && (! rg_uart_intr_last))
	 awsteria_core.v_fi_external_interrupt_reqs [irq_num_uart16550_0].enq (True);

      // Negedge
      else if ((! intr) && rg_uart_intr_last)
	 awsteria_core.v_fi_external_interrupt_reqs [irq_num_uart16550_0].enq (False);

      rg_uart_intr_last <= intr;
   endrule

   // ----------------
   // Connect Host AXI4L Channels host-to-hw interrupt line
   rule rl_host_to_hw_interrupt;
      Bit #(32) x <- pop_o (axi4L_channels.v_from_host [host_to_hw_chan_interrupt]);
      Bool      irq_set = unpack (x [31]);
      Bit #(4)  irq_num = x [3:0];    // Virtio device's interrupt numbering

      if (verbosity > 0) begin
	 $display ("%0d: %m.rl_host_to_hw_interrupt: %08h", cur_cycle, x);
	 $display ("    irq_num %02d  irq_set %02d", irq_num, irq_set);
      end

      case (irq_num)
	 1: awsteria_core.v_fi_external_interrupt_reqs [irq_num_host_to_hw_1].enq (irq_set);
	 2: awsteria_core.v_fi_external_interrupt_reqs [irq_num_host_to_hw_2].enq (irq_set);
	 3: awsteria_core.v_fi_external_interrupt_reqs [irq_num_host_to_hw_3].enq (irq_set);
	 4: awsteria_core.v_fi_external_interrupt_reqs [irq_num_host_to_hw_4].enq (irq_set);
	 default: begin
		     $display ("%0d: ERROR: %m.rl_host_to_hw_interrupt: ", cur_cycle);
		     $display ("    Unsupported irq_num %0d (irq_set = %0d)",
			       irq_num, irq_set);
		  end
      endcase
   endrule

   // ================================================================
   // Connect non-maskable interrupt request to core

   // TODO: nothing for the moment

   // ****************************************************************
   // Tandem verifier: drain and output vectors of bytes
   // TODO: Temporarily using C to write TV to file in simulation,
   //       need to write to DDR or to host.
   // ifdefs here are because imported C functions are only valid in simulation.

`ifdef INCLUDE_TANDEM_VERIF
   Reg #(Bool) rg_tv_file_opened <- mkReg (False);

   rule rl_open_tv_file ((! rg_tv_file_opened))
      $display ("%0d: %m.rl_open_tv_file", cur_cycle);

      // Open file for Tandem Verification trace output
      let success <- c_trace_file_open ('h_AA);
      if (success == 0) begin
	 $display ("    ERROR: Top_HW_Side.rl_step0: error opening TV trace file.");
	 $display ("    Aborting.");
	 $finish (1);
      end
      else
	 $display ("    opened TV trace file.");

      rg_tv_file_opened <= True;
   endrule

   // Write out TV info to file

   rule rl_tv_vb_out;
      let tv_info <- pop_o (awsteria_core.fo_tv_info);
      let n  = tv_info.num_bytes;
      let vb = tv_info.vec_bytes;

      Bit #(32) success = 1;

      for (Bit #(32) j = 0; j < fromInteger (valueOf (TV_VB_SIZE)); j = j + 8) begin
	 Bit #(64) w64 = {vb [j+7], vb [j+6], vb [j+5], vb [j+4],
			  vb [j+3], vb [j+2], vb [j+1], vb [j] };
	 let success1 <- c_trace_file_load_word64_in_buffer (j, w64);
	 success = (success & success1);
      end

      if (success == 0) begin
	 $display ("ERROR: %m.rl_tv_vb_out: error loading %0d bytes into buffer", n);
	 $finish (1);
      end
      else begin
	 // Send the data
	 success <- c_trace_file_write_buffer (n);
	 if (success == 0)
	    $display ("ERROR: %m.rl_tv_vb_out: error writing bytevec data buffer (%0d bytes)", n);
      end
   endrule
`endif

   // ****************************************************************
   // NDM Reset (non-debug-module reset)

   // TODO: ignored for now

   // ****************************************************************
   // Initializations

   Reg #(Bit #(2)) rg_init_state <- mkReg (0);

   rule rl_initialize (rg_init_state == 0);
      uart0.server_reset.request.put (?);
      mmio_fabric.reset;

      // Initialize address maps of IPs
      boot_rom.set_addr_map (soc_map.m_boot_rom_addr_base,
			     soc_map.m_boot_rom_addr_lim);

      uart0.set_addr_map (soc_map.m_uart16550_0_addr_base,
			  soc_map.m_uart16550_0_addr_lim);

      rg_init_state <= 1;

      if (verbosity != 0) begin
	 $display ("  SoC address map:");
	 $display ("  Boot ROM:        0x%0h .. 0x%0h",
		   soc_map.m_boot_rom_addr_base,
		   soc_map.m_boot_rom_addr_lim);
	 $display ("  UART0:           0x%0h .. 0x%0h",
		   soc_map.m_uart16550_0_addr_base,
		   soc_map.m_uart16550_0_addr_lim);
	 $display ("  Host Access      0x%0h .. 0x%0h",
		   soc_map.m_host_access_addr_base,
		   soc_map.m_host_access_addr_lim);
      end
   endrule

   rule rl_init_complete (rg_init_state == 1);
      let uart0_rsp <- uart0.server_reset.response.get;
      rg_init_state <= 2;
   endrule

   // ****************************************************************
   // INTERFACE

   // Facing Host
   interface AXI4_Slave_IFC      host_AXI4_S  = awsteria_core.dma_S;
   interface AXI4_Lite_Slave_IFC host_AXI4L_S = axi4L_channels.axi4L_S;

   // Facing DDR
`ifdef INCLUDE_DDR_B
   interface AXI4_Master_IFC ddr_A_M = ddr_fabric.v_to_slaves [0];
`endif

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
      rg_env_ready <= env_ready;
   endmethod

   // The DUT asserts this to inform the AWSteria environment that it has "halted"
   method Bool m_halted;
      return False;    // TODO: do something useful here?
   endmethod

   // ================
   // Real-time counter (in AWS and VCU118: 4ns period, irrespective of DUT clock)

   method Action m_glcount (Bit #(64) glcount);
      noAction;    // TODO: do something useful here?
   endmethod
endmodule

// ****************************************************************
// Specialization of parameterized AXI4 Deburster

(* synthesize *)
module mkAXI4_Deburster_B (AXI4_Deburster_IFC #(AXI4_Wd_Id,
						AXI4_Wd_Addr,
						AXI4_Wd_Data_B,
						AXI4_Wd_User));
   let m <- mkAXI4_Deburster;
   return m;
endmodule

// ================================================================

endpackage
