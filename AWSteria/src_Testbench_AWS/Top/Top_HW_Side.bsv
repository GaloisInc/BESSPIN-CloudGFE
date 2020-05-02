// Copyright (c) 2013-2020 Bluespec, Inc. All Rights Reserved.
// Author: Rishiyur S. Nikhil

package Top_HW_Side;

// ================================================================
// mkTop_HW_Side is the top-level system for simulation.
// mkMem_Model is a memory model.

// ================================================================
// BSV lib imports

import FIFOF        :: *;
import GetPut       :: *;
import ClientServer :: *;
import Connectable  :: *;
import StmtFSM      :: *;

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

import C_Imports        :: *;

// ================================================================
// Top-level module.
// Instantiates the SoC.
// Instantiates a memory model.

(* synthesize *)
module mkTop_HW_Side (Empty) ;

   // 0: quiet; 1: rules
   Integer verbosity = 0;

   // Transactor to talk to the AWS OCL ports
   AXI4L_32_32_0_Master_Xactor_IFC     ocl_xactor      <- mkAXI4_Lite_Master_Xactor;

   // Transactor to talk to the AWS DMA_PCIS port
   AXI4_16_64_512_0_Master_Xactor_IFC  dma_pcis_xactor <- mkAXI4_Master_Xactor;

   // The top-level of the BSV code in the AWS CL
   AWS_BSV_Top_IFC  aws_BSV_top <- mkAWS_BSV_Top;

   AXI4_16_64_512_0_Slave_IFC  ddr4_A <- mkMem_Model (0);
   AXI4_16_64_512_0_Slave_IFC  ddr4_B <- mkMem_Model (1);
   AXI4_16_64_512_0_Slave_IFC  ddr4_C <- mkMem_Model (2);
   AXI4_16_64_512_0_Slave_IFC  ddr4_D <- mkMem_Model (3);

   // Connect OCL and DMA_PCIS transactors to AWS_BSV_Top
   mkConnection (ocl_xactor.axi_side,      aws_BSV_top.ocl_slave);
   mkConnection (dma_pcis_xactor.axi_side, aws_BSV_top.dma_pcis_slave);

   // Connect memory models to AWS_BSV_Top
   mkConnection (aws_BSV_top.ddr4_A_master, ddr4_A);
   mkConnection (aws_BSV_top.ddr4_B_master, ddr4_B);
   mkConnection (aws_BSV_top.ddr4_C_master, ddr4_C);
   mkConnection (aws_BSV_top.ddr4_D_master, ddr4_D);

   Reg #(Bool) rg_running <- mkRegU;

   // ================================================================
   // Misc. signals: ddr4 ready signals, 4ns counters, vdip, vled

   Reg #(Bit #(64)) rg_counter_4ns <- mkReg (0);
   Reg #(Bit #(16)) rg_last_vled   <- mkReg (0);
   Reg #(Bit #(16)) rg_vdip        <- mkReg (0);

   rule rl_status_signals;
      // ---------------- gcounts
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
   // Clients that share the Master side of the OCL connections:
   // WARNING: Should match defs in AWS_OCL_Adapter.bsv

   Integer ocl_client_control  = 1;
   Integer ocl_client_UART     = 2;
   Integer ocl_client_debugger = 3;

   Integer control_addr_verbosity   = 'h4;
   Integer control_addr_tohost      = 'h8;
   Integer control_addr_ddr4_loaded = 'hc;

   // ================================================================
   // BEHAVIOR

   function Action fa_ocl_control_write (Bit #(16) control_addr, Bit #(32) ocl_data);
      action
	 Bit #(32) ocl_addr = { fromInteger (ocl_client_control), control_addr };
	 let wra = AXI4_Lite_Wr_Addr {awaddr: ocl_addr, awprot: 0, awuser: ?};
	 let wrd = AXI4_Lite_Wr_Data {wdata:  ocl_data,   wstrb: '1};
	 ocl_xactor.i_wr_addr.enq (wra);
	 ocl_xactor.i_wr_data.enq (wrd);

	 if (verbosity != 0)
	    $display ("Top_HW_Side.fa_ocl_write: addr %0h data %0h", ocl_addr, ocl_data);
      endaction
   endfunction

   function Action fa_ocl_control_read_req (Bit #(16) control_addr);
      action
	 Bit #(32) ocl_addr = { fromInteger (ocl_client_control), control_addr };
	 let rda = AXI4_Lite_Rd_Addr {araddr: ocl_addr, arprot: 0, aruser: ?};
	 ocl_xactor.i_rd_addr.enq (rda);

	 if (verbosity != 0)
	    $display ("Top_HW_Side.fa_ocl_read_req: addr %0h", ocl_addr);
      endaction
   endfunction

   function ActionValue #(Bit #(32)) fav_ocl_control_read_rsp;
      actionvalue
	 let rdr <- pop_o (ocl_xactor.o_rd_data);
	 return rdr.rdata;
      endactionvalue
   endfunction

   FSM fsm <- mkFSM (
      seq
	 action
	    $display ("================================================================");
	    $display ("Bluespec RISC-V + WindSoC AWS simulation v1.0");
	    $display ("Copyright (c) 2017-2020 Bluespec, Inc. All Rights Reserved.");
	    $display ("================================================================");
	 endaction

	 // Set CPU verbosity and logdelay (simulation only)
	 action
	    Bool v1 <- $test$plusargs ("v1");
	    Bool v2 <- $test$plusargs ("v2");
	    Bit #(32)  verbosity = ((v2 ? 2 : (v1 ? 1 : 0)));
	    Bit #(32) logdelay  = 0;    // # of instructions after which to set verbosity
	    Bit #(32) data      = ((logdelay & 32'h_FFFF_FFF0) | (verbosity & 32'h_F));
	    $display ("Top_HW_Side: verbosity = %0d, logdelay = 0x%0h", verbosity, logdelay);
	    fa_ocl_control_write (fromInteger (control_addr_verbosity), data);
	 endaction

	 // Load tohost addr from symbol-table file 'symbol_table.txt'
	 action
	    Bool      watch_tohost <- $test$plusargs ("tohost");
	    Bit #(32) tohost_addr  = 1;    // Convention: misaligned if not watching tohost
	    if (watch_tohost) begin
	       Bit #(64) x <- c_get_symbol_val ("tohost");
	       tohost_addr  = truncate (x);
	    end
	    $display ("Top_HW_Side: watch_tohost = %0d, tohost_addr = 0x%0h",
		      pack (watch_tohost), tohost_addr);
	    fa_ocl_control_write (fromInteger (control_addr_tohost),
				  tohost_addr);
	 endaction

	 // Load memory
	 action
	    $display ("Top_HW_Side: Top_HW_Side: load DDR4 (TODO); for now, delay 10000 ticks");
	 endaction
	 delay (10000);
	 $display ("Top_HW_Side: Top_HW_Side: finished delay 10000 ticks");

	 // Go!
	 action
	    // Start timing the simulation
	    Bit #(32) cycle_num <- cur_cycle;
	    c_start_timing (zeroExtend (cycle_num));

	    // ----------------
	    // Declare  'DDR4 has been loaded'
	    fa_ocl_control_write (fromInteger (control_addr_ddr4_loaded), 0);
	 endaction

	 $display ("Top_HW_Side: polling remote counter");
	 rg_running <= True;
	 while (rg_running) seq
	    fa_ocl_control_read_req (0);
	    action
	       let x <- fav_ocl_control_read_rsp;
	       rg_running <= (x < 100000);
	    endaction
	 endseq
	 $display ("Top_HW_Side: remote counter exceeded limit");
	 $finish (0);
      endseq);

   Reg #(Bool) rg_done_once <- mkReg (False);
   rule rl_once (! rg_done_once);
      fsm.start;
      rg_done_once <= True;
   endrule


   // THE FOLLOWING ARE FOR FUTURE INCLUSION
`ifdef INCLUDE_GDB_CONTROL
      // ----------------
      // Open connection to remote debug client
      let dmi_status <- c_debug_client_connect (dmi_default_tcp_port);
      if (dmi_status != dmi_status_ok) begin
	 $display ("ERROR: Top_HW_Side.rl_step0: error opening debug client connection.");
	 $display ("    Aborting.");
	 $finish (1);
      end
`endif

`ifdef INCLUDE_TANDEM_VERIF
      // ----------------
      // Open file for Tandem Verification trace output
      let success <- c_trace_file_open ('h_AA);
      if (success == 0) begin
	 $display ("ERROR: Top_HW_Side.rl_step0: error opening trace file.");
	 $display ("    Aborting.");
	 $finish (1);
      end
      else
	 $display ("Top_HW_Side.rl_step0: opened trace file.");
`endif

   // ================================================================
   // Discard OCL write reponses, just checking for errors.

   rule rl_ocl_wr_response_drain;
      let wrr <- pop_o (ocl_xactor.o_wr_resp);

      if (wrr.bresp != AXI4_LITE_OKAY) begin
	 $display ("Top_HW_Side: OCL response error: ", fshow (wrr.bresp));
	 $finish (1);
      end
      else begin
	 if (verbosity != 0)
	    $display ("Top_HW_Side.rl_ocl_wr_response_drain: ", fshow (wrr));
      end
   endrule

   // ================================================================
   // UART console I/O

   /* TODO: fix up to talk over AWS OCL
   // Relay system console output to terminal

   rule rl_relay_console_out;
      let ch <- soc_top.get_to_console.get;
      $write ("%c", ch);
      $fflush (stdout);
   endrule

   // Poll terminal input and relay any chars into system console input.
   // Note: rg_console_in_poll is used to poll only every N cycles, whenever it wraps around to 0.

   Reg #(Bit #(12)) rg_console_in_poll <- mkReg (0);

   rule rl_relay_console_in;
      if (rg_console_in_poll == 0) begin
	 Bit #(8) ch <- c_trygetchar (?);
	 if (ch != 0) begin
	    soc_top.put_from_console.put (ch);
	    // $write ("%0d: Top_HW_Side.bsv.rl_relay_console: ch = 0x%0h", cur_cycle, ch);
	    // if (ch >= 'h20) $write (" ('%c')", ch);
	    // $display ("");
	 end
      end
      rg_console_in_poll <= rg_console_in_poll + 1;
   endrule
   */

   // ================================================================
   // Terminate on any non-zero status

   /* TODO: change this to use AWS SH/CL mechanisms
   rule rl_terminate (soc_top.status != 0);
      $display ("%0d: %m:.rl_terminate: soc_top status is 0x%0h (= 0d%0d)",
		cur_cycle, soc_top.status, soc_top.status);

      // End timing the simulation
      Bit #(32) cycle_num <- cur_cycle;
      c_end_timing (zeroExtend (cycle_num));
      $finish (0);
   endrule
   */

   // ================================================================
   // Interaction with remote debug client

`ifdef INCLUDE_GDB_CONTROL
   rule rl_debugger_request;
      Bit #(64) req <- c_debug_client_request_recv ('hAA);    // from Debugger over network connection
      Bit #(8)  status  = req [63:56];
      Bit #(32) data    = req [55:24];
      Bit #(16) dm_addr = req [23:8];
      Bit #(8)  op      = req [7:0];

      // Construct OCL addr: 'debugger' id in upper 16b, DM addr in lower 16b
      Bit #(32) ocl_addr = { fromInteger (ocl_client_debugger), (dm_addr << 2) };

      if (status == dmi_status_err) begin
	 $display ("%0d: Top_HW_Side.rl_debugger_request: receive error; aborting",
		   cur_cycle);
	 $finish (1);
      end
      else if (status == dmi_status_ok) begin
	 if (verbosity != 0)
	    $display ("%0d: Top_HW_Side.rl_debugger_request:", cur_cycle);

	 if (op == dmi_op_read) begin
	    if (verbosity != 0)
	       $display ("Top_HW_Side.rl_debugger_request: OCL READ dm_addr %0h (OCL addr %0h)",
			 dm_addr, ocl_addr);
	    let rda = AXI4_Lite_Rd_Addr {araddr: ocl_addr, arprot: 0, aruser: ?};
	    ocl_xactor.i_rd_addr.enq (rda);
	 end

	 else if (op == dmi_op_write) begin
	    if (verbosity != 0)
	       $display ("Top_HW_Side.rl_debugger_request: OCL WRITE dm_addr %0h (OCL addr %0h) data %0h",
			 dm_addr, ocl_addr, data);
	    let wra = AXI4_Lite_Wr_Addr {awaddr: ocl_addr, awprot: 0, awuser: ?};
	    let wrd = AXI4_Lite_Wr_Data {wdata:  data,   wstrb: '1};
	    ocl_xactor.i_wr_addr.enq (wra);
	    ocl_xactor.i_wr_data.enq (wrd);
	 end

	 else if (op == dmi_op_shutdown) begin
	    $display ("Top_HW_Side.rl_debugger_request: SHUTDOWN");

	    // End timing the simulation and print simulation speed stats
	    Bit #(32) cycle_num <- cur_cycle;
	    c_end_timing (zeroExtend (cycle_num));
	    $finish (0);
	 end
	 else if (op == dmi_op_start_command) begin    // For debugging only
	    if (verbosity != 0)
	       $display ("Top_HW_Side.rl_debugger_request: START COMMAND ================");
	 end
	 else begin
	    if (verbosity != 0)
	       $display (" Top_HW_Side.rl_debugger_request: UNRECOGNIZED OP %0d; ignoring", op);
	 end
      end
   endrule

   rule rl_ocl_rd_response;
      let rdr <- pop_o (ocl_xactor.o_rd_data);
      if (verbosity != 0)
	 $display ("Top_HW_Side.rl_ocl_rd_response: ", fshow (rdr));

      // TODO: triage UART response here; for now, only from debug module
      let status <- c_debug_client_response_send (truncate (rdr.rdata));
      if (status == dmi_status_err) begin
	 $display ("%0d: Top_HW_Side.rl_ocl_rd_response: send error; aborting",
		   cur_cycle);
	 $finish (1);
      end
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
      end

      if (success == 0)
	 $display ("ERROR: Top_HW_Side.rl_tv_vb_out: error loading %0d bytes into buffer", n);
      else begin
	 // Send the data
	 success <- c_trace_file_write_buffer (n);
	 if (success == 0)
	    $display ("ERROR: Top_HW_Side.rl_tv_vb_out: error writing out bytevec data buffer (%0d bytes)", n);
      end

      if (success == 0) begin
	 $finish (1);
      end
   endrule
`endif

   // ================================================================
   // INTERFACE

   //  None (this is top-level)

endmodule

// ================================================================

endpackage: Top_HW_Side
