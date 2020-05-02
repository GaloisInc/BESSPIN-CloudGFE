// Copyright (c) 2016-2020 Bluespec, Inc. All Rights Reserved.
// Author: Rishiyur S. Nikhil

package AWS_OCL_Adapter;

// ================================================================
// This package connects the AWS OCL AXI4-Lite port to WindSoC's Debug
// Module and UART.

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

// ================================================================
// Project imports

import External_Control :: *;    // Control requests/responses from HSFE
import AXI4_Lite_Types  :: *;
import AWS_BSV_Top_Defs :: *;

// ================================================================
// This OCL slave services a variety of host-side commands,
// distinguished by the OCL 32-bit address.  The upper 16b of the 32b
// address identifies the class of command:

Integer ocl_client_control  = 1;
Integer ocl_client_UART     = 2;
Integer ocl_client_debugger = 3;

function Bool fv_addr_is_for_control (Bit #(32) axi4L_addr);
   return (axi4L_addr [31:16] == fromInteger (ocl_client_control));
endfunction

function Bool fv_addr_is_for_UART (Bit #(32) axi4L_addr);
   return (axi4L_addr [31:16] == fromInteger (ocl_client_UART));
endfunction

`ifdef INCLUDE_GDB_CONTROL
function Bool fv_addr_is_for_Debug_Module (Bit #(32) axi4L_addr);
   return (axi4L_addr [31:16] == fromInteger (ocl_client_debugger));
endfunction
`endif

function Bool fv_addr_is_for_unknown (Bit #(32) axi4L_addr);
   Bit #(16) id = axi4L_addr [31:16];
   return (   (id != fromInteger (ocl_client_control))
	   && (id != fromInteger (ocl_client_UART))
`ifdef INCLUDE_GDB_CONTROL
	   && (id != fromInteger (ocl_client_debugger))
`endif
	   );
endfunction

// Addresses within the control class
Integer control_addr_verbosity   = 'h4;
Integer control_addr_tohost      = 'h8;
Integer control_addr_ddr4_loaded = 'hc;

// ================================================================
// INTERFACE

typedef struct {
   Bit #(4)   verbosity;
   Bit #(64)  logdelay;

   Bool       watch_tohost;
   Bit #(64)  tohost_addr;

   Bool       ddr4_loaded;
   } Test_Control
deriving (Bits, FShow);


interface OCL_Adapter_IFC;
   // Facing SH: OCL
   interface AXI4L_32_32_0_Slave_IFC ocl_slave;

   // ----------------------------------------------------------------
   // Facing WindSoC

   // ----------------
   // Control

   // Control data from host
   method Test_Control mv_test_control;

   // Control data to host
   method Action ma_set_status (Bit #(32) status);

   // ----------------
   // UART0

   interface Put #(Bit #(8)) put_to_console;      // for DUT to send a byte to host
   interface Get #(Bit #(8)) get_from_console;    // for DUT to recv a byte from host

`ifdef INCLUDE_GDB_CONTROL
   // ----------------
   // Debug Module

   interface Client #(Control_Req, Control_Rsp) external_control_client;
`endif
endinterface

// ================================================================

(* synthesize *)
module mkOCL_Adapter (OCL_Adapter_IFC);

   // 0: quiet; 1: rules
   Integer verbosity = 0;

   // Transactor for the OCL AXI4-Lite interface
   AXI4L_32_32_0_Slave_Xactor_IFC  ocl_xactor <- mkAXI4_Lite_Slave_Xactor;

   // Controls from host
   Reg #(Maybe #(Bit #(32))) rg_mb_control_data <- mkReg (tagged Invalid);

   // UART bytes
   FIFOF #(Bit #(8)) f_to_console   <- mkFIFOF;
   FIFOF #(Bit #(8)) f_from_console <- mkFIFOF;

`ifdef INCLUDE_GDB_CONTROL
   // Debugger requests and responses
   // TODO: this 'control' has nothing to do with 'control_data' above;
   //       we should clean up these names to avoid confusion.
   FIFOF #(Control_Req) f_control_reqs <- mkFIFOF;
   FIFOF #(Control_Rsp) f_control_rsps <- mkFIFOF;
`endif

   // ----------------
   // This FIFO remembers the OCL request addr, so we can respond to
   // split-phase read-requests appropriately.
   FIFOF #(Bit #(32)) f_ocl_addr <- mkFIFOF;

   // ----------------
   // Control info

   // Set verbosity of CPU to this value after logdelay cycles
   Reg #(Bit #(4))  rg_verbosity <- mkReg (0);
   Reg #(Bit #(64)) rg_logdelay  <- mkReg (0);

   // 'watch_tohost' specifies if the mem location at 'tohost_addr'
   // should be watched for non-zero writes (ISA test convention).
   // cf. 'htif' in original Spike, Berkeley stuff.

   Reg #(Bool)      rg_watch_tohost <- mkReg (False);
   Reg #(Bit #(64)) rg_tohost_addr  <- mkReg (0);

   // Signal from host that it has initialized contents of memory.
   Reg #(Bool) rg_ddr4_loaded <- mkReg (False);

   // Signal to host about hw-side status
   // [ For now: 0 = 'still running', 1 = 'tohost written', 2 = 'memory error' ]
   Reg #(Bit #(32)) rg_status <- mkReg (0);

   // ================================================================
   // OCL requests

   // Write requests (AXI4-Lite channels WR_ADDR, WR_DATA and WR_RESP)
   // (we send OCL response to write-requests immediately, in this rule.)
   rule rl_ocl_wr_req;    // req from AWS SH
      let wra  <- pop_o (ocl_xactor.o_wr_addr);
      let wrd  <- pop_o (ocl_xactor.o_wr_data);
      let bresp = AXI4_LITE_OKAY;

      if (verbosity != 0)
	 $display ("AWS_OCL_Adapter.rl_ocl_wr_req: addr %0h data %0h", wra.awaddr, wrd.wdata);

      if (fv_addr_is_for_control (wra.awaddr)) begin
	 if (wra.awaddr [15:0] == fromInteger (control_addr_verbosity)) begin
	    rg_verbosity <= wrd.wdata [3:0];
	    rg_logdelay  <= zeroExtend (wrd.wdata & 32'h_FFFF_FFF0);
	    if (verbosity != 0)
	       $display ("    Control: verbosity %0d, logdelay %0h", rg_verbosity, rg_logdelay);
	 end
	 else if (wra.awaddr [15:0] == fromInteger (control_addr_tohost)) begin
	    rg_watch_tohost <= (wrd.wdata [0] == 0);    // Convention: misaligned if don't watch tohost
	    rg_tohost_addr  <= zeroExtend (wrd.wdata);
	    if (verbosity != 0)
	       $display ("    Control: watch_tohost %0d tohost_addr %0h ",
			 (wrd.wdata [2:0] != 0), wrd.wdata);
	 end
	 else if (wra.awaddr [15:0] == fromInteger (control_addr_ddr4_loaded)) begin
	    rg_ddr4_loaded <= True;
	    if (verbosity != 0)
	       $display ("    Control: ddr4 loaded");
	 end
	 else begin
	    bresp = AXI4_LITE_SLVERR;
	    $display ("AWS_OCL_Adapter: Control: ERROR: Unrecognized AWADDR");
	    $display ("    addr %0h data %0h", wra.awaddr, wrd.wdata);
	 end
      end

      else if (fv_addr_is_for_UART (wra.awaddr)) begin
	 let data8 = wrd.wdata [7:0];
	 f_from_console.enq (data8);
	 if (verbosity != 0)
	    $display ("    Byte from console to UART: %0h", data8);
      end

`ifdef INCLUDE_GDB_CONTROL
      else if (fv_addr_is_for_Debug_Module (wra.awaddr)) begin
	 Bit #(7) dm_addr = wra.awaddr [8:2];
	 let control_req = Control_Req {op:   external_control_req_op_write_control_fabric,
					arg1: zeroExtend (dm_addr),
					arg2: zeroExtend (wrd.wdata)};    // DMI data
	 f_control_reqs.enq (control_req);
	 if (verbosity != 0)
	    $display ("    Debug Module: dm_addr %0h data %0h", dm_addr, wrd.wdata);
      end
`endif

      else begin
	 bresp = AXI4_LITE_SLVERR;
	 $display ("AWS_OCL_Adapter.rl_ocl_wr_req: ERROR: unrecognized addr %0h, data %0h",
		   wra.awaddr, wrd.wdata);
	 $display ("    Responding with bresp ", fshow (bresp));
      end
      let wrr = AXI4_Lite_Wr_Resp {bresp: bresp, buser: ?};
      ocl_xactor.i_wr_resp.enq (wrr);
   endrule

   // Read requests (AXI4-Lite channel RD_ADDR).
   // (responses done in separate rules below, since unknown latency to serve.).
   (* descending_urgency = "rl_ocl_wr_req, rl_ocl_rd_req" *)    // this choice is arbitrary
   rule rl_ocl_rd_req;
      let rda <- pop_o (ocl_xactor.o_rd_addr);

      // Remember the addr for later response
      if (verbosity != 0)
	 $display ("AWS_OCL_Adapter.rl_ocl_rd_req: addr %0h", rda.araddr);
      f_ocl_addr.enq (rda.araddr);

      if (fv_addr_is_for_control (rda.araddr)) begin
	 if (verbosity != 0)
	    $display ("    Control (no op)");
      end

      else if (fv_addr_is_for_UART (rda.araddr)) begin
	 if (verbosity != 0)
	    $display ("    Request for byte from UART to console");
      end

`ifdef INCLUDE_GDB_CONTROL
      else if (fv_addr_is_for_Debug_Module (rda.araddr)) begin
	 Bit #(7) dm_addr = rda.araddr [8:2];
	 let control_req = Control_Req {op:   external_control_req_op_read_control_fabric,
					arg1: zeroExtend (dm_addr),
					arg2: 0};                      // DMI data
	 f_control_reqs.enq (control_req);
	 if (verbosity != 0)
	    $display ("    Debug Module read request: dm_addr %0h", dm_addr);
      end
`endif

      else begin
	 noAction;
      end
   endrule

   // ================================================================
   // OCL responses to OCL read-requests

   // Control responses
   rule rl_ocl_rd_rsp_control (fv_addr_is_for_control (f_ocl_addr.first));
      // For now, reads to any 'control' addr returns value of rg_status
      f_ocl_addr.deq;
      let rresp = AXI4_LITE_OKAY;
      let rdr = AXI4_Lite_Rd_Data {rresp: rresp,
				   rdata: rg_status,
				   ruser: ?};
      ocl_xactor.i_rd_data.enq (rdr);

      if (verbosity != 0)
	 $display ("AWS_BSV_Top.rl_ocl_rd_rsp_control: rresp", fshow (rresp));
   endrule

   // Read-Responses from UART to SH
   // TODO: This requires polling from the host; should we change it to avoid polling?
   // We return data '1 (FFFF_FFFF) if no UART data available
   rule rl_ocl_rd_rsp_UART (fv_addr_is_for_UART (f_ocl_addr.first));
      f_ocl_addr.deq;
      let data = '1;
      if (f_to_console.notEmpty) begin
	 let data8 <- pop (f_to_console);
	 data = zeroExtend (data8);
      end
      let rdr = AXI4_Lite_Rd_Data {rresp: AXI4_LITE_OKAY, rdata: data, ruser: ?};
      ocl_xactor.i_rd_data.enq (rdr);

      if (verbosity != 0)
	 $display ("AWS_BSV_Top.rl_ocl_rd_rsp_UART: data8 %0h", data);
   endrule

`ifdef INCLUDE_GDB_CONTROL
   // Read-responses from DM to SH
   rule rl_ocl_rd_rsp_DM (fv_addr_is_for_Debug_Module (f_ocl_addr.first));
      f_ocl_addr.deq;
      let control_rsp <- pop (f_control_rsps);
      let rresp = ((control_rsp.status == external_control_rsp_status_ok)
		   ? AXI4_LITE_OKAY
		   : AXI4_LITE_SLVERR);
      Bit #(32) rdata = truncate (control_rsp.result);
      let rdr = AXI4_Lite_Rd_Data {rresp: rresp, rdata: rdata, ruser: ?};
      ocl_xactor.i_rd_data.enq (rdr);

      if (verbosity != 0)
	 $display ("AWS_BSV_Top.rl_ocl_rd_rsp_DM: ", fshow (rresp), " data %0h", rdata);
   endrule
`endif

   rule rl_ocl_rd_rsp_unknown (fv_addr_is_for_unknown (f_ocl_addr.first));
      f_ocl_addr.deq;
      let rresp = AXI4_LITE_SLVERR;
      let rdr = AXI4_Lite_Rd_Data {rresp: rresp, rdata: 0, ruser: ?};
      ocl_xactor.i_rd_data.enq (rdr);

      if (verbosity != 0)
	 $display ("AWS_BSV_Top.rl_ocl_rd_rsp_unknown_addr: rresp", fshow (rresp));
   endrule

   // ================================================================
   // INTERFACE

   // Facing SH: OCL
   interface AWS_AXI4_Lite_Slave_IFC  ocl_slave = ocl_xactor.axi_side;

   // ----------------
   // Control

   // Control data from host
   method Test_Control mv_test_control;
      return Test_Control {verbosity:    rg_verbosity,
			   logdelay:     rg_logdelay,

			   watch_tohost: rg_watch_tohost,
			   tohost_addr:  rg_tohost_addr,

			   ddr4_loaded:  rg_ddr4_loaded};
   endmethod

   // Control data to host
   method Action ma_set_status (Bit #(32) status);
      rg_status <= status;
   endmethod

   // UART0
   interface Put put_to_console   = toPut (f_to_console);
   interface Get get_from_console = toGet (f_from_console);

`ifdef INCLUDE_GDB_CONTROL
   // Debug Module
   interface Client  external_control_client = toGPClient (f_control_reqs, f_control_rsps);
`endif
endmodule

// ================================================================

endpackage
