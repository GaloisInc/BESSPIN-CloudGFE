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
import Clocks       :: *;

// ----------------
// BSV additional libs

import Cur_Cycle  :: *;
import GetPut_Aux :: *;
import Semi_FIFOF :: *;

// ================================================================
// Project imports

import TV_Info        :: *;

import AXI4       :: *;
import AXI4Lite   :: *;
import SourceSink :: *;

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
   Clock  clk <- exposeCurrentClock();
   Reset rstn <- mkAsyncResetFromCR(5, clk);

   // 0: quiet; 1: rules
   Integer verbosity = 0;

   Reg #(Bit #(16)) rg_state <- mkReg (0, reset_by rstn);

   // If the default clock is nominally 250MHz at 10 Verilog time steps,
   // then period 26 is just under 100MHz:
   Clock core_clk  <- mkAbsoluteClock(0, 26, reset_by rstn);

   // The top-level of the BSV code in the AWS CL
   AWS_BSV_Top_IFC  aws_BSV_top <- mkAWS_BSV_Top (core_clk, reset_by rstn);

   // Stub out the DMA_PCIS interface (not used here; no 'host side')
   AXI4_Master_Synth #(14, 64, 512, 0, 0, 0, 0, 0)
     dma_pcis_master = culDeSac;//dummy_AXI4_Master_ifc;
   mkConnection (dma_pcis_master, aws_BSV_top.dma_pcis_slave, reset_by rstn);

   // Transactor to connect to the OCL interface
   AXI4Lite_Shim #(32, 32, 0, 0, 0, 0, 0)
     ocl_shim <- mkAXI4LiteShimFF (reset_by rstn);
   let tmp <- toUnguarded_AXI4Lite_Master (ocl_shim.master, reset_by rstn);
   let ocl_shim_masterSynth <- toAXI4Lite_Master_Synth ( tmp
                                                       , reset_by rstn);

   mkConnection (ocl_shim_masterSynth, aws_BSV_top.ocl_slave, reset_by rstn);

   // ----------------
   // Models for the four DDR4s

   /*
   // DDR4 A (cached mem access, incl. bursts)
   let ddr4_A <- mkAWS_DDR4_A_Model;
   mkConnection (aws_BSV_top.ddr4_A_master, ddr4_A, reset_by rstn);

   // DDR4 B (uncached mem access, no bursts)
   let ddr4_B <- mkAWS_DDR4_B_Model;
   mkConnection (aws_BSV_top.ddr4_B_master, ddr4_B, reset_by rstn);

   // DDR4 C (tie-off: unused for now)
   let ddr4_C <- mkAWS_DDR4_C_Model;
   mkConnection (aws_BSV_top.ddr4_C_master, ddr4_C, reset_by rstn);

   // DDR4 D (tie-off: unused for now)
   let ddr4_D <- mkAWS_DDR4_D_Model;
   mkConnection (aws_BSV_top.ddr4_D_master, ddr4_D, reset_by rstn);
   */
   AXI4_16_64_512_0_0_0_0_0_Slave_Synth ddr4_A <- mkMem_Model (0, reset_by rstn);
   AXI4_16_64_512_0_0_0_0_0_Slave_Synth ddr4_B <- mkMem_Model (1, reset_by rstn);
   AXI4_16_64_512_0_0_0_0_0_Slave_Synth ddr4_C <- mkMem_Model (2, reset_by rstn);
   AXI4_16_64_512_0_0_0_0_0_Slave_Synth ddr4_D <- mkMem_Model (3, reset_by rstn);

   // AXI4 Deburster in front of DDR4 A
   AXI4_Shim #(16, 64, 512, 0, 0, 0, 0, 0) ddr4_A_deburster <- mkBurstToNoBurst(reset_by rstn);
   let ddr4_A_deburster_Synth_master <- toAXI4_Master_Synth (ddr4_A_deburster.master, reset_by rstn);
   let ddr4_A_deburster_Synth_slave  <- toAXI4_Slave_Synth  (ddr4_A_deburster.slave, reset_by rstn);
   AXI4_Shim #(16, 64, 512, 0, 0, 0, 0, 0) ddr4_B_deburster <- mkBurstToNoBurst(reset_by rstn);
   let ddr4_B_deburster_Synth_master <- toAXI4_Master_Synth (ddr4_B_deburster.master, reset_by rstn);
   let ddr4_B_deburster_Synth_slave  <- toAXI4_Slave_Synth  (ddr4_B_deburster.slave, reset_by rstn);
   AXI4_Shim #(16, 64, 512, 0, 0, 0, 0, 0) ddr4_C_deburster <- mkBurstToNoBurst(reset_by rstn);
   let ddr4_C_deburster_Synth_master <- toAXI4_Master_Synth (ddr4_C_deburster.master, reset_by rstn);
   let ddr4_C_deburster_Synth_slave  <- toAXI4_Slave_Synth  (ddr4_C_deburster.slave, reset_by rstn);
   AXI4_Shim #(16, 64, 512, 0, 0, 0, 0, 0) ddr4_D_deburster <- mkBurstToNoBurst(reset_by rstn);
   let ddr4_D_deburster_Synth_master <- toAXI4_Master_Synth (ddr4_D_deburster.master, reset_by rstn);
   let ddr4_D_deburster_Synth_slave  <- toAXI4_Slave_Synth  (ddr4_D_deburster.slave, reset_by rstn);

   // Connect AWS_BSV_Top ddr ports to debursters
   mkConnection (aws_BSV_top.ddr4_A_master, ddr4_A_deburster_Synth_slave, reset_by rstn);
   mkConnection (aws_BSV_top.ddr4_B_master, ddr4_B_deburster_Synth_slave, reset_by rstn);
   mkConnection (aws_BSV_top.ddr4_C_master, ddr4_C_deburster_Synth_slave, reset_by rstn);
   mkConnection (aws_BSV_top.ddr4_D_master, ddr4_D_deburster_Synth_slave, reset_by rstn);

   // Connect debursters to DDR models
   mkConnection (ddr4_A_deburster_Synth_master, ddr4_A, reset_by rstn);
   mkConnection (ddr4_B_deburster_Synth_master, ddr4_B, reset_by rstn);
   mkConnection (ddr4_C_deburster_Synth_master, ddr4_C, reset_by rstn);
   mkConnection (ddr4_D_deburster_Synth_master, ddr4_D, reset_by rstn);

   // ================================================================
   // Functions to simulate host-to/from-hw communication with
   // AWS_BSV_Top: AXI4L interactions over OCL
   // See comments in AWS_OCL_Adapter for encoding of AXI4L addrs and data
   // for multiple logical channels.

   function Action fa_chan_status_req (Bit #(32) addr_base, Integer chan);
      action
	 Bit #(32) araddr = (addr_base + (fromInteger (chan) << 3) + 4);
	 let rda = AXI4Lite_ARFlit {araddr: araddr, arprot: 0, aruser: 0};
	 ocl_shim.slave.ar.put (rda);
      endaction
   endfunction

   function ActionValue #(Bool) fa_chan_status_rsp ();
      actionvalue
	 let rdd <- get (ocl_shim.slave.r);
	 return unpack (rdd.rdata [0]);
      endactionvalue
   endfunction

   function Action fa_chan_write (Integer chan, Bit #(32) data);
      action
	 // AXI4L-channel address
	 Bit #(32) addr = (ocl_host_to_hw_chan_addr_base + (fromInteger (chan) << 3));

	 let wra = AXI4Lite_AWFlit {awaddr: addr, awprot: 0, awuser: 0};
	 ocl_shim.slave.aw.put (wra);

	 // AXI4L-channel data
	 let wrd = AXI4Lite_WFlit {wdata: data, wstrb: '1};
	 ocl_shim.slave.w.put (wrd);
      endaction
   endfunction

   function Action fa_chan_read_req (Integer chan);
      action
	 // AXI4L-channel address
	 Bit #(32) araddr = (ocl_hw_to_host_chan_addr_base + (fromInteger (chan) << 3));

	 let rda = AXI4Lite_ARFlit {araddr: araddr, arprot: 0, aruser: 0};
	 ocl_shim.slave.ar.put (rda);
      endaction
   endfunction

   function ActionValue #(Bit #(32)) fa_chan_read_rsp ();
      actionvalue
	 let rdd <- get (ocl_shim.slave.r);
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
      let x1 <- get (ocl_shim.slave.b);
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
