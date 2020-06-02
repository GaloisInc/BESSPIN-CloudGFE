//
// Generated by Bluespec Compiler, version 2019.05.beta2 (build a88bf40db, 2019-05-24)
//
//
//
//
// Ports:
// Name                         I/O  size props
// awready                        O     1 reg
// wready                         O     1 reg
// bvalid                         O     1 reg
// bid                            O    16 reg
// bresp                          O     2 reg
// arready                        O     1 reg
// rvalid                         O     1 reg
// rid                            O    16 reg
// rdata                          O   512 reg
// rresp                          O     2 reg
// rlast                          O     1 reg
// CLK                            I     1 clock
// RST_N                          I     1 reset
// awvalid                        I     1
// awid                           I    16 reg
// awaddr                         I    64 reg
// awlen                          I     8 reg
// awsize                         I     3 reg
// awburst                        I     2 reg
// awlock                         I     1 reg
// awcache                        I     4 reg
// awprot                         I     3 reg
// awqos                          I     4 reg
// awregion                       I     4 reg
// wvalid                         I     1
// wdata                          I   512 reg
// wstrb                          I    64 reg
// wlast                          I     1 reg
// bready                         I     1
// arvalid                        I     1
// arid                           I    16 reg
// araddr                         I    64 reg
// arlen                          I     8 reg
// arsize                         I     3 reg
// arburst                        I     2 reg
// arlock                         I     1 reg
// arcache                        I     4 reg
// arprot                         I     3 reg
// arqos                          I     4 reg
// arregion                       I     4 reg
// rready                         I     1
//
// No combinational paths from inputs to outputs
//
//

`ifdef BSV_ASSIGNMENT_DELAY
`else
  `define BSV_ASSIGNMENT_DELAY
`endif

`ifdef BSV_POSITIVE_RESET
  `define BSV_RESET_VALUE 1'b1
  `define BSV_RESET_EDGE posedge
`else
  `define BSV_RESET_VALUE 1'b0
  `define BSV_RESET_EDGE negedge
`endif

module mkMem_Model(CLK,
		   RST_N,

		   awvalid,
		   awid,
		   awaddr,
		   awlen,
		   awsize,
		   awburst,
		   awlock,
		   awcache,
		   awprot,
		   awqos,
		   awregion,

		   awready,

		   wvalid,
		   wdata,
		   wstrb,
		   wlast,

		   wready,

		   bvalid,

		   bid,

		   bresp,

		   bready,

		   arvalid,
		   arid,
		   araddr,
		   arlen,
		   arsize,
		   arburst,
		   arlock,
		   arcache,
		   arprot,
		   arqos,
		   arregion,

		   arready,

		   rvalid,

		   rid,

		   rdata,

		   rresp,

		   rlast,

		   rready);
  parameter [1 : 0] ddr4_num = 2'b0;
  input  CLK;
  input  RST_N;

  // action method m_awvalid
  input  awvalid;
  input  [15 : 0] awid;
  input  [63 : 0] awaddr;
  input  [7 : 0] awlen;
  input  [2 : 0] awsize;
  input  [1 : 0] awburst;
  input  awlock;
  input  [3 : 0] awcache;
  input  [2 : 0] awprot;
  input  [3 : 0] awqos;
  input  [3 : 0] awregion;

  // value method m_awready
  output awready;

  // action method m_wvalid
  input  wvalid;
  input  [511 : 0] wdata;
  input  [63 : 0] wstrb;
  input  wlast;

  // value method m_wready
  output wready;

  // value method m_bvalid
  output bvalid;

  // value method m_bid
  output [15 : 0] bid;

  // value method m_bresp
  output [1 : 0] bresp;

  // value method m_buser

  // action method m_bready
  input  bready;

  // action method m_arvalid
  input  arvalid;
  input  [15 : 0] arid;
  input  [63 : 0] araddr;
  input  [7 : 0] arlen;
  input  [2 : 0] arsize;
  input  [1 : 0] arburst;
  input  arlock;
  input  [3 : 0] arcache;
  input  [2 : 0] arprot;
  input  [3 : 0] arqos;
  input  [3 : 0] arregion;

  // value method m_arready
  output arready;

  // value method m_rvalid
  output rvalid;

  // value method m_rid
  output [15 : 0] rid;

  // value method m_rdata
  output [511 : 0] rdata;

  // value method m_rresp
  output [1 : 0] rresp;

  // value method m_rlast
  output rlast;

  // value method m_ruser

  // action method m_rready
  input  rready;

  // signals for module outputs
  wire [511 : 0] rdata;
  wire [15 : 0] bid, rid;
  wire [1 : 0] bresp, rresp;
  wire arready, awready, bvalid, rlast, rvalid, wready;

  // ports of submodule axi4_xactor_f_rd_addr
  wire [108 : 0] axi4_xactor_f_rd_addr$D_IN, axi4_xactor_f_rd_addr$D_OUT;
  wire axi4_xactor_f_rd_addr$CLR,
       axi4_xactor_f_rd_addr$DEQ,
       axi4_xactor_f_rd_addr$EMPTY_N,
       axi4_xactor_f_rd_addr$ENQ,
       axi4_xactor_f_rd_addr$FULL_N;

  // ports of submodule axi4_xactor_f_rd_data
  wire [530 : 0] axi4_xactor_f_rd_data$D_IN, axi4_xactor_f_rd_data$D_OUT;
  wire axi4_xactor_f_rd_data$CLR,
       axi4_xactor_f_rd_data$DEQ,
       axi4_xactor_f_rd_data$EMPTY_N,
       axi4_xactor_f_rd_data$ENQ,
       axi4_xactor_f_rd_data$FULL_N;

  // ports of submodule axi4_xactor_f_wr_addr
  wire [108 : 0] axi4_xactor_f_wr_addr$D_IN, axi4_xactor_f_wr_addr$D_OUT;
  wire axi4_xactor_f_wr_addr$CLR,
       axi4_xactor_f_wr_addr$DEQ,
       axi4_xactor_f_wr_addr$EMPTY_N,
       axi4_xactor_f_wr_addr$ENQ,
       axi4_xactor_f_wr_addr$FULL_N;

  // ports of submodule axi4_xactor_f_wr_data
  wire [576 : 0] axi4_xactor_f_wr_data$D_IN, axi4_xactor_f_wr_data$D_OUT;
  wire axi4_xactor_f_wr_data$CLR,
       axi4_xactor_f_wr_data$DEQ,
       axi4_xactor_f_wr_data$EMPTY_N,
       axi4_xactor_f_wr_data$ENQ,
       axi4_xactor_f_wr_data$FULL_N;

  // ports of submodule axi4_xactor_f_wr_resp
  wire [17 : 0] axi4_xactor_f_wr_resp$D_IN, axi4_xactor_f_wr_resp$D_OUT;
  wire axi4_xactor_f_wr_resp$CLR,
       axi4_xactor_f_wr_resp$DEQ,
       axi4_xactor_f_wr_resp$EMPTY_N,
       axi4_xactor_f_wr_resp$ENQ,
       axi4_xactor_f_wr_resp$FULL_N;

  // ports of submodule rf
  wire [511 : 0] rf$D_IN, rf$D_OUT_1, rf$D_OUT_2;
  wire [63 : 0] rf$ADDR_1,
		rf$ADDR_2,
		rf$ADDR_3,
		rf$ADDR_4,
		rf$ADDR_5,
		rf$ADDR_IN;
  wire rf$WE;

  // rule scheduling signals
  wire CAN_FIRE_RL_rl_rd_req,
       CAN_FIRE_RL_rl_wr_req,
       CAN_FIRE_m_arvalid,
       CAN_FIRE_m_awvalid,
       CAN_FIRE_m_bready,
       CAN_FIRE_m_rready,
       CAN_FIRE_m_wvalid,
       WILL_FIRE_RL_rl_rd_req,
       WILL_FIRE_RL_rl_wr_req,
       WILL_FIRE_m_arvalid,
       WILL_FIRE_m_awvalid,
       WILL_FIRE_m_bready,
       WILL_FIRE_m_rready,
       WILL_FIRE_m_wvalid;

  // declarations used by system tasks
  // synopsys translate_off
  reg [31 : 0] v__h838;
  reg [31 : 0] v__h928;
  reg [31 : 0] v__h1268;
  reg [31 : 0] v__h1336;
  reg [31 : 0] v__h832;
  reg [31 : 0] v__h922;
  reg [31 : 0] v__h1262;
  reg [31 : 0] v__h1330;
  // synopsys translate_on

  // remaining internal signals
  wire [511 : 0] mask__h1402,
		 x1_avValue_rdata__h1008,
		 x__h1413,
		 y__h1414,
		 y__h1415,
		 y_avValue_rdata__h1020;
  wire [63 : 0] addr_base__h679,
		addr_impl_last__h681,
		addr_last__h680,
		offset_b__h1215,
		offset_b__h783;
  wire [1 : 0] x1_avValue_rresp__h1027;
  wire NOT_axi4_xactor_f_rd_addr_first_BITS_92_TO_29__ETC___d19,
       _0b0_CONCAT_ddr4_num_CONCAT_0x0_ULE_axi4_xactor_ETC___d40,
       _0b0_CONCAT_ddr4_num_CONCAT_0x0_ULE_axi4_xactor_ETC___d7,
       axi4_xactor_f_rd_addr_first_BITS_92_TO_29_ULE__ETC___d10,
       axi4_xactor_f_wr_addr_first__8_BITS_92_TO_29_9_ETC___d42,
       axi4_xactor_f_wr_addr_first__8_BITS_92_TO_29_9_ETC___d52;

  // action method m_awvalid
  assign CAN_FIRE_m_awvalid = 1'd1 ;
  assign WILL_FIRE_m_awvalid = 1'd1 ;

  // value method m_awready
  assign awready = axi4_xactor_f_wr_addr$FULL_N ;

  // action method m_wvalid
  assign CAN_FIRE_m_wvalid = 1'd1 ;
  assign WILL_FIRE_m_wvalid = 1'd1 ;

  // value method m_wready
  assign wready = axi4_xactor_f_wr_data$FULL_N ;

  // value method m_bvalid
  assign bvalid = axi4_xactor_f_wr_resp$EMPTY_N ;

  // value method m_bid
  assign bid = axi4_xactor_f_wr_resp$D_OUT[17:2] ;

  // value method m_bresp
  assign bresp = axi4_xactor_f_wr_resp$D_OUT[1:0] ;

  // action method m_bready
  assign CAN_FIRE_m_bready = 1'd1 ;
  assign WILL_FIRE_m_bready = 1'd1 ;

  // action method m_arvalid
  assign CAN_FIRE_m_arvalid = 1'd1 ;
  assign WILL_FIRE_m_arvalid = 1'd1 ;

  // value method m_arready
  assign arready = axi4_xactor_f_rd_addr$FULL_N ;

  // value method m_rvalid
  assign rvalid = axi4_xactor_f_rd_data$EMPTY_N ;

  // value method m_rid
  assign rid = axi4_xactor_f_rd_data$D_OUT[530:515] ;

  // value method m_rdata
  assign rdata = axi4_xactor_f_rd_data$D_OUT[514:3] ;

  // value method m_rresp
  assign rresp = axi4_xactor_f_rd_data$D_OUT[2:1] ;

  // value method m_rlast
  assign rlast = axi4_xactor_f_rd_data$D_OUT[0] ;

  // action method m_rready
  assign CAN_FIRE_m_rready = 1'd1 ;
  assign WILL_FIRE_m_rready = 1'd1 ;

  // submodule axi4_xactor_f_rd_addr
  FIFO2 #(.width(32'd109), .guarded(32'd1)) axi4_xactor_f_rd_addr(.RST(RST_N),
								  .CLK(CLK),
								  .D_IN(axi4_xactor_f_rd_addr$D_IN),
								  .ENQ(axi4_xactor_f_rd_addr$ENQ),
								  .DEQ(axi4_xactor_f_rd_addr$DEQ),
								  .CLR(axi4_xactor_f_rd_addr$CLR),
								  .D_OUT(axi4_xactor_f_rd_addr$D_OUT),
								  .FULL_N(axi4_xactor_f_rd_addr$FULL_N),
								  .EMPTY_N(axi4_xactor_f_rd_addr$EMPTY_N));

  // submodule axi4_xactor_f_rd_data
  FIFO2 #(.width(32'd531), .guarded(32'd1)) axi4_xactor_f_rd_data(.RST(RST_N),
								  .CLK(CLK),
								  .D_IN(axi4_xactor_f_rd_data$D_IN),
								  .ENQ(axi4_xactor_f_rd_data$ENQ),
								  .DEQ(axi4_xactor_f_rd_data$DEQ),
								  .CLR(axi4_xactor_f_rd_data$CLR),
								  .D_OUT(axi4_xactor_f_rd_data$D_OUT),
								  .FULL_N(axi4_xactor_f_rd_data$FULL_N),
								  .EMPTY_N(axi4_xactor_f_rd_data$EMPTY_N));

  // submodule axi4_xactor_f_wr_addr
  FIFO2 #(.width(32'd109), .guarded(32'd1)) axi4_xactor_f_wr_addr(.RST(RST_N),
								  .CLK(CLK),
								  .D_IN(axi4_xactor_f_wr_addr$D_IN),
								  .ENQ(axi4_xactor_f_wr_addr$ENQ),
								  .DEQ(axi4_xactor_f_wr_addr$DEQ),
								  .CLR(axi4_xactor_f_wr_addr$CLR),
								  .D_OUT(axi4_xactor_f_wr_addr$D_OUT),
								  .FULL_N(axi4_xactor_f_wr_addr$FULL_N),
								  .EMPTY_N(axi4_xactor_f_wr_addr$EMPTY_N));

  // submodule axi4_xactor_f_wr_data
  FIFO2 #(.width(32'd577), .guarded(32'd1)) axi4_xactor_f_wr_data(.RST(RST_N),
								  .CLK(CLK),
								  .D_IN(axi4_xactor_f_wr_data$D_IN),
								  .ENQ(axi4_xactor_f_wr_data$ENQ),
								  .DEQ(axi4_xactor_f_wr_data$DEQ),
								  .CLR(axi4_xactor_f_wr_data$CLR),
								  .D_OUT(axi4_xactor_f_wr_data$D_OUT),
								  .FULL_N(axi4_xactor_f_wr_data$FULL_N),
								  .EMPTY_N(axi4_xactor_f_wr_data$EMPTY_N));

  // submodule axi4_xactor_f_wr_resp
  FIFO2 #(.width(32'd18), .guarded(32'd1)) axi4_xactor_f_wr_resp(.RST(RST_N),
								 .CLK(CLK),
								 .D_IN(axi4_xactor_f_wr_resp$D_IN),
								 .ENQ(axi4_xactor_f_wr_resp$ENQ),
								 .DEQ(axi4_xactor_f_wr_resp$DEQ),
								 .CLR(axi4_xactor_f_wr_resp$CLR),
								 .D_OUT(axi4_xactor_f_wr_resp$D_OUT),
								 .FULL_N(axi4_xactor_f_wr_resp$FULL_N),
								 .EMPTY_N(axi4_xactor_f_wr_resp$EMPTY_N));

  // submodule rf
  RegFile #(.addr_width(32'd64),
	    .data_width(32'd512),
	    .lo(64'd0),
	    .hi(64'd67108863)) rf(.CLK(CLK),
				  .ADDR_1(rf$ADDR_1),
				  .ADDR_2(rf$ADDR_2),
				  .ADDR_3(rf$ADDR_3),
				  .ADDR_4(rf$ADDR_4),
				  .ADDR_5(rf$ADDR_5),
				  .ADDR_IN(rf$ADDR_IN),
				  .D_IN(rf$D_IN),
				  .WE(rf$WE),
				  .D_OUT_1(rf$D_OUT_1),
				  .D_OUT_2(rf$D_OUT_2),
				  .D_OUT_3(),
				  .D_OUT_4(),
				  .D_OUT_5());

  // rule RL_rl_rd_req
  assign CAN_FIRE_RL_rl_rd_req =
	     axi4_xactor_f_rd_addr$EMPTY_N && axi4_xactor_f_rd_data$FULL_N ;
  assign WILL_FIRE_RL_rl_rd_req = CAN_FIRE_RL_rl_rd_req ;

  // rule RL_rl_wr_req
  assign CAN_FIRE_RL_rl_wr_req =
	     axi4_xactor_f_wr_addr$EMPTY_N && axi4_xactor_f_wr_data$EMPTY_N &&
	     axi4_xactor_f_wr_resp$FULL_N ;
  assign WILL_FIRE_RL_rl_wr_req = CAN_FIRE_RL_rl_wr_req ;

  // submodule axi4_xactor_f_rd_addr
  assign axi4_xactor_f_rd_addr$D_IN =
	     { arid,
	       araddr,
	       arlen,
	       arsize,
	       arburst,
	       arlock,
	       arcache,
	       arprot,
	       arqos,
	       arregion } ;
  assign axi4_xactor_f_rd_addr$ENQ = arvalid && axi4_xactor_f_rd_addr$FULL_N ;
  assign axi4_xactor_f_rd_addr$DEQ = CAN_FIRE_RL_rl_rd_req ;
  assign axi4_xactor_f_rd_addr$CLR = 1'b0 ;

  // submodule axi4_xactor_f_rd_data
  assign axi4_xactor_f_rd_data$D_IN =
	     { axi4_xactor_f_rd_addr$D_OUT[108:93],
	       x1_avValue_rdata__h1008,
	       x1_avValue_rresp__h1027,
	       1'd1 } ;
  assign axi4_xactor_f_rd_data$ENQ = CAN_FIRE_RL_rl_rd_req ;
  assign axi4_xactor_f_rd_data$DEQ = rready && axi4_xactor_f_rd_data$EMPTY_N ;
  assign axi4_xactor_f_rd_data$CLR = 1'b0 ;

  // submodule axi4_xactor_f_wr_addr
  assign axi4_xactor_f_wr_addr$D_IN =
	     { awid,
	       awaddr,
	       awlen,
	       awsize,
	       awburst,
	       awlock,
	       awcache,
	       awprot,
	       awqos,
	       awregion } ;
  assign axi4_xactor_f_wr_addr$ENQ = awvalid && axi4_xactor_f_wr_addr$FULL_N ;
  assign axi4_xactor_f_wr_addr$DEQ = CAN_FIRE_RL_rl_wr_req ;
  assign axi4_xactor_f_wr_addr$CLR = 1'b0 ;

  // submodule axi4_xactor_f_wr_data
  assign axi4_xactor_f_wr_data$D_IN = { wdata, wstrb, wlast } ;
  assign axi4_xactor_f_wr_data$ENQ = wvalid && axi4_xactor_f_wr_data$FULL_N ;
  assign axi4_xactor_f_wr_data$DEQ = CAN_FIRE_RL_rl_wr_req ;
  assign axi4_xactor_f_wr_data$CLR = 1'b0 ;

  // submodule axi4_xactor_f_wr_resp
  assign axi4_xactor_f_wr_resp$D_IN =
	     { axi4_xactor_f_wr_addr$D_OUT[108:93],
	       (!_0b0_CONCAT_ddr4_num_CONCAT_0x0_ULE_axi4_xactor_ETC___d40 ||
		!axi4_xactor_f_wr_addr_first__8_BITS_92_TO_29_9_ETC___d42 ||
		!axi4_xactor_f_wr_addr_first__8_BITS_92_TO_29_9_ETC___d52) ?
		 2'b10 :
		 2'b0 } ;
  assign axi4_xactor_f_wr_resp$ENQ = CAN_FIRE_RL_rl_wr_req ;
  assign axi4_xactor_f_wr_resp$DEQ = bready && axi4_xactor_f_wr_resp$EMPTY_N ;
  assign axi4_xactor_f_wr_resp$CLR = 1'b0 ;

  // submodule rf
  assign rf$ADDR_1 = { 6'd0, offset_b__h1215[63:6] } ;
  assign rf$ADDR_2 = { 6'd0, offset_b__h783[63:6] } ;
  assign rf$ADDR_3 = 64'h0 ;
  assign rf$ADDR_4 = 64'h0 ;
  assign rf$ADDR_5 = 64'h0 ;
  assign rf$ADDR_IN = { 6'd0, offset_b__h1215[63:6] } ;
  assign rf$D_IN = x__h1413 | y__h1414 ;
  assign rf$WE =
	     WILL_FIRE_RL_rl_wr_req &&
	     _0b0_CONCAT_ddr4_num_CONCAT_0x0_ULE_axi4_xactor_ETC___d40 &&
	     axi4_xactor_f_wr_addr_first__8_BITS_92_TO_29_9_ETC___d42 &&
	     axi4_xactor_f_wr_addr_first__8_BITS_92_TO_29_9_ETC___d52 ;

  // remaining internal signals
  assign NOT_axi4_xactor_f_rd_addr_first_BITS_92_TO_29__ETC___d19 =
	     offset_b__h783 > addr_impl_last__h681 ;
  assign _0b0_CONCAT_ddr4_num_CONCAT_0x0_ULE_axi4_xactor_ETC___d40 =
	     addr_base__h679 <= axi4_xactor_f_wr_addr$D_OUT[92:29] ;
  assign _0b0_CONCAT_ddr4_num_CONCAT_0x0_ULE_axi4_xactor_ETC___d7 =
	     addr_base__h679 <= axi4_xactor_f_rd_addr$D_OUT[92:29] ;
  assign addr_base__h679 = { 28'b0, ddr4_num, 34'h0 } ;
  assign addr_impl_last__h681 = addr_base__h679 + 64'h00000000FFFFFFFF ;
  assign addr_last__h680 = { 28'b0, ddr4_num, 34'h3FFFFFFFF } ;
  assign axi4_xactor_f_rd_addr_first_BITS_92_TO_29_ULE__ETC___d10 =
	     axi4_xactor_f_rd_addr$D_OUT[92:29] <= addr_last__h680 ;
  assign axi4_xactor_f_wr_addr_first__8_BITS_92_TO_29_9_ETC___d42 =
	     axi4_xactor_f_wr_addr$D_OUT[92:29] <= addr_last__h680 ;
  assign axi4_xactor_f_wr_addr_first__8_BITS_92_TO_29_9_ETC___d52 =
	     offset_b__h1215 <= addr_impl_last__h681 ;
  assign mask__h1402 =
	     { axi4_xactor_f_wr_data$D_OUT[64] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[63] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[62] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[61] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[60] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[59] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[58] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[57] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[56] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[55] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[54] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[53] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[52] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[51] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[50] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[49] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[48] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[47] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[46] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[45] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[44] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[43] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[42] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[41] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[40] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[39] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[38] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[37] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[36] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[35] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[34] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[33] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[32] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[31] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[30] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[29] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[28] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[27] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[26] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[25] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[24] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[23] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[22] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[21] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[20] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[19] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[18] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[17] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[16] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[15] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[14] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[13] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[12] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[11] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[10] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[9] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[8] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[7] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[6] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[5] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[4] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[3] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[2] ? 8'hFF : 8'h0,
	       axi4_xactor_f_wr_data$D_OUT[1] ? 8'hFF : 8'h0 } ;
  assign offset_b__h1215 =
	     axi4_xactor_f_wr_addr$D_OUT[92:29] - addr_base__h679 ;
  assign offset_b__h783 =
	     axi4_xactor_f_rd_addr$D_OUT[92:29] - addr_base__h679 ;
  assign x1_avValue_rdata__h1008 =
	     (!_0b0_CONCAT_ddr4_num_CONCAT_0x0_ULE_axi4_xactor_ETC___d7 ||
	      !axi4_xactor_f_rd_addr_first_BITS_92_TO_29_ULE__ETC___d10 ||
	      NOT_axi4_xactor_f_rd_addr_first_BITS_92_TO_29__ETC___d19) ?
	       y_avValue_rdata__h1020 :
	       rf$D_OUT_2 ;
  assign x1_avValue_rresp__h1027 =
	     (!_0b0_CONCAT_ddr4_num_CONCAT_0x0_ULE_axi4_xactor_ETC___d7 ||
	      !axi4_xactor_f_rd_addr_first_BITS_92_TO_29_ULE__ETC___d10 ||
	      NOT_axi4_xactor_f_rd_addr_first_BITS_92_TO_29__ETC___d19) ?
	       2'b10 :
	       2'b0 ;
  assign x__h1413 = rf$D_OUT_1 & y__h1415 ;
  assign y__h1414 = axi4_xactor_f_wr_data$D_OUT[576:65] & mask__h1402 ;
  assign y__h1415 =
	     { axi4_xactor_f_wr_data$D_OUT[64] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[63] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[62] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[61] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[60] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[59] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[58] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[57] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[56] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[55] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[54] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[53] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[52] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[51] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[50] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[49] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[48] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[47] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[46] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[45] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[44] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[43] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[42] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[41] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[40] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[39] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[38] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[37] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[36] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[35] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[34] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[33] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[32] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[31] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[30] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[29] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[28] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[27] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[26] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[25] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[24] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[23] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[22] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[21] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[20] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[19] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[18] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[17] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[16] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[15] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[14] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[13] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[12] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[11] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[10] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[9] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[8] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[7] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[6] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[5] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[4] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[3] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[2] ? 8'd0 : 8'd255,
	       axi4_xactor_f_wr_data$D_OUT[1] ? 8'd0 : 8'd255 } ;
  assign y_avValue_rdata__h1020 =
	     { 448'd0, axi4_xactor_f_rd_addr$D_OUT[92:29] } ;

  // handling of system tasks

  // synopsys translate_off
  always@(negedge CLK)
  begin
    #0;
    if (RST_N != `BSV_RESET_VALUE)
      if (WILL_FIRE_RL_rl_rd_req &&
	  (!_0b0_CONCAT_ddr4_num_CONCAT_0x0_ULE_axi4_xactor_ETC___d7 ||
	   !axi4_xactor_f_rd_addr_first_BITS_92_TO_29_ULE__ETC___d10))
	begin
	  v__h838 = $stime;
	  #0;
	end
    v__h832 = v__h838 / 32'd10;
    if (RST_N != `BSV_RESET_VALUE)
      if (WILL_FIRE_RL_rl_rd_req &&
	  (!_0b0_CONCAT_ddr4_num_CONCAT_0x0_ULE_axi4_xactor_ETC___d7 ||
	   !axi4_xactor_f_rd_addr_first_BITS_92_TO_29_ULE__ETC___d10))
	$display("%0d: Mem_Model [%0d]: rl_rd_req: @ %0h -> OUT OF BOUNDS",
		 v__h832,
		 ddr4_num,
		 axi4_xactor_f_rd_addr$D_OUT[92:29]);
    if (RST_N != `BSV_RESET_VALUE)
      if (WILL_FIRE_RL_rl_rd_req &&
	  _0b0_CONCAT_ddr4_num_CONCAT_0x0_ULE_axi4_xactor_ETC___d7 &&
	  axi4_xactor_f_rd_addr_first_BITS_92_TO_29_ULE__ETC___d10 &&
	  NOT_axi4_xactor_f_rd_addr_first_BITS_92_TO_29__ETC___d19)
	begin
	  v__h928 = $stime;
	  #0;
	end
    v__h922 = v__h928 / 32'd10;
    if (RST_N != `BSV_RESET_VALUE)
      if (WILL_FIRE_RL_rl_rd_req &&
	  _0b0_CONCAT_ddr4_num_CONCAT_0x0_ULE_axi4_xactor_ETC___d7 &&
	  axi4_xactor_f_rd_addr_first_BITS_92_TO_29_ULE__ETC___d10 &&
	  NOT_axi4_xactor_f_rd_addr_first_BITS_92_TO_29__ETC___d19)
	$display("%0d: Mem_Model [%0d]: rl_rd_req: @ %0h -> OUT OF IMPLEMENTED BOUNDS",
		 v__h922,
		 ddr4_num,
		 axi4_xactor_f_rd_addr$D_OUT[92:29]);
    if (RST_N != `BSV_RESET_VALUE)
      if (WILL_FIRE_RL_rl_wr_req &&
	  (!_0b0_CONCAT_ddr4_num_CONCAT_0x0_ULE_axi4_xactor_ETC___d40 ||
	   !axi4_xactor_f_wr_addr_first__8_BITS_92_TO_29_9_ETC___d42))
	begin
	  v__h1268 = $stime;
	  #0;
	end
    v__h1262 = v__h1268 / 32'd10;
    if (RST_N != `BSV_RESET_VALUE)
      if (WILL_FIRE_RL_rl_wr_req &&
	  (!_0b0_CONCAT_ddr4_num_CONCAT_0x0_ULE_axi4_xactor_ETC___d40 ||
	   !axi4_xactor_f_wr_addr_first__8_BITS_92_TO_29_9_ETC___d42))
	$display("%0d: Mem_Model [%0d]: rl_wr_req: @ %0h <= %0h strb %0h: OUT OF BOUNDS",
		 v__h1262,
		 ddr4_num,
		 axi4_xactor_f_wr_addr$D_OUT[92:29],
		 axi4_xactor_f_wr_data$D_OUT[576:65],
		 axi4_xactor_f_wr_data$D_OUT[64:1]);
    if (RST_N != `BSV_RESET_VALUE)
      if (WILL_FIRE_RL_rl_wr_req &&
	  _0b0_CONCAT_ddr4_num_CONCAT_0x0_ULE_axi4_xactor_ETC___d40 &&
	  axi4_xactor_f_wr_addr_first__8_BITS_92_TO_29_9_ETC___d42 &&
	  !axi4_xactor_f_wr_addr_first__8_BITS_92_TO_29_9_ETC___d52)
	begin
	  v__h1336 = $stime;
	  #0;
	end
    v__h1330 = v__h1336 / 32'd10;
    if (RST_N != `BSV_RESET_VALUE)
      if (WILL_FIRE_RL_rl_wr_req &&
	  _0b0_CONCAT_ddr4_num_CONCAT_0x0_ULE_axi4_xactor_ETC___d40 &&
	  axi4_xactor_f_wr_addr_first__8_BITS_92_TO_29_9_ETC___d42 &&
	  !axi4_xactor_f_wr_addr_first__8_BITS_92_TO_29_9_ETC___d52)
	$display("%0d: Mem_Model [%0d]: rl_wr_req: @ %0h <= %0h strb %0h: OUT OF IMPLEMENTED BOUNDS",
		 v__h1330,
		 ddr4_num,
		 axi4_xactor_f_wr_addr$D_OUT[92:29],
		 axi4_xactor_f_wr_data$D_OUT[576:65],
		 axi4_xactor_f_wr_data$D_OUT[64:1]);
  end
  // synopsys translate_on
endmodule  // mkMem_Model

