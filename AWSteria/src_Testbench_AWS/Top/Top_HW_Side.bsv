// Copyright (c) 2013-2020 Bluespec, Inc. All Rights Reserved.
// Author: Rishiyur S. Nikhil

package Top_HW_Side;

// ================================================================
// mkTop_HW_Side is the top-level system for simulation.
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

// Communication with host
import Bytevec   :: *;
import C_Imports :: *;

// ================================================================
// Top-level module.
// Instantiates the SoC.
// Instantiates a memory model.

typedef enum { STATE_CONNECTING, STATE_CONNECTED, STATE_RUNNING } State
deriving (Eq, Bits, FShow);

(* synthesize *)
module mkTop_HW_Side (Empty) ;
   Clock  clk <- exposeCurrentClock();
   Reset rstn <- mkAsyncResetFromCR(5, clk);

   // 0: quiet; 1: rules
   Integer verbosity = 1;

   Reg #(State) rg_state <- mkReg (STATE_CONNECTING, reset_by rstn);

   // If the default clock is nominally 250MHz at 10 Verilog time steps,
   // then period 26 is just under 100MHz:
   Clock core_clk  <- mkAbsoluteClock(0, 26, reset_by rstn);

   // The top-level of the BSV code in the AWS CL
   AWS_BSV_Top_IFC  aws_BSV_top <- mkAWS_BSV_Top (core_clk, reset_by rstn);

   // Models for the four DDR4s
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
   // BEHAVIOR: start up

   rule rl_connecting (rg_state == STATE_CONNECTING);
      $display ("================================================================");
      $display ("Bluespec AWSteria simulation v1.0");
      $display ("Copyright (c) 2020 Bluespec, Inc. All Rights Reserved.");
      $display ("================================================================");

      // Open connection to remote host (host is client, we are server)
      c_host_connect (default_tcp_port);
      rg_state <= STATE_CONNECTED;
   endrule

   rule rl_start_when_connected (rg_state == STATE_CONNECTED);

      // Any post-connection initialization goes here

      rg_state <= STATE_RUNNING;
   endrule

   // ================================================================
   // Interaction with remote host

   Integer verbosity_bytevec = 0;

   // Communication box (converts between bytevecs and message structs)
   Bytevec_IFC comms <- mkBytevec(reset_by rstn);

   // Receive a bytevec from host and put into communication box
   rule rl_host_recv (rg_state == STATE_RUNNING);
      Bytevec_C_to_BSV bytevec <- c_host_recv (fromInteger (bytevec_C_to_BSV_size));
      // Protocol: bytevec [0] is the size of the bytevec
      // 0 is used to indicate that no bytevec was available from the host
      if (bytevec [0] != 0) begin
	 comms.fi_C_to_BSV_bytevec.enq (bytevec);

	 // Debug
	 if (verbosity_bytevec != 0) begin
	    $write ("Top_HW_Side.rl_host_recv\n    [");
	    for (Integer j = 0; j < bytevec_C_to_BSV_size; j = j + 1)
	       if (fromInteger (j) < bytevec [0])
		  $write (" %02h", bytevec [j]);
	    $display ("]");
	 end
      end
   endrule

   // Get a bytevec from communication box and send to host
   rule rl_host_send (rg_state == STATE_RUNNING);
      BSV_to_C_Bytevec bytevec <- pop_o (comms.fo_BSV_to_C_bytevec);

      // Debug
      if (verbosity_bytevec != 0) begin
	 $write ("Top_HW_Side.rl_host_send\n    [");
	 for (Integer j = 0; j < fromInteger (bytevec_BSV_to_C_size); j = j + 1)
	    if (fromInteger (j) < bytevec [0])
	       $write (" %02h", bytevec [j]);
	 $display ("]");
      end

      c_host_send (bytevec, fromInteger (bytevec_BSV_to_C_size));
   endrule

   // ----------------
   // Connect communication box and DMA_PCIS AXI4 port of aws_BSV_top

   Integer verbosity_AXI = 0;

   // Note: the rl_xxx's below can't be replaced by 'mkConnection'
   // because although t1 and t2 are isomorphic types, they are
   // different BSV types coming from different declarations.

   AXI4_Shim #(14, 64, 512, 0, 0, 0, 0, 0)
      dma_pcis_shim <- mkAXI4Shim (reset_by rstn);
   let dma_pcis_shim_masterSynth <- toAXI4_Master_Synth ( dma_pcis_shim.master
                                                        , reset_by rstn);

   mkConnection (dma_pcis_shim_masterSynth, aws_BSV_top.dma_pcis_slave, reset_by rstn);

   // Connect AXI4 WR_ADDR channel
   // Basically: mkConnection (comms.fo_AXI4_Wr_Addr_i16_a64_u0,  dma_pcis_xactor.i_wr_addr)
   rule rl_connect_dma_pcis_wr_addr;
      let x1 <- pop_o (comms.fo_AXI4_Wr_Addr_i16_a64_u0);
      let x2 = AXI4_AWFlit {awid: truncate (x1.awid),
			    awaddr: x1.awaddr,
			    awlen: x1.awlen,
			    awsize: unpack (x1.awsize),
			    awburst: unpack (x1.awburst),
			    awlock: unpack (x1.awlock),
			    awcache: x1.awcache,
			    awprot: x1.awprot,
			    awqos: x1.awqos,
			    awregion: x1.awregion,
			    awuser: x1.awuser};
      dma_pcis_shim.slave.aw.put (x2);

      if (verbosity_AXI != 0) begin
	 $display ("Top_HW_Side.rl_connect_dma_pcis_wr_addr:");
	 $display ("    ", fshow (AXI4_AWFlit #(16,64,0)'(x2)));
      end
   endrule

   Reg #(Bit #(8)) rg_AXI4_wr_data_beat <- mkReg (0, reset_by rstn);

   // Connect AXI4 WR_DATA channel
   // Basically: mkConnection (comms.fo_AXI4_Wr_Data_d512_u0,  dma_pcis_xactor.i_wr_data)
   rule rl_connect_dma_pcis_wr_data;
      let x1 <- pop_o (comms.fo_AXI4_Wr_Data_d512_u0);
      let x2 = AXI4_WFlit {wdata: x1.wdata,
			   wstrb: x1.wstrb,
			   wlast: unpack (x1.wlast),
			   wuser: x1.wuser};
      dma_pcis_shim.slave.w.put (x2);

      if (verbosity_AXI != 0) begin
	 $display ("Top_HW_Side.rl_connect_dma_pcis_wr_data: beat %0d", rg_AXI4_wr_data_beat);
	 $display ("    ", fshow (x2));
      end
      rg_AXI4_wr_data_beat <= (x2.wlast ? 0: (rg_AXI4_wr_data_beat + 1));
   endrule

   // Connect AXI4 RD_ADDR channel
   // Basically: mkConnection (comms.fo_AXI4_Rd_Addr_i16_a64_u0,  dma_pcis_xactor.i_rd_addr)
   rule rl_connect_dma_pcis_rd_addr;
      let x1 <- pop_o (comms.fo_AXI4_Rd_Addr_i16_a64_u0);
      let x2 = AXI4_ARFlit {arid: truncate (x1.arid),
			    araddr: x1.araddr,
			    arlen: x1.arlen,
			    arsize: unpack (x1.arsize),
			    arburst: unpack (x1.arburst),
			    arlock: unpack (x1.arlock),
			    arcache: x1.arcache,
			    arprot: x1.arprot,
			    arqos: x1.arqos,
			    arregion: x1.arregion,
			    aruser: x1.aruser};
      dma_pcis_shim.slave.ar.put (x2);

      if (verbosity_AXI != 0) begin
	 $display ("Top_HW_Side.rl_connect_dma_pcis_rd_addr:");
	 $display ("    ", fshow (AXI4_ARFlit #(16,64,0)'(x2)));
      end
   endrule

   // Connect AXI4 WR_RESP channel
   // Basically: mkConnection (comms.fi_AXI4_Wr_Resp_i16_u0,  dma_pcis_xactor.o_wr_resp)
   rule rl_connect_dma_pcis_wr_resp;
      let x1 <- get (dma_pcis_shim.slave.b);
      let x2 = AXI4_Wr_Resp_i16_u0 {bid:   zeroExtend (x1.bid),
				    bresp: pack (x1.bresp),
				    buser: x1.buser};
      comms.fi_AXI4_Wr_Resp_i16_u0.enq (x2);

      if (verbosity_AXI != 0) begin
	 $display ("Top_HW_Side.rl_connect_dma_pcis_wr_resp:");
	 $display ("    ", fshow (x2));
      end
   endrule

   // Connect AXI4 RD_DATA channel
   // Basically: mkConnection (comms.fi_AXI4_Rd_Data_i16_d512_u0,  dma_pcis_xactor.o_rd_data)
   rule rl_connect_dma_pcis_rd_data;
      let x1 <- get (dma_pcis_shim.slave.r);
      let x2 = AXI4_Rd_Data_i16_d512_u0 {rid:   zeroExtend (x1.rid),
					 rdata: x1.rdata,
					 rresp: pack (x1.rresp),
					 rlast: pack (x1.rlast),
					 ruser: x1.ruser};
      comms.fi_AXI4_Rd_Data_i16_d512_u0.enq (x2);

      if (verbosity_AXI != 0) begin
	 $display ("Top_HW_Side.rl_connect_dma_pcis_rd_data:");
	 $display ("    ", fshow (x2));
      end
   endrule

   // ----------------
   // Connect communication box and OCL AXI4-Lite port of aws_BSV_top

   Integer verbosity_AXI4L = 1;

   AXI4Lite_Shim #(32, 32, 0, 0, 0, 0, 0)
      ocl_shim <- mkAXI4LiteShim (reset_by rstn);
   let ocl_shim_masterSynth <- toAXI4Lite_Master_Synth ( ocl_shim.master
                                                       , reset_by rstn);

   mkConnection (ocl_shim_masterSynth, aws_BSV_top.ocl_slave, reset_by rstn);

   // Connect AXI4L WR_ADDR channel
   // Basically: mkConnection (comms.fo_AXI4L_Wr_Addr_a32_u0,  ocl_xactor.i_wr_addr)
   rule rl_connect_ocl_wr_addr;
      let x1 <- pop_o (comms.fo_AXI4L_Wr_Addr_a32_u0);
      let x2 = AXI4Lite_AWFlit {awaddr: x1.awaddr,
				awprot: x1.awprot,
				awuser: x1.awuser};
      ocl_shim.slave.aw.put (x2);

      if (verbosity_AXI4L != 0) begin
	 $display ("Top_HW_Side.rl_connect_ocl_wr_addr:");
	 $display ("    ", fshow (AXI4Lite_AWFlit #(32,0)'(x2)));
      end
   endrule

   // Connect AXI4L WR_DATA channel
   // Basically: mkConnection (comms.fo_AXI4L_Wr_Data_d32,  ocl_xactor.i_wr_data)
   rule rl_connect_ocl_wr_data;
      let x1 <- pop_o (comms.fo_AXI4L_Wr_Data_d32);
      let x2 = AXI4Lite_WFlit {wdata: x1.wdata,
			       wstrb: x1.wstrb,
			       wuser: 0};
      ocl_shim.slave.w.put (x2);

      if (verbosity_AXI4L != 0) begin
	 $display ("Top_HW_Side.rl_connect_ocl_wr_data:");
	 $display ("    ", fshow (AXI4Lite_WFlit #(32,0)'(x2)));
      end
   endrule

   // Connect AXI4L RD_ADDR channel
   // Basically: mkConnection (comms.fo_AXI4L_Rd_Addr_a32_u0,  ocl_xactor.i_rd_addr)
   rule rl_connect_ocl_rd_addr;
      let x1 <- pop_o (comms.fo_AXI4L_Rd_Addr_a32_u0);
      let x2 = AXI4Lite_ARFlit {araddr: x1.araddr,
				arprot: x1.arprot,
				aruser: x1.aruser};
      ocl_shim.slave.ar.put (x2);

      if (verbosity_AXI4L != 0) begin
	 $display ("Top_HW_Side.rl_connect_ocl_rd_addr:");
	 $display ("    ", fshow (AXI4Lite_ARFlit #(32,0)'(x2)));
      end
   endrule

   // Connect AXI4L WR_RESP channel
   // Basically: mkConnection (comms.fi_AXI4L_Wr_Resp_u0,  ocl_xactor.i_wr_resp)
   rule rl_connect_ocl_wr_resp;
      let x1 <- get (ocl_shim.slave.b);
      let x2 = AXI4L_Wr_Resp_u0 {bresp: pack (x1.bresp),
				 buser: x1.buser};
      comms.fi_AXI4L_Wr_Resp_u0.enq (x2);

      if (verbosity_AXI4L != 0) begin
	 $display ("Top_HW_Side.rl_connect_ocl_wr_resp:");
	 $display ("    ", fshow (x2));
      end
   endrule

   // Connect AXI4L RD_DATA channel
   // Basically: mkConnection (comms.fi_AXI4L_Rd_Data_d32_u0,  ocl_xactor.o_rd_data)
   rule rl_connect_ocl_rd_data;
      let x1 <- get (ocl_shim.slave.r);
      let x2 = AXI4L_Rd_Data_d32_u0 {rresp: pack (x1.rresp),
				     rdata: x1.rdata,
				     ruser: x1.ruser};
      comms.fi_AXI4L_Rd_Data_d32_u0.enq (x2);

      if (verbosity_AXI4L != 0) begin
	 $display ("Top_HW_Side.rl_connect_ocl_rd_data:");
	 $display ("    ", fshow (x2));
      end
   endrule

   // ================================================================
   // Misc. signals normally provided by SH/CL AWS top-level SystemVerilog
   //     ddr4 ready signals
   //     glcount0, glcount1 (4ns counters)
   //     vdip, vled (*)
   // TODO: (*) should have own channels to/from host in communication box

   Reg #(Bit #(64)) rg_counter_4ns <- mkReg (0, reset_by rstn);
   Reg #(Bit #(16)) rg_last_vled   <- mkReg (0, reset_by rstn);
   Reg #(Bit #(16)) rg_vdip        <- mkReg (0, reset_by rstn);

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

endpackage: Top_HW_Side
