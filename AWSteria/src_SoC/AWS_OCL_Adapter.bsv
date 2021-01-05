// Copyright (c) 2016-2020 Bluespec, Inc. All Rights Reserved.
// Author: Rishiyur S. Nikhil

package AWS_OCL_Adapter;

// ================================================================
// The mkAWS_OCL_Adapter module has two faces:
// - Facing the host: slave AXI4-Lite port, connects to AWS OCL interface.
// - Facing SoC: a collection of Semi_FIFOF interfaces, 32-bit wide data.
//    Each is a unidirectional channel, mapped to an AXI4-Lite address.
// The host enqueues to a channel with a single write transaction
//         (response AXI4_LITE_SLVERR if full).
// The host dequeues from a channel with a single read transaction
//         (response is AXI4_LITE_SLVERR if empty).

// This module just transports, and does not interpret the 32-bit data
// transferred on these channels.

// ================================================================
// BSV library imports

import Vector :: *;
import FIFOF  :: *;
import GetPut :: *;

// ----------------
// BSV additional libs

import Semi_FIFOF :: *;

// ================================================================
// Project imports

import AXI4_Lite_Types  :: *;
import AWS_BSV_Top_Defs :: *;

// ================================================================
// Address configurations for host-to-hw and hw-to-host channels.

// Each channel is at an 8-byte-aligned address.
// So, channel id = offset [31:3]
// where offset   = addr - addr_base.

// For channel addr A, addr A+4 is its 'status' address.
// For hw-to-host channel addr A,
//    reading A   => dequeued data (if available, else undefined value)
//    reading A+4 => 'notEmpty' status    (dequeue will return data)
// For host-to-hw channel addr A,
//    reading A+4 => 'notFull'  status    (enq will succeed)
//    writing A   => enq data

// Channels in each direction are independent (an application may
// choose to interpret a pair as request/response).  The number of
// channels in each direction need not be the same.

typedef 5 Num_OCL_Host_to_HW_Channels;
typedef 4 Num_OCL_HW_to_Host_Channels;

Integer num_ocl_host_to_hw_channels = valueOf (Num_OCL_Host_to_HW_Channels);
Integer num_ocl_hw_to_host_channels = valueOf (Num_OCL_HW_to_Host_Channels);

// These base addrs must have lsbs = 2'h0

Bit #(32) ocl_hw_to_host_chan_addr_base = 32'h_0000_0000;
Bit #(32) ocl_host_to_hw_chan_addr_base = 32'h_0000_1000;

function Bit #(32) fv_chan_id (Bit #(32) addr, Bit #(32) addr_base);
   return ((addr - addr_base) >> 3);
endfunction

// ================================================================
// INTERFACE

interface OCL_Adapter_IFC;
   // ----------------
   // Facing SH: OCL
   interface AXI4L_32_32_0_Slave_IFC ocl_slave;

   // ----------------
   // Facing SoC
   interface Vector #(Num_OCL_Host_to_HW_Channels, FIFOF_O #(Bit #(32)))  v_from_host;
   interface Vector #(Num_OCL_HW_to_Host_Channels, FIFOF_I #(Bit #(32)))  v_to_host;
endinterface

// ================================================================

(* synthesize *)
module mkOCL_Adapter (OCL_Adapter_IFC);
   // 0: quiet; 1: rules
   Integer verbosity = 0;

   // Transactor for the OCL AXI4-Lite interface
   AXI4L_32_32_0_Slave_Xactor_IFC  ocl_xactor <- mkAXI4_Lite_Slave_Xactor;

   Vector #(Num_OCL_Host_to_HW_Channels, FIFOF #(Bit #(32))) v_f_from_host <- replicateM (mkFIFOF);
   Vector #(Num_OCL_HW_to_Host_Channels, FIFOF #(Bit #(32))) v_f_to_host   <- replicateM (mkFIFOF);

   // ================================================================
   // AXI4-Lite transactions

   // Write requests (AXI4-Lite channels WR_ADDR, WR_DATA and WR_RESP)
   // (we send the AXI4-Lite response immediately.)
   rule rl_AXI4L_wr;    // req from AWS SH
      let wra  <- pop_o (ocl_xactor.o_wr_addr);
      let wrd  <- pop_o (ocl_xactor.o_wr_data);
      if (verbosity != 0)
	 $display ("AWS_OCL_Adapter.rl_AXI4L_wr: addr %0h data %0h", wra.awaddr, wrd.wdata);

      // Default response
      let wrr = AXI4_Lite_Wr_Resp {bresp: AXI4_LITE_OKAY, buser: ?};

      if ((ocl_host_to_hw_chan_addr_base <= wra.awaddr)
	  && (fv_chan_id (wra.awaddr, ocl_host_to_hw_chan_addr_base)
	      < fromInteger (num_ocl_host_to_hw_channels)))
	 begin
	    let chan_id = fv_chan_id (wra.awaddr, ocl_host_to_hw_chan_addr_base);
	    if (v_f_from_host [chan_id].notFull) begin
	       v_f_from_host [chan_id].enq (wrd.wdata);
	       if (verbosity != 0)
		  $display ("    Host-to-hw chan [%0d] enq", chan_id);
	    end
	    else begin
	       wrr.bresp = AXI4_LITE_SLVERR;
	       $display ("ERROR: AWS_OCL_Adapter.rl_AXI4L_wr: addr %0h data %0h; chan [%0d] overflow",
			 wra.awaddr, wrd.wdata, chan_id);
	    end
	 end
      else begin
	 wrr.bresp = AXI4_LITE_DECERR;
	 $display ("ERROR: AWS_OCL_Adapter.rl_AXI4L_wr: addr %0h data %0h; unknown addr",
		   wra.awaddr, wrd.wdata);
      end

      ocl_xactor.i_wr_resp.enq (wrr);
      if (verbosity != 0) begin
	 $write ("    Response: ", fshow (wrr.bresp));
	 if (wrr.bresp == AXI4_LITE_SLVERR)
	    $write (" (full, declined)");
	 $displayh ("");
      end
   endrule

   // Read requests (AXI4-Lite channel RD_ADDR, RD_DATA).
   // (we send the AXI4-Lite response immediately.)
   // Reads can be for data in a hw-to-host channel
   // or for status (notFull/notEmpty) on hw-to-host and host-to-hw channels.
   // Address [2:0] is 3'b000 for data (read data only), 3'b100 for status.
   rule rl_AXI4L_rd;
      let rda <- pop_o (ocl_xactor.o_rd_addr);
      if (verbosity != 0)
	 $display ("AWS_OCL_Adapter.rl_AXI4L_rd: addr %0h", rda.araddr);

      // Default data: all 1's
      Bit #(32) rdata = 32'h_FFFF_FFFF;
      Bit #(0)  ruser = ?;
      let rdr = AXI4_Lite_Rd_Data {rresp: AXI4_LITE_OKAY, rdata: rdata, ruser: ruser};

      if ((ocl_host_to_hw_chan_addr_base <= rda.araddr)
	  && (fv_chan_id (rda.araddr, ocl_host_to_hw_chan_addr_base)
	      < fromInteger (num_ocl_host_to_hw_channels)))
	 begin
	    // host-to-hw channels: read status only
	    let chan_id = fv_chan_id (rda.araddr, ocl_host_to_hw_chan_addr_base);
	    if (rda.araddr [2:0] == 3'b100) begin
	       // Status
	       rdr.rdata = zeroExtend (pack (v_f_from_host [chan_id].notFull));
	       if (verbosity != 0)
		  $display ("    Host-to-HW chan [%0d] full status: %0d", chan_id, rdr.rdata);
	    end
	    else begin
	       rdr.rresp = AXI4_LITE_SLVERR;
	       $display ("ERROR: AWS_OCL_Adapter.rl_AXI4L_rd: ERROR: unknown rd addr %0h",
			 rda.araddr);
	    end
	 end

      else if ((ocl_hw_to_host_chan_addr_base <= rda.araddr)
	       && (fv_chan_id (rda.araddr, ocl_hw_to_host_chan_addr_base)
		   < fromInteger (num_ocl_hw_to_host_channels)))
	 begin
	    // hw-to-host channels: read status or data
	    let chan_id = fv_chan_id (rda.araddr, ocl_hw_to_host_chan_addr_base);
	    if (rda.araddr [2:0] == 3'b100) begin
	       // Status
	       rdr.rdata = zeroExtend (pack (v_f_to_host [chan_id].notEmpty));
	       if (verbosity != 0)
		  $display ("    HW-to-host chan [%0d] empty status: %0d", chan_id, rdr.rdata);
	    end
	    else if (v_f_to_host [chan_id].notEmpty) begin
	       // Data
	       rdr.rdata = v_f_to_host [chan_id].first;
	       v_f_to_host [chan_id].deq;
	       if (verbosity != 0)
		  $display ("    HW-to-host chan [%0d] data %0h", chan_id, rdr.rdata);
	    end
	    else begin
	       rdr.rresp = AXI4_LITE_SLVERR;
	       $display ("ERROR: AWS_OCL_Adapter.rl_AXI4L_rd: addr %0h; ERROR: data read on empty chan [%0d]",
			 rda.araddr, chan_id);
	    end
	 end

      else begin
	 rdr.rresp = AXI4_LITE_DECERR;
	 $display ("ERROR: AWS_OCL_Adapter.rl_AXI4L_rd: unknown read addr %0h",
		   rda.araddr);
      end

      // Note: rresp=AXI4_LITE_OKAY even for invalid requests since
      // AWS host-side API does not seem to provide access to rresp.

      ocl_xactor.i_rd_data.enq (rdr);
      if (verbosity != 0)
	 $display ("    response ", fshow (rdr));
   endrule

   // ================================================================
   // INTERFACE

   // ----------------
   // Facing SH: OCL
   interface AWS_AXI4_Lite_Slave_IFC  ocl_slave = ocl_xactor.axi_side;

   // ----------------
   // Facing SoC
   interface v_from_host = map (to_FIFOF_O, v_f_from_host);
   interface v_to_host   = map (to_FIFOF_I, v_f_to_host);

endmodule

// ================================================================

endpackage
