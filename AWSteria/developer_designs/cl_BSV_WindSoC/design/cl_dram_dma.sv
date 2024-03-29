// This code borrows excerpts from the Amazon AWS-FPGA examples.
// Original copyrignt and license:
//    // Amazon FPGA Hardware Development Kit
//    //
//    // Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//    //
//    // Licensed under the Amazon Software License (the "License"). You may not use
//    // this file except in compliance with the License. A copy of the License is
//    // located at
//    //
//    //    http://aws.amazon.com/asl/
//    //
//    // or in the "license" file accompanying this file. This file is distributed on
//    // an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
//    // implied. See the License for the specific language governing permissions and
//    // limitations under the License.
//
// Modifications Copyright (c) 2020, Bluespec, Inc.
// Author: Rishiyur S. Nikhil
//
// ================================================================
// HW-side designs written in BSV for Amazon AWS-FPGA sit inside two
// outermost modules that are generic infrastructure (not
// design-specific):
//
//    cl_AWS_BSV_Top            (this module, written in SV)
//    │
//    ├─── mkAWS_BSV_Top        (written in BSV)
//    │    │
//    │    └─── <design>        (written in BSV)
//    │
//    └─── sh_ddr               (written in SV, provided by AWS-FPGA)
//
// This module is the 'CL' top-level, connecting to the AWS 'SH'.
// The following SH<->CL ports are used/unused by mkAWS_BSV_Top.
// (cf. standard CL port-list at:
//      aws-fpga/hdk/common/shell_stable/design/interfaces/cl_ports.vh)

// Used:
//    clk_main0, rst_main_n
//    sh_cl_flr_assert, cl_sh_flr_done
//    cl_sh_id0, ch_sh_id1
//    CLK_300M_DIMM0_*, M_A_*, cl_RST_DIMM_A_N    DDR A physical interfaces
//    CLK_300M_DIMM1_*, M_B_*, cl_RST_DIMM_B_N    DDR B physical interfaces
//    CLK_300M_DIMM2_*, M_D_*, cl_RST_DIMM_D_N    DDR D physical interfaces
//    sh_ddr_stat_*, ddr_sh_stat_*                DDR A,B,D stats interfaces
//    cl_sh_ddr_*, sh_cl_ddr_*                    DDR C AXI4 interfaces, ready signal
//    sh_cl_dma_pcis_*, cl_sh_dma_pcis_*          DMA_PCIS AXI4 interface, ready signal
//    sh_ocl_*, ocl_sh_*                          OCL AXI4-Lite interface, ready signal
//    sh_cl_glcount0/1                            4ns counters

// Unused: all other ports are unused (see 'tie off unused interfaces' section below)

// This wrapper instantiates the standard 'sh_ddr' for DDRs A, B and D
// - The physical and stats interfaces are connected to cl_ports as usual.
// - The AXI4 ports are connected inside this module to mkAWS_BSV_Top ports.

// This module's organization (with '*****' dividers):
//    - Tie-off unused interfaces
//    - Local Buses/Signals
//    - sh_ddr instantiation
//    - mkAWS_BSV_Top instantiation

// ================================================================

module cl_dram_dma #(parameter NUM_DDR=4)

(
   `include "cl_ports.vh"

);

`include "cl_common_defines.vh"      // CL Defines for all examples
`include "cl_id_defines.vh"          // Defines for ID0 and ID1 (PCI ID's)
`include "cl_dram_dma_defines.vh"

   // ****************************************************************
   // ****************************************************************
   // TIE OFF UNUSED INTERFACES
   // cf. aws-fpga/hdk/common/shell_stable/design/interfaces/unused_*

`include "unused_pcim_template.inc"
`include "unused_cl_sda_template.inc"
`include "unused_sh_bar1_template.inc"
`include "unused_apppf_irq_template.inc"

   // Unused 'full' signals
   assign  cl_sh_dma_rd_full = 1'b0;
   assign  cl_sh_dma_wr_full = 1'b0;

   // The functionality for these signals is TBD so they can can be tied-off.
   assign  cl_sh_status0 = 32'h0;
   assign  cl_sh_status1 = 32'h0;

   // ****************************************************************
   // ****************************************************************
   // PCIe ID signals
   // CL_SH_ID0:  31:16: PCIe Device ID     15: 0: PCIe Vendor ID
   // CL_SH_ID1:  31:16: PCIe Subsystem ID  15: 0: PCIe Subsystem Vendor ID

   assign cl_sh_id0 [31:0] = `CL_SH_ID0;
   assign cl_sh_id1 [31:0] = `CL_SH_ID1;

   // ****************************************************************
   // ****************************************************************
   // LOCAL BUSES/SIGNALS

   // ================================================================
   // Reset synchronization

   (* dont_touch = "true" *)
   logic pipe_rst_n;

   logic pre_sync_rst_n;

   (* dont_touch = "true" *)
   logic sync_rst_n;

   lib_pipe #(.WIDTH(1), .STAGES(4))
   PIPE_RST_N (.clk(clk_main_a0), .rst_n(1'b1), .in_bus(rst_main_n), .out_bus(pipe_rst_n));

   always_ff @(negedge pipe_rst_n or posedge clk_main_a0)
     if (! pipe_rst_n)
       begin
	  pre_sync_rst_n <= 0;
	  sync_rst_n <= 0;
       end
     else
       begin
	  pre_sync_rst_n <= 1;
	  sync_rst_n <= pre_sync_rst_n;
       end

   // ================================================================
   // FLR signals

   logic sh_cl_flr_assert_q;

   //FLR response
   always_ff @(negedge sync_rst_n or posedge clk_main_a0)
     if (! sync_rst_n)
       begin
	  sh_cl_flr_assert_q <= 0;
	  cl_sh_flr_done     <= 0;
       end
     else
       begin
	  sh_cl_flr_assert_q <= sh_cl_flr_assert;
	  cl_sh_flr_done     <= sh_cl_flr_assert_q && !cl_sh_flr_done;
       end

   // ================================================================
   // Width adjustment for DMA_PCIS bid and rid buses.
   // mkAWS_BSV_TOP drives bid and rid as 16b outputs.
   // But the corresponding CL inputs are only 6b.

   logic [15:0] cl_sh_dma_pcis_bid_16b;
   logic [15:0] cl_sh_dma_pcis_rid_16b;

   assign cl_sh_dma_pcis_bid = cl_sh_dma_pcis_bid_16b [5:0];
   assign cl_sh_dma_pcis_rid = cl_sh_dma_pcis_rid_16b [5:0];

   // ================================================================
   // DDR

   // Ready signals from DDRs
   logic [2:0] ddr4_A_B_D_ready;    // from sh_ddr, for DDR A, B, D
   logic       ddr4_C_ready_q;      // from cl_ports, for DDR C
   logic [3:0] ddr4_A_B_C_D_ready;

   always_ff @(posedge clk_main_a0 or negedge sync_rst_n)
     if (! sync_rst_n)
       begin
	  ddr4_C_ready_q <= 1'b0;
       end
     else
       begin
	  ddr4_C_ready_q <= sh_cl_ddr_is_ready;
       end

   assign ddr4_A_B_C_D_ready = {ddr4_A_B_D_ready[2], ddr4_C_ready_q, ddr4_A_B_D_ready[1:0]};

   // Vector-of-buses view of DDR4 A, B, D AXI4 ports, as expected by sh_ddr
   logic [15:0]  v_ddr4_axi4_awid    [2:0];
   logic [63:0]  v_ddr4_axi4_awaddr  [2:0];
   logic [7:0] 	 v_ddr4_axi4_awlen   [2:0];
   logic [2:0] 	 v_ddr4_axi4_awsize  [2:0];
   logic [1:0] 	 v_ddr4_axi4_awburst [2:0];
   logic 	 v_ddr4_axi4_awvalid [2:0];
   logic [2:0] 	 v_ddr4_axi4_awready;

   logic [15:0]  v_ddr4_axi4_wid     [2:0];
   logic [511:0] v_ddr4_axi4_wdata   [2:0];
   logic [63:0]  v_ddr4_axi4_wstrb   [2:0];
   logic [2:0] 	 v_ddr4_axi4_wlast;
   logic [2:0] 	 v_ddr4_axi4_wvalid;
   logic [2:0] 	 v_ddr4_axi4_wready;

   logic [15:0]  v_ddr4_axi4_bid     [2:0];
   logic [1:0] 	 v_ddr4_axi4_bresp   [2:0];
   logic [2:0] 	 v_ddr4_axi4_bvalid;
   logic [2:0] 	 v_ddr4_axi4_bready;

   logic [15:0]  v_ddr4_axi4_arid    [2:0];
   logic [63:0]  v_ddr4_axi4_araddr  [2:0];
   logic [7:0] 	 v_ddr4_axi4_arlen   [2:0];
   logic [2:0] 	 v_ddr4_axi4_arsize  [2:0];
   logic [1:0] 	 v_ddr4_axi4_arburst [2:0];
   logic [2:0] 	 v_ddr4_axi4_arvalid;
   logic [2:0] 	 v_ddr4_axi4_arready;

   logic [15:0]  v_ddr4_axi4_rid     [2:0];
   logic [511:0] v_ddr4_axi4_rdata   [2:0];
   logic [1:0] 	 v_ddr4_axi4_rresp   [2:0];
   logic [2:0] 	 v_ddr4_axi4_rlast;
   logic [2:0] 	 v_ddr4_axi4_rvalid;
   logic [2:0] 	 v_ddr4_axi4_rready;

   // Vector-of-buses view of DDR4 A, B, D stats ports, as expected by sh_ddr
   // From cl_ports to sh_ddr
   logic [7:0]  v_ddr4_stats_addr_q[2:0];
   logic [2:0]  v_ddr4_stats_wr_q;
   logic [2:0]  v_ddr4_stats_rd_q;
   logic [31:0] v_ddr4_stats_wdata_q[2:0];

   // From sh_ddr to cl_ports
   logic [2:0] 	v_ddr4_stats_ack_q;
   logic [31:0] v_ddr4_stats_rdata_q[2:0];
   logic [7:0] 	v_ddr4_stats_int_q[2:0];

   // ****************************************************************
   // ****************************************************************
   // MODULE INSTANTIATIONS ETC.

   // ================================================================
   // DDR A, B, D INSTANTIATION

   // ----------------
   // Synchronize and connect stats signals between cl_ports and v_ddr4_stats_* (which connects to sh_ddr)

   localparam NUM_CFG_STGS_CL_DDR_ATG = 8;

   // DDR A
   lib_pipe #(.WIDTH(1+1+8+32), .STAGES(NUM_CFG_STGS_CL_DDR_ATG))
   PIPE_DDR_STAT0 (.clk(clk_main_a0), .rst_n(sync_rst_n),
		   .in_bus({sh_ddr_stat_wr0, sh_ddr_stat_rd0, sh_ddr_stat_addr0, sh_ddr_stat_wdata0}),
		   .out_bus({v_ddr4_stats_wr_q[0], v_ddr4_stats_rd_q[0], v_ddr4_stats_addr_q[0], v_ddr4_stats_wdata_q[0]})
		   );


   lib_pipe #(.WIDTH(1+8+32), .STAGES(NUM_CFG_STGS_CL_DDR_ATG))
   PIPE_DDR_STAT_ACK0 (.clk(clk_main_a0), .rst_n(sync_rst_n),
		       .in_bus({v_ddr4_stats_ack_q[0], v_ddr4_stats_int_q[0], v_ddr4_stats_rdata_q[0]}),
		       .out_bus({ddr_sh_stat_ack0, ddr_sh_stat_int0, ddr_sh_stat_rdata0})
		       );

   // DDR B
   lib_pipe #(.WIDTH(1+1+8+32), .STAGES(NUM_CFG_STGS_CL_DDR_ATG))
   PIPE_DDR_STAT1 (.clk(clk_main_a0), .rst_n(sync_rst_n),
		   .in_bus({sh_ddr_stat_wr1, sh_ddr_stat_rd1, sh_ddr_stat_addr1, sh_ddr_stat_wdata1}),
		   .out_bus({v_ddr4_stats_wr_q[1], v_ddr4_stats_rd_q[1], v_ddr4_stats_addr_q[1], v_ddr4_stats_wdata_q[1]})
		   );


   lib_pipe #(.WIDTH(1+8+32), .STAGES(NUM_CFG_STGS_CL_DDR_ATG))
   PIPE_DDR_STAT_ACK1 (.clk(clk_main_a0), .rst_n(sync_rst_n),
		       .in_bus({v_ddr4_stats_ack_q[1], v_ddr4_stats_int_q[1], v_ddr4_stats_rdata_q[1]}),
		       .out_bus({ddr_sh_stat_ack1, ddr_sh_stat_int1, ddr_sh_stat_rdata1})
		       );

   // DDR D
   lib_pipe #(.WIDTH(1+1+8+32), .STAGES(NUM_CFG_STGS_CL_DDR_ATG))
   PIPE_DDR_STAT2 (.clk(clk_main_a0), .rst_n(sync_rst_n),
		   .in_bus({sh_ddr_stat_wr2, sh_ddr_stat_rd2, sh_ddr_stat_addr2, sh_ddr_stat_wdata2}),
		   .out_bus({v_ddr4_stats_wr_q[2], v_ddr4_stats_rd_q[2], v_ddr4_stats_addr_q[2], v_ddr4_stats_wdata_q[2]})
		   );


   lib_pipe #(.WIDTH(1+8+32), .STAGES(NUM_CFG_STGS_CL_DDR_ATG))
   PIPE_DDR_STAT_ACK2 (.clk(clk_main_a0), .rst_n(sync_rst_n),
		       .in_bus({v_ddr4_stats_ack_q[2], v_ddr4_stats_int_q[2], v_ddr4_stats_rdata_q[2]}),
		       .out_bus({ddr_sh_stat_ack2, ddr_sh_stat_int2, ddr_sh_stat_rdata2})
		       );

   assign v_ddr4_axi4_awburst [0] = 2'b01;
   assign v_ddr4_axi4_awburst [1] = 2'b01;
   assign v_ddr4_axi4_awburst [2] = 2'b01;

   assign v_ddr4_axi4_arburst [0] = 2'b01;
   assign v_ddr4_axi4_arburst [1] = 2'b01;
   assign v_ddr4_axi4_arburst [2] = 2'b01;

   // ================================================================
   // Instantiate sh_ddr (for DDRs A, B, D)

   (* dont_touch = "true" *)
   logic  sh_ddr_sync_rst_n;

   lib_pipe #(.WIDTH(1), .STAGES(4))
   SH_DDR_SLC_RST_N (.clk(clk_main_a0), .rst_n(1'b1), .in_bus(sync_rst_n), .out_bus(sh_ddr_sync_rst_n));

   sh_ddr #(
            .DDR_A_PRESENT(`DDR_A_PRESENT),
            .DDR_B_PRESENT(`DDR_B_PRESENT),
            .DDR_D_PRESENT(`DDR_D_PRESENT)
	    ) SH_DDR
     (
      .clk(clk_main_a0),
      .rst_n(sh_ddr_sync_rst_n),

      .stat_clk(clk_main_a0),
      .stat_rst_n(sh_ddr_sync_rst_n),

      // ----------------------------------------------------------------
      // Physical A, B, D interfaces connected directly to cl_ports

      .CLK_300M_DIMM0_DP(CLK_300M_DIMM0_DP),
      .CLK_300M_DIMM0_DN(CLK_300M_DIMM0_DN),
      .M_A_ACT_N(M_A_ACT_N),
      .M_A_MA(M_A_MA),
      .M_A_BA(M_A_BA),
      .M_A_BG(M_A_BG),
      .M_A_CKE(M_A_CKE),
      .M_A_ODT(M_A_ODT),
      .M_A_CS_N(M_A_CS_N),
      .M_A_CLK_DN(M_A_CLK_DN),
      .M_A_CLK_DP(M_A_CLK_DP),
      .M_A_PAR(M_A_PAR),
      .M_A_DQ(M_A_DQ),
      .M_A_ECC(M_A_ECC),
      .M_A_DQS_DP(M_A_DQS_DP),
      .M_A_DQS_DN(M_A_DQS_DN),
      .cl_RST_DIMM_A_N(cl_RST_DIMM_A_N),


      .CLK_300M_DIMM1_DP(CLK_300M_DIMM1_DP),
      .CLK_300M_DIMM1_DN(CLK_300M_DIMM1_DN),
      .M_B_ACT_N(M_B_ACT_N),
      .M_B_MA(M_B_MA),
      .M_B_BA(M_B_BA),
      .M_B_BG(M_B_BG),
      .M_B_CKE(M_B_CKE),
      .M_B_ODT(M_B_ODT),
      .M_B_CS_N(M_B_CS_N),
      .M_B_CLK_DN(M_B_CLK_DN),
      .M_B_CLK_DP(M_B_CLK_DP),
      .M_B_PAR(M_B_PAR),
      .M_B_DQ(M_B_DQ),
      .M_B_ECC(M_B_ECC),
      .M_B_DQS_DP(M_B_DQS_DP),
      .M_B_DQS_DN(M_B_DQS_DN),
      .cl_RST_DIMM_B_N(cl_RST_DIMM_B_N),

      .CLK_300M_DIMM3_DP(CLK_300M_DIMM3_DP),
      .CLK_300M_DIMM3_DN(CLK_300M_DIMM3_DN),
      .M_D_ACT_N(M_D_ACT_N),
      .M_D_MA(M_D_MA),
      .M_D_BA(M_D_BA),
      .M_D_BG(M_D_BG),
      .M_D_CKE(M_D_CKE),
      .M_D_ODT(M_D_ODT),
      .M_D_CS_N(M_D_CS_N),
      .M_D_CLK_DN(M_D_CLK_DN),
      .M_D_CLK_DP(M_D_CLK_DP),
      .M_D_PAR(M_D_PAR),
      .M_D_DQ(M_D_DQ),
      .M_D_ECC(M_D_ECC),
      .M_D_DQS_DP(M_D_DQS_DP),
      .M_D_DQS_DN(M_D_DQS_DN),
      .cl_RST_DIMM_D_N(cl_RST_DIMM_D_N),

      // ----------------------------------------------------------------
      // AXI4 A, B, D interfaces connected to local AXI4 buses

      .cl_sh_ddr_awid    (v_ddr4_axi4_awid),
      .cl_sh_ddr_awaddr  (v_ddr4_axi4_awaddr),
      .cl_sh_ddr_awlen   (v_ddr4_axi4_awlen),
      .cl_sh_ddr_awsize  (v_ddr4_axi4_awsize),
      .cl_sh_ddr_awvalid (v_ddr4_axi4_awvalid),
      .cl_sh_ddr_awburst (v_ddr4_axi4_awburst),
      .sh_cl_ddr_awready (v_ddr4_axi4_awready),

      .cl_sh_ddr_wid     (v_ddr4_axi4_wid),
      .cl_sh_ddr_wdata   (v_ddr4_axi4_wdata),
      .cl_sh_ddr_wstrb   (v_ddr4_axi4_wstrb),
      .cl_sh_ddr_wlast   (v_ddr4_axi4_wlast),
      .cl_sh_ddr_wvalid  (v_ddr4_axi4_wvalid),
      .sh_cl_ddr_wready  (v_ddr4_axi4_wready),

      .sh_cl_ddr_bid     (v_ddr4_axi4_bid),
      .sh_cl_ddr_bresp   (v_ddr4_axi4_bresp),
      .sh_cl_ddr_bvalid  (v_ddr4_axi4_bvalid),
      .cl_sh_ddr_bready  (v_ddr4_axi4_bready),

      .cl_sh_ddr_arid    (v_ddr4_axi4_arid),
      .cl_sh_ddr_araddr  (v_ddr4_axi4_araddr),
      .cl_sh_ddr_arlen   (v_ddr4_axi4_arlen),
      .cl_sh_ddr_arsize  (v_ddr4_axi4_arsize),
      .cl_sh_ddr_arvalid (v_ddr4_axi4_arvalid),
      .cl_sh_ddr_arburst (v_ddr4_axi4_arburst),
      .sh_cl_ddr_arready (v_ddr4_axi4_arready),

      .sh_cl_ddr_rid    (v_ddr4_axi4_rid),
      .sh_cl_ddr_rdata  (v_ddr4_axi4_rdata),
      .sh_cl_ddr_rresp  (v_ddr4_axi4_rresp),
      .sh_cl_ddr_rlast  (v_ddr4_axi4_rlast),
      .sh_cl_ddr_rvalid (v_ddr4_axi4_rvalid),
      .cl_sh_ddr_rready (v_ddr4_axi4_rready),

      // ----------------------------------------------------------------
      // DDR A, B, D ready signals

      .sh_cl_ddr_is_ready(ddr4_A_B_D_ready),

      // ----------------------------------------------------------------
      // DDR A, B, D stats connected to local ddr4 stats bus

      .sh_ddr_stat_addr0  (v_ddr4_stats_addr_q[0]) ,
      .sh_ddr_stat_wr0    (v_ddr4_stats_wr_q[0]     ) ,
      .sh_ddr_stat_rd0    (v_ddr4_stats_rd_q[0]     ) ,
      .sh_ddr_stat_wdata0 (v_ddr4_stats_wdata_q[0]  ) ,
      .ddr_sh_stat_ack0   (v_ddr4_stats_ack_q[0]    ) ,
      .ddr_sh_stat_rdata0 (v_ddr4_stats_rdata_q[0]  ),
      .ddr_sh_stat_int0   (v_ddr4_stats_int_q[0]    ),

      .sh_ddr_stat_addr1  (v_ddr4_stats_addr_q[1]) ,
      .sh_ddr_stat_wr1    (v_ddr4_stats_wr_q[1]     ) ,
      .sh_ddr_stat_rd1    (v_ddr4_stats_rd_q[1]     ) ,
      .sh_ddr_stat_wdata1 (v_ddr4_stats_wdata_q[1]  ) ,
      .ddr_sh_stat_ack1   (v_ddr4_stats_ack_q[1]    ) ,
      .ddr_sh_stat_rdata1 (v_ddr4_stats_rdata_q[1]  ),
      .ddr_sh_stat_int1   (v_ddr4_stats_int_q[1]    ),

      .sh_ddr_stat_addr2  (v_ddr4_stats_addr_q[2]) ,
      .sh_ddr_stat_wr2    (v_ddr4_stats_wr_q[2]     ) ,
      .sh_ddr_stat_rd2    (v_ddr4_stats_rd_q[2]     ) ,
      .sh_ddr_stat_wdata2 (v_ddr4_stats_wdata_q[2]  ) ,
      .ddr_sh_stat_ack2   (v_ddr4_stats_ack_q[2]    ) ,
      .ddr_sh_stat_rdata2 (v_ddr4_stats_rdata_q[2]  ),
      .ddr_sh_stat_int2   (v_ddr4_stats_int_q[2]    )
      );

   // ================================================================
   // The AWS DDR4 interfaces have a 'wid' bus, which is actually not
   // legal for AXI4 ('wid' only exists for AXI3), per ARM
   // documentation.
   // Here we drive those buses with 0.

   assign  v_ddr4_axi4_wid [0] = 16'b0;    // DDR A
   assign  v_ddr4_axi4_wid [1] = 16'b0;    // DDR B
   assign  cl_sh_ddr_wid       = 16'b0;    // DDR C
   assign  v_ddr4_axi4_wid [2] = 16'b0;    // DDR D

   // ================================================================
   // mkAWS_BSV_Top instantiation

   (* dont_touch = "true" *)
   logic mkAWS_BSV_Top_sync_rst_n;

   lib_pipe #(.WIDTH(1), .STAGES(4))
   mkAWS_BSV_Top_SLC_RST_N (.clk     (clk_main_a0),
			    .rst_n   (1'b1),
			    .in_bus  (sync_rst_n),
			    .out_bus (mkAWS_BSV_Top_sync_rst_n));

   mkAWS_BSV_Top #()
   aws_BSV_top   (.CLK   (clk_main_a0),
		  .RST_N (mkAWS_BSV_Top_sync_rst_n),

		  // ----------------
		  // DMA_PCIS connection
		  .dma_pcis_slave_awvalid  (sh_cl_dma_pcis_awvalid),
		  .dma_pcis_slave_awid     ({ 10'b0, sh_cl_dma_pcis_awid }),
		  .dma_pcis_slave_awaddr   (sh_cl_dma_pcis_awaddr),
		  .dma_pcis_slave_awlen    (sh_cl_dma_pcis_awlen),
		  .dma_pcis_slave_awsize   (sh_cl_dma_pcis_awsize),
		  .dma_pcis_slave_awburst  (2'b01),    // INCR only
		  .dma_pcis_slave_awlock   (1'b0),     // unused
		  .dma_pcis_slave_awcache  (4'b0),     // unused
		  .dma_pcis_slave_awprot   (3'b0),     // unused
		  .dma_pcis_slave_awqos    (4'b0),     // unused
		  .dma_pcis_slave_awregion (4'b0),     // unused
		  .dma_pcis_slave_awready  (cl_sh_dma_pcis_awready),

		  .dma_pcis_slave_wvalid   (sh_cl_dma_pcis_wvalid),
		  .dma_pcis_slave_wdata    (sh_cl_dma_pcis_wdata),
		  .dma_pcis_slave_wstrb    (sh_cl_dma_pcis_wstrb),
		  .dma_pcis_slave_wlast    (sh_cl_dma_pcis_wlast),
		  .dma_pcis_slave_wready   (cl_sh_dma_pcis_wready),

		  .dma_pcis_slave_bvalid   (cl_sh_dma_pcis_bvalid),
		  .dma_pcis_slave_bid      (cl_sh_dma_pcis_bid_16b),
		  .dma_pcis_slave_bresp    (cl_sh_dma_pcis_bresp),
		  .dma_pcis_slave_bready   (sh_cl_dma_pcis_bready),

		  .dma_pcis_slave_arvalid  (sh_cl_dma_pcis_arvalid),
		  .dma_pcis_slave_arid     ({ 10'b0, sh_cl_dma_pcis_arid }),
		  .dma_pcis_slave_araddr   (sh_cl_dma_pcis_araddr),
		  .dma_pcis_slave_arlen    (sh_cl_dma_pcis_arlen),
		  .dma_pcis_slave_arsize   (sh_cl_dma_pcis_arsize),
		  .dma_pcis_slave_arburst  (2'b01),    // INCR only
		  .dma_pcis_slave_arlock   (1'b0),     // unused
		  .dma_pcis_slave_arcache  (4'b0),     // unused
		  .dma_pcis_slave_arprot   (3'b0),     // unused
		  .dma_pcis_slave_arqos    (4'b0),     // unused
		  .dma_pcis_slave_arregion (4'b0),     // unused
		  .dma_pcis_slave_arready  (cl_sh_dma_pcis_arready),

		  .dma_pcis_slave_rvalid   (cl_sh_dma_pcis_rvalid),
		  .dma_pcis_slave_rid      (cl_sh_dma_pcis_rid_16b),
		  .dma_pcis_slave_rdata    (cl_sh_dma_pcis_rdata),
		  .dma_pcis_slave_rresp    (cl_sh_dma_pcis_rresp),
		  .dma_pcis_slave_rlast    (cl_sh_dma_pcis_rlast),
		  .dma_pcis_slave_rready   (sh_cl_dma_pcis_rready),

		  // ----------------
		  // OCL SLAVE (AXI4_Lite_32_32 Slave)
		  .ocl_slave_aw_awvalid (sh_ocl_awvalid),
		  .ocl_slave_aw_awaddr  (sh_ocl_awaddr),
		  .ocl_slave_aw_awprot  (3'b0),        // unused
		  .ocl_slave_aw_awready (ocl_sh_awready),

		  .ocl_slave_w_wvalid  (sh_ocl_wvalid),
		  .ocl_slave_w_wdata   (sh_ocl_wdata),
		  .ocl_slave_w_wstrb   (sh_ocl_wstrb),
		  .ocl_slave_w_wready  (ocl_sh_wready),

		  .ocl_slave_b_bvalid  (ocl_sh_bvalid),
		  .ocl_slave_b_bresp   (ocl_sh_bresp),
		  .ocl_slave_b_bready  (sh_ocl_bready),

		  .ocl_slave_ar_arvalid (sh_ocl_arvalid),
		  .ocl_slave_ar_araddr  (sh_ocl_araddr),
		  .ocl_slave_ar_arprot  (3'b0),        // unused
		  .ocl_slave_ar_arready (ocl_sh_arready),

		  .ocl_slave_r_rvalid  (ocl_sh_rvalid),
		  .ocl_slave_r_rresp   (ocl_sh_rresp),
		  .ocl_slave_r_rdata   (ocl_sh_rdata),
		  .ocl_slave_r_rready  (sh_ocl_rready),

		  // ----------------
		  // DDR A
		  .ddr4_A_master_awvalid  (v_ddr4_axi4_awvalid [0]),
		  .ddr4_A_master_awid     (v_ddr4_axi4_awid [0]),
		  .ddr4_A_master_awaddr   (v_ddr4_axi4_awaddr [0]),
		  .ddr4_A_master_awlen    (v_ddr4_axi4_awlen [0]),
		  .ddr4_A_master_awsize   (v_ddr4_axi4_awsize [0]),
		  .ddr4_A_master_awburst  (),    // Unused; we drive 2'b01 (INCR) into sh_ddr
		  .ddr4_A_master_awlock   (),    // Unused
		  .ddr4_A_master_awcache  (),    // Unused
		  .ddr4_A_master_awprot   (),    // Unused
		  .ddr4_A_master_awqos    (),    // Unused
		  .ddr4_A_master_awregion (),    // Unused
		  .ddr4_A_master_awready  (v_ddr4_axi4_awready [0]),

		  .ddr4_A_master_wvalid   (v_ddr4_axi4_wvalid [0]),
		  .ddr4_A_master_wdata    (v_ddr4_axi4_wdata [0]),
		  .ddr4_A_master_wstrb    (v_ddr4_axi4_wstrb [0]),
		  .ddr4_A_master_wlast    (v_ddr4_axi4_wlast [0]),
		  .ddr4_A_master_wready   (v_ddr4_axi4_wready [0]),

		  .ddr4_A_master_bvalid   (v_ddr4_axi4_bvalid [0]),
		  .ddr4_A_master_bid      (v_ddr4_axi4_bid [0]),
		  .ddr4_A_master_bresp    (v_ddr4_axi4_bresp [0]),
		  .ddr4_A_master_bready   (v_ddr4_axi4_bready [0]),

		  .ddr4_A_master_arvalid  (v_ddr4_axi4_arvalid [0]),
		  .ddr4_A_master_arid     (v_ddr4_axi4_arid [0]),
		  .ddr4_A_master_araddr   (v_ddr4_axi4_araddr [0]),
		  .ddr4_A_master_arlen    (v_ddr4_axi4_arlen [0]),
		  .ddr4_A_master_arsize   (v_ddr4_axi4_arsize [0]),
		  .ddr4_A_master_arburst  (),    // Unused; we drive 2'b01 (INCR) into sh_ddr
		  .ddr4_A_master_arlock   (),    // Unused
		  .ddr4_A_master_arcache  (),    // Unused
		  .ddr4_A_master_arprot   (),    // Unused
		  .ddr4_A_master_arqos    (),    // Unused
		  .ddr4_A_master_arregion (),    // Unused
		  .ddr4_A_master_arready  (v_ddr4_axi4_arready [0]),

		  .ddr4_A_master_rvalid   (v_ddr4_axi4_rvalid [0]),
		  .ddr4_A_master_rid      (v_ddr4_axi4_rid [0]),
		  .ddr4_A_master_rdata    (v_ddr4_axi4_rdata [0]),
		  .ddr4_A_master_rresp    (v_ddr4_axi4_rresp [0]),
		  .ddr4_A_master_rlast    (v_ddr4_axi4_rlast [0]),
		  .ddr4_A_master_rready   (v_ddr4_axi4_rready [0]),

		  // ----------------
		  // DDR B
		  .ddr4_B_master_awvalid  (v_ddr4_axi4_awvalid [1]),
		  .ddr4_B_master_awid     (v_ddr4_axi4_awid [1]),
		  .ddr4_B_master_awaddr   (v_ddr4_axi4_awaddr [1]),
		  .ddr4_B_master_awlen    (v_ddr4_axi4_awlen [1]),
		  .ddr4_B_master_awsize   (v_ddr4_axi4_awsize [1]),
		  .ddr4_B_master_awburst  (),    // Unused; we drive 2'b01 (INCR) into sh_ddr
		  .ddr4_B_master_awlock   (),    // Unused
		  .ddr4_B_master_awcache  (),    // Unused
		  .ddr4_B_master_awprot   (),    // Unused
		  .ddr4_B_master_awqos    (),    // Unused
		  .ddr4_B_master_awregion (),    // Unused
		  .ddr4_B_master_awready  (v_ddr4_axi4_awready [1]),

		  .ddr4_B_master_wvalid   (v_ddr4_axi4_wvalid [1]),
		  .ddr4_B_master_wdata    (v_ddr4_axi4_wdata [1]),
		  .ddr4_B_master_wstrb    (v_ddr4_axi4_wstrb [1]),
		  .ddr4_B_master_wlast    (v_ddr4_axi4_wlast [1]),
		  .ddr4_B_master_wready   (v_ddr4_axi4_wready [1]),

		  .ddr4_B_master_bvalid   (v_ddr4_axi4_bvalid [1]),
		  .ddr4_B_master_bid      (v_ddr4_axi4_bid [1]),
		  .ddr4_B_master_bresp    (v_ddr4_axi4_bresp [1]),
		  .ddr4_B_master_bready   (v_ddr4_axi4_bready [1]),

		  .ddr4_B_master_arvalid  (v_ddr4_axi4_arvalid [1]),
		  .ddr4_B_master_arid     (v_ddr4_axi4_arid [1]),
		  .ddr4_B_master_araddr   (v_ddr4_axi4_araddr [1]),
		  .ddr4_B_master_arlen    (v_ddr4_axi4_arlen [1]),
		  .ddr4_B_master_arsize   (v_ddr4_axi4_arsize [1]),
		  .ddr4_B_master_arburst  (),    // unused; we drive 2'b01 (INCR) into sh_ddr
		  .ddr4_B_master_arlock   (),    // Unused
		  .ddr4_B_master_arcache  (),    // Unused
		  .ddr4_B_master_arprot   (),    // Unused
		  .ddr4_B_master_arqos    (),    // Unused
		  .ddr4_B_master_arregion (),    // Unused
		  .ddr4_B_master_arready  (v_ddr4_axi4_arready [1]),

		  .ddr4_B_master_rvalid   (v_ddr4_axi4_rvalid [1]),
		  .ddr4_B_master_rid      (v_ddr4_axi4_rid [1]),
		  .ddr4_B_master_rdata    (v_ddr4_axi4_rdata [1]),
		  .ddr4_B_master_rresp    (v_ddr4_axi4_rresp [1]),
		  .ddr4_B_master_rlast    (v_ddr4_axi4_rlast [1]),
		  .ddr4_B_master_rready   (v_ddr4_axi4_rready [1]),

		  // ----------------
		  // DDR C
		  .ddr4_C_master_awvalid  (cl_sh_ddr_awvalid),
		  .ddr4_C_master_awid     (cl_sh_ddr_awid),
		  .ddr4_C_master_awaddr   (cl_sh_ddr_awaddr),
		  .ddr4_C_master_awlen    (cl_sh_ddr_awlen),
		  .ddr4_C_master_awsize   (cl_sh_ddr_awsize),
		  .ddr4_C_master_awburst  (),    // Unused; we drive 2'b01 (INCR) into cl_sh_ddr_awburst
		  .ddr4_C_master_awlock   (),    // Unused
		  .ddr4_C_master_awcache  (),    // Unused
		  .ddr4_C_master_awprot   (),    // Unused
		  .ddr4_C_master_awqos    (),    // Unused
		  .ddr4_C_master_awregion (),    // Unused
		  .ddr4_C_master_awready  (sh_cl_ddr_awready),

		  .ddr4_C_master_wvalid   (cl_sh_ddr_wvalid),
		  .ddr4_C_master_wdata    (cl_sh_ddr_wdata),
		  .ddr4_C_master_wstrb    (cl_sh_ddr_wstrb),
		  .ddr4_C_master_wlast    (cl_sh_ddr_wlast),
		  .ddr4_C_master_wready   (sh_cl_ddr_wready),

		  .ddr4_C_master_bvalid   (sh_cl_ddr_bvalid),
		  .ddr4_C_master_bid      (sh_cl_ddr_bid),
		  .ddr4_C_master_bresp    (sh_cl_ddr_bresp),
		  .ddr4_C_master_bready   (cl_sh_ddr_bready),

		  .ddr4_C_master_arvalid  (cl_sh_ddr_arvalid),
		  .ddr4_C_master_arid     (cl_sh_ddr_arid),
		  .ddr4_C_master_araddr   (cl_sh_ddr_araddr),
		  .ddr4_C_master_arlen    (cl_sh_ddr_arlen),
		  .ddr4_C_master_arsize   (cl_sh_ddr_arsize),
		  .ddr4_C_master_arburst  (),    // Unused; we drive 2'b01 (INCR) into cl_sh_ddr_arburst
		  .ddr4_C_master_arlock   (),    // Unused
		  .ddr4_C_master_arcache  (),    // Unused
		  .ddr4_C_master_arprot   (),    // Unused
		  .ddr4_C_master_arqos    (),    // Unused
		  .ddr4_C_master_arregion (),    // Unused
		  .ddr4_C_master_arready  (sh_cl_ddr_arready),

		  .ddr4_C_master_rvalid   (sh_cl_ddr_rvalid),
		  .ddr4_C_master_rid      (sh_cl_ddr_rid),
		  .ddr4_C_master_rdata    (sh_cl_ddr_rdata),
		  .ddr4_C_master_rresp    (sh_cl_ddr_rresp),
		  .ddr4_C_master_rlast    (sh_cl_ddr_rlast),
		  .ddr4_C_master_rready   (cl_sh_ddr_rready),

		  // ----------------
		  // DDR D
		  .ddr4_D_master_awvalid  (v_ddr4_axi4_awvalid [2]),
		  .ddr4_D_master_awid     (v_ddr4_axi4_awid [2]),
		  .ddr4_D_master_awaddr   (v_ddr4_axi4_awaddr [2]),
		  .ddr4_D_master_awlen    (v_ddr4_axi4_awlen [2]),
		  .ddr4_D_master_awsize   (v_ddr4_axi4_awsize [2]),
		  .ddr4_D_master_awburst  (),    // Unused; we drive 2'b01 (INCR) into sh_ddr
		  .ddr4_D_master_awlock   (),    // Unused
		  .ddr4_D_master_awcache  (),    // Unused
		  .ddr4_D_master_awprot   (),    // Unused
		  .ddr4_D_master_awqos    (),    // Unused
		  .ddr4_D_master_awregion (),    // Unused
		  .ddr4_D_master_awready  (v_ddr4_axi4_awready [2]),

		  .ddr4_D_master_wvalid   (v_ddr4_axi4_wvalid [2]),
		  .ddr4_D_master_wdata    (v_ddr4_axi4_wdata [2]),
		  .ddr4_D_master_wstrb    (v_ddr4_axi4_wstrb [2]),
		  .ddr4_D_master_wlast    (v_ddr4_axi4_wlast [2]),
		  .ddr4_D_master_wready   (v_ddr4_axi4_wready [2]),

		  .ddr4_D_master_bvalid   (v_ddr4_axi4_bvalid [2]),
		  .ddr4_D_master_bid      (v_ddr4_axi4_bid [2]),
		  .ddr4_D_master_bresp    (v_ddr4_axi4_bresp [2]),
		  .ddr4_D_master_bready   (v_ddr4_axi4_bready [2]),

		  .ddr4_D_master_arvalid  (v_ddr4_axi4_arvalid [2]),
		  .ddr4_D_master_arid     (v_ddr4_axi4_arid [2]),
		  .ddr4_D_master_araddr   (v_ddr4_axi4_araddr [2]),
		  .ddr4_D_master_arlen    (v_ddr4_axi4_arlen [2]),
		  .ddr4_D_master_arsize   (v_ddr4_axi4_arsize [2]),
		  .ddr4_D_master_arburst  (),    // Unused; we drive 2'b01 (INCR) into sh_ddr
		  .ddr4_D_master_arlock   (),    // Unused
		  .ddr4_D_master_arcache  (),    // Unused
		  .ddr4_D_master_arprot   (),    // Unused
		  .ddr4_D_master_arqos    (),    // Unused
		  .ddr4_D_master_arregion (),    // Unused
		  .ddr4_D_master_arready  (v_ddr4_axi4_arready [2]),

		  .ddr4_D_master_rvalid   (v_ddr4_axi4_rvalid [2]),
		  .ddr4_D_master_rid      (v_ddr4_axi4_rid [2]),
		  .ddr4_D_master_rdata    (v_ddr4_axi4_rdata [2]),
		  .ddr4_D_master_rresp    (v_ddr4_axi4_rresp [2]),
		  .ddr4_D_master_rlast    (v_ddr4_axi4_rlast [2]),
		  .ddr4_D_master_rready   (v_ddr4_axi4_rready [2]),

		  .m_ddr4_ready_ddr4_A_B_C_D_ready (ddr4_A_B_C_D_ready),

		  .m_glcount0_glcount0 (sh_cl_glcount0),
		  .m_glcount1_glcount1 (sh_cl_glcount1),
		  .m_vled              (cl_sh_status_vled),
		  .m_vdip_vdip         (sh_cl_status_vdip)
		  );

// ****************************************************************
// ****************************************************************

endmodule
