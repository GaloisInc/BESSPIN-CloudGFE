// Copyright (c) 2013-2020 Bluespec, Inc. All Rights Reserved.
// Author: Rishiyur S. Nikhil

package Top_HW_Side_Standalone;

// ================================================================
// mkTop_HW_Side is a top-level system for simulation.

//    This is a 'standalone' version that does not communicate with
//    any 'host side'.  It just primes the simulation with the initial
//    setup that the host would do, and handles UART I/O to the
//    terminal.

//    Set verbosity and logdelay
//    Set watch tohost
//    Set 'DDR4 loaded'

// mkMem_Model is a memory model.

// ================================================================
// BSV lib imports

import Vector       :: *;
import FIFOF        :: *;
import GetPut       :: *;
import ClientServer :: *;
import Connectable  :: *;

// ----------------
// BSV additional libs

import Cur_Cycle  :: *;
import GetPut_Aux :: *;
import Semi_FIFOF :: *;

// ================================================================
// Project imports

import TV_Info        :: *;

import AXI4_Types      :: *;
import AXI4_Lite_Types :: *;

import AWS_BSV_Top_Defs :: *;
import AWS_BSV_Top      :: *;
import AWS_DDR4_Model   :: *;

// Communication channel information
import AWS_OCL_Adapter :: *;

// C imports for UART input and output.
import C_Imports :: *;

// ================================================================
// Top-level module.
// Instantiates the SoC.
// Instantiates a memory model.

(* synthesize *)
module mkTop_HW_Side (Empty) ;

   // 0: quiet; 1: rules
   Integer verbosity = 0;

   Reg #(Bit #(16)) rg_state <- mkReg (0);

   // The top-level of the BSV code in the AWS CL
   AWS_BSV_Top_IFC  aws_BSV_top <- mkAWS_BSV_Top;

   // Stub out the DMA_PCIS interface (not used here; no 'host side')
   AXI4_16_64_512_0_Master_IFC  dma_pcis_master = dummy_AXI4_Master_ifc;
   mkConnection (dma_pcis_master, aws_BSV_top.dma_pcis_slave);

   // Transactor to connect to the OCL interface
   AXI4L_32_32_0_Master_Xactor_IFC  ocl_xactor <- mkAXI4_Lite_Master_Xactor;
   mkConnection (ocl_xactor.axi_side, aws_BSV_top.ocl_slave);

   // ----------------
   // Models for the four DDR4s

   // DDR4 A (cached mem access, incl. bursts)
   AXI4_16_64_512_0_Slave_IFC  ddr4_A <- mkAWS_DDR4_A_Model;
   mkConnection (aws_BSV_top.ddr4_A_master, ddr4_A);

   // DDR4 B (uncached mem access, no bursts)
   AXI4_16_64_512_0_Slave_IFC  ddr4_B <- mkAWS_DDR4_B_Model;
   mkConnection (aws_BSV_top.ddr4_B_master, ddr4_B);

   // DDR4 C (tie-off: unused for now)
   AXI4_16_64_512_0_Slave_IFC  ddr4_C <- mkAWS_DDR4_C_Model;
   mkConnection (aws_BSV_top.ddr4_C_master, ddr4_C);

   // DDR4 D (tie-off: unused for now)
   AXI4_16_64_512_0_Slave_IFC  ddr4_D <- mkAWS_DDR4_D_Model;
   mkConnection (aws_BSV_top.ddr4_D_master, ddr4_D);

   // ================================================================
   // Functions to simulate host-to/from-hw communication with
   // AWS_BSV_Top: AXI4L interactions over OCL
   // See comments in AWS_OCL_Adapter for encoding of AXI4L addrs and data
   // for multiple logical channels.

   function Action fa_chan_status_req (Bit #(32) addr_base, Integer chan);
      action
	 Bit #(32) araddr = (addr_base + (fromInteger (chan) << 3) + 4);
	 let rda = AXI4_Lite_Rd_Addr {araddr: araddr, arprot: 0, aruser: 0};
	 ocl_xactor.i_rd_addr.enq (rda);
      endaction
   endfunction

   function ActionValue #(Bool) fa_chan_status_rsp ();
      actionvalue
	 let rdd <- pop_o (ocl_xactor.o_rd_data);
	 return unpack (rdd.rdata [0]);
      endactionvalue
   endfunction

   function Action fa_chan_write (Integer chan, Bit #(32) data);
      action
	 // AXI4L-channel address
	 Bit #(32) addr = (ocl_host_to_hw_chan_addr_base + (fromInteger (chan) << 3));

	 let wra = AXI4_Lite_Wr_Addr {awaddr: addr, awprot: 0, awuser: 0};
	 ocl_xactor.i_wr_addr.enq (wra);

	 // AXI4L-channel data
	 let wrd = AXI4_Lite_Wr_Data {wdata: data, wstrb: '1};
	 ocl_xactor.i_wr_data.enq (wrd);
      endaction
   endfunction

   function Action fa_chan_read_req (Integer chan);
      action
	 // AXI4L-channel address
	 Bit #(32) araddr = (ocl_hw_to_host_chan_addr_base + (fromInteger (chan) << 3));

	 let rda = AXI4_Lite_Rd_Addr {araddr: araddr, arprot: 0, aruser: 0};
	 ocl_xactor.i_rd_addr.enq (rda);
      endaction
   endfunction

   function ActionValue #(Bit #(32)) fa_chan_read_rsp ();
      actionvalue
	 let rdd <- pop_o (ocl_xactor.o_rd_data);
	 return rdd.rdata;
      endactionvalue
   endfunction

   // ================================================================
   // BEHAVIOR

   rule rl_start (rg_state == 0);
      rg_state <= 10;
      $display ("================================================================");
      $display ("Bluespec AWSteria standalone simulation (no host) v1.0");
      $display ("Copyright (c) 2020 Bluespec, Inc. All Rights Reserved.");
      $display ("================================================================");
   endrule

   // ----------------
   // Set verbosity

   rule rl_set_verbosity_chan_status_req (rg_state == 10);
      rg_state <= 11;
      $display ("%0d: Top_HW_Side_Standalone.rl_set_verbosity_chan_status_req", cur_cycle);
      fa_chan_status_req (ocl_host_to_hw_chan_addr_base, host_to_hw_chan_control);
   endrule

   rule rl_set_verbosity (rg_state == 11);
      $display ("%0d: Top_HW_Side_Standalone.rl_set_verbosity", cur_cycle);
      let notFull <- fa_chan_status_rsp ();
      if (! notFull)
	 rg_state <= 10;
      else begin
	 rg_state <= 20;
	 Bit #(32) hs_syscontrol_tag_verbosity = 1;
	 Bit #(32) cpu_verbosity               = 0;
	 Bit #(32) logdelay                    = 0;
	 Bit #(32) command = ((logdelay << 24)                   // 24'h_log_delay
			      | (cpu_verbosity << 4)             // 4'h_verbosity
			      | hs_syscontrol_tag_verbosity);
	 fa_chan_write (host_to_hw_chan_control, command);
	 $display ("    command = %0h", command);
      end
   endrule

   // ----------------
   // Set watch tohost

   rule rl_set_watch_tohost_chan_status_req (rg_state == 20);
      rg_state <= 21;
      $display ("%0d: Top_HW_Side_Standalone.rl_set_watch_tohost_chan_status_req", cur_cycle);
      fa_chan_status_req (ocl_host_to_hw_chan_addr_base, host_to_hw_chan_control);
   endrule

   rule rl_set_watch_tohost (rg_state == 21);
      $display ("%0d: Top_HW_Side_Standalone.rl_set_watch_tohost", cur_cycle);
      let notFull <- fa_chan_status_rsp ();
      if (! notFull)
	 rg_state <= 20;
      else begin
	 rg_state <= 30;

	 Bit #(32) hs_syscontrol_tag_watch_tohost    = 3;
	 Bit #(32) hs_syscontrol_tag_no_watch_tohost = 2;
	 Bool      watch_tohost                      = True;
	 Bit #(32) tohost_addr                       = 'hbfff_f000;    // GFE SoC Map
	 // Bit #(32) tohost_addr  = 'h8000_1000;    // WindSoC SoC map

	 Bit #(32) command = 0;
	 $display ("%0d: Top_HW_Side_Standalone.rl_set_watch_tohost (first time))", cur_cycle);
	 if (watch_tohost) begin
	    command = (tohost_addr             // 29'h_to_host_addr_DW
		       | hs_syscontrol_tag_watch_tohost);
	    $display ("    Watch: tohost_addr = %0h (chan command: %0h)", tohost_addr, command);
	 end
	 else begin
	    command = (0                          // 28'h_0
		       | hs_syscontrol_tag_no_watch_tohost);
	    $display ("    No watch (chan command: %0h)", command);
	 end
	 fa_chan_write (host_to_hw_chan_control, command);
	 $display ("    command = %0h", command);
      end
   endrule

   // ----------------
   // Set DDR4-is-loaded

   rule rl_set_ddr4_is_loaded_chan_status_req (rg_state == 30);
      rg_state <= 31;
      $display ("%0d: Top_HW_Side_Standalone.rl_set_dd4_is_loaded_chan_status_req", cur_cycle);
      fa_chan_status_req (ocl_host_to_hw_chan_addr_base, host_to_hw_chan_control);
   endrule

   rule rl_set_dd4_is_loaded (rg_state == 31);
      $display ("%0d: Top_HW_Side_Standalone.rl_set_ddr4_is_loaded", cur_cycle);
      let notFull <- fa_chan_status_rsp ();
      if (! notFull)
	 rg_state <= 30;
      else begin
	 rg_state <= 100;
	 Bit #(32) hs_syscontrol_tag_ddr4_is_loaded = 0;
	 Bit #(32) command = (0                                       // 28'h_0
			      | hs_syscontrol_tag_ddr4_is_loaded);
	 fa_chan_write (host_to_hw_chan_control, command);
	 $display ("    command = %0h", command);
      end
   endrule

   // ----------------
   // End of startup sequence; this sequence loops

   Bit #(16) state_top_of_loop = 100;

   // ----------------
   // Get SoC status

   rule rl_get_SoC_Status_chan_status_req (rg_state == 100);
      rg_state <= 101;
      if (verbosity >= 1)
	 $display ("%0d: Top_HW_Side_Standalone.rl_get_SoC_Status_chan_status_req", cur_cycle);
      fa_chan_status_req (ocl_hw_to_host_chan_addr_base, hw_to_host_chan_status);
   endrule

   rule rl_get_SoC_Status_req (rg_state == 101);
      if (verbosity >= 1)
	 $display ("%0d: Top_HW_Side_Standalone.rl_get_SoC_Status_req", cur_cycle);

      let notEmpty <- fa_chan_status_rsp ();
      if (! notEmpty)
	 rg_state <= 110;
      else begin
	 rg_state <= 102;
	 fa_chan_read_req (hw_to_host_chan_status);
      end
   endrule

   rule rl_get_SoC_Status (rg_state == 102);
      rg_state <= 110;
      if (verbosity >= 1)
	 $display ("%0d: Top_HW_Side_Standalone.rl_get_SoC_Status", cur_cycle);
      let data <- fa_chan_read_rsp ();

      // Encoding: { 16'tohost_value,
      //             4'ddr4_ready, 2'b0, 1'ddr4_is_loaded, 1'initialized_2, 8'soc_status}
      Bit #(8)  soc_status     = data [7:0];
      Bit #(1)  hw_initialized = data [8];
      Bit #(1)  ddr4_is_loaded = data [9];
      Bit #(16) tohost_value   = data [31:16];

      if (soc_status != 0) begin
	 // Error termination signal from HW
	 $display ("%0d: Top_HW_Side_Standalone.rl_get_SoC_status", cur_cycle);

	 $display ("    soc_status (non-zero, ERROR): 0x%0h", soc_status);
	 $display ("    hw_initialized = %0d", hw_initialized);
	 $display ("    ddr4_is_loaded = %0d", ddr4_is_loaded);
	 $finish (1);
      end
      else if (tohost_value != 0) begin
         if (verbosity == 0)
	    $display ("%0d: Top_HW_Side_Standalone.rl_get_SoC_status", cur_cycle);
	 $display ("    tohost_value = 0x%0h", tohost_value);
	 Bit #(16) testnum = (tohost_value >> 1);
	 if (testnum == 0)
	    $display ("PASS");
	 else
	    $display ("FAIL on test %0d", testnum);
	 $finish (1);
      end
   endrule

   // ----------------
   // Get UART output (from RISC-V CPU to console)

   rule rl_get_UART_out_chan_status_req (rg_state == 110);
      rg_state <= 111;
      if (verbosity >= 1)
	 $display ("%0d: Top_HW_Side_Standalone.rl_get_UART_out_chan_status_req", cur_cycle);
      fa_chan_status_req (ocl_hw_to_host_chan_addr_base, host_to_hw_chan_UART);
   endrule

   rule rl_get_UART_out_req (rg_state == 111);
      if (verbosity >= 1)
	 $display ("%0d: Top_HW_Side_Standalone.rl_get_UART_out_req", cur_cycle);

      let notEmpty <- fa_chan_status_rsp ();
      if (! notEmpty)
	 rg_state <= 120;
      else begin
	 rg_state <= 112;
	 fa_chan_read_req (host_to_hw_chan_UART);
      end
   endrule

   rule rl_get_UART_out (rg_state == 112);
      rg_state <= 120;
      if (verbosity >= 1)
	 $display ("%0d: Top_HW_Side_Standalone.rl_get_UART_out", cur_cycle);
      let data <- fa_chan_read_rsp ();
      $write ("%c", data);
   endrule

   // ----------------
   // UART input (from console to RISC-V CPU)

   // rg_console_in_poll is used to poll only every N cycles, whenever it wraps around to 0.
   Reg   #(Bit #(12)) rg_keyboard_poll_delay <- mkReg (0);
   FIFOF #(Bit #(8))  f_UART_input_chars     <- mkFIFOF;

   rule rl_pending_UART_input (rg_state == 120);
      if (verbosity >= 1)
	 $display ("%0d: Top_HW_Side_Standalone.rl_pending_UART_input", cur_cycle);

      if (f_UART_input_chars.notEmpty) begin
	 fa_chan_status_req (ocl_host_to_hw_chan_addr_base, host_to_hw_chan_UART);
	 rg_state <= 121;
      end
      else if (rg_keyboard_poll_delay != 0) begin
	 // Not yet time to poll keyboard
	 rg_keyboard_poll_delay <= rg_keyboard_poll_delay - 1;
	 rg_state <= state_top_of_loop;
      end
      else begin
	 // Poll keyboard
	 Bit #(8) ch <- c_trygetchar (?);
	 if (ch != 0) begin
	    // Console char available; enqueue it for UART
	    f_UART_input_chars.enq (ch);
	    fa_chan_status_req (ocl_host_to_hw_chan_addr_base, host_to_hw_chan_UART);
	    rg_state <= 121;
	 end
	 else begin
	    rg_keyboard_poll_delay <= '1;
	    rg_state <= state_top_of_loop;
	 end
      end
   endrule

   rule rl_put_UART_input (rg_state == 121);
      rg_state <= state_top_of_loop;
      if (verbosity >= 1)
	 $display ("%0d: Top_HW_Side_Standalone.rl_put_UART_input", cur_cycle);
      let notFull <- fa_chan_status_rsp ();
      if (notFull) begin
	 let ch <- pop (f_UART_input_chars);
	 fa_chan_write (host_to_hw_chan_UART, zeroExtend (ch));
      end
   endrule

   // ----------------

   // Drain AXI4L wr responses
   rule rl_drain_ocl_wr_resp;
      let x1 <- pop_o (ocl_xactor.o_wr_resp);
   endrule
   
   // ================================================================
   // Misc. signals normally provided by SH/CL AWS top-level SystemVerilog
   //     ddr4 ready signals
   //     glcount0, glcount1 (4ns counters)
   //     vdip, vled (*)
   // TODO: (*) should have own channels to/from host in communication box

   Reg #(Bit #(64)) rg_counter_4ns <- mkReg (0);
   Reg #(Bit #(16)) rg_last_vled   <- mkReg (0);
   Reg #(Bit #(16)) rg_vdip        <- mkReg (0);

   rule rl_status_signals;
      // ---------------- gcounts (4ns counters)
      // Assume 100 MHZ, so counter should increase by 2.5 every tick.
      // For rg_counter_4ns, let binary point be to between bits [1] and [0].
      // So 2.5 is 'b_101
      aws_BSV_top.m_glcount0 (rg_counter_4ns >> 1);
      aws_BSV_top.m_glcount1 (rg_counter_4ns >> 1);
      rg_counter_4ns <= rg_counter_4ns + 'b_101;

      // ---------------- DDR ready
      aws_BSV_top.m_ddr4_ready ('1);

      // ---------------- VDIP
      aws_BSV_top.m_vdip (rg_vdip);

      // ---------------- VLED
      let vled = aws_BSV_top.m_vled;
      for (Integer j = 0; j < 16; j = j + 1)
	 if ((rg_last_vled [j] == 0) && (vled [j] == 1)) begin
	    if (verbosity != 0)
	       $display ("vled [%0d] turned on", j);
	 end
	 else if ((rg_last_vled [j] == 1) && (vled [j] == 0)) begin
	    if (verbosity != 0)
	       $display ("vled [%0d] turned off", j);
	 end
      rg_last_vled <= vled;
   endrule

   // ================================================================
   // INTERFACE

   //  None (this is top-level)

endmodule

// ================================================================

endpackage: Top_HW_Side_Standalone
