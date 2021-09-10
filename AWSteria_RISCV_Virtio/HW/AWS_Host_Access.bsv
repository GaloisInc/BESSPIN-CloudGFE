// Copyright (c) 2016-2021 Bluespec, Inc. All Rights Reserved.
// Author: Rishiyur S. Nikhil

package AWS_Host_Access;

// mkAWS_Host_Access is a simple AXI4 slave that is a 'proxy' for a
// the AWS host, which actually services all the AXI4 transactions.
// It simply forwards Read/Write requests (from the SoC fabric) to the
// AWS host, and forwards the responses from the AWS host back into
// the SoC fabric.

// All reads/writes are with 32-bit addrs, 32-bit aligned, for 32-bit data.

// Encoding:
// - Write requests: we send two 32-bit words:
//      - addr | 0x1 (because of 32b alignment, [1:0] of addr are
//                    always 0; we use [0]=1 as a 'write' tag)
//      - data
// - Read requests: we send one 32-bit word:
//      - addr | 0x0 (because of 32b alignment, [1:0] of addr are
//                    always 0; we use [0]=0 as a 'read' tag)
// - Responses: Each request eventually gets a 32-bit response:
//       the read-data for reads, any unspecified value for writes.

// ================================================================
// BSV library imports

import Vector        :: *;
import FIFOF         :: *;
import GetPut        :: *;
import ClientServer  :: *;

// ----------------
// BSV additional libs

import Cur_Cycle  :: *;
import GetPut_Aux :: *;
import Semi_FIFOF :: *;

// ================================================================
// Project imports

import AXI4_Types  :: *;
import Fabric_Defs :: *;

// ================================================================

interface AWS_Host_Access_IFC;
   // Main Fabric Reqs/Rsps
   interface AXI4_Slave_IFC #(Wd_Id, Wd_Addr, Wd_Data, Wd_User) slave;

   // Transport to/from host
   interface Get #(Bit #(32)) to_aws_host;
   interface Put #(Bit #(32)) from_aws_host;
endinterface

// ================================================================

(* synthesize *)
module mkAWS_Host_Access (AWS_Host_Access_IFC);

   // 0: quiet; 1 rules
   Integer verbosity = 1;

   FIFOF #(Bit #(32)) f_to_aws_host   <- mkFIFOF;
   FIFOF #(Bit #(32)) f_from_aws_host <- mkFIFOF;

   // Pending responses
   // First component is: 
   FIFOF #(Tuple4 #(Bit #(1),         // 0=read, 1=write
		    Bit #(32),        // addr lsbs, for aligning read-data to AXI bus
		    Bit #(Wd_Id),
		    Bit #(Wd_User)))  f_rsps_pending <- mkSizedFIFOF (32);

   // ----------------
   // Connector to AXI4 fabric

   AXI4_Slave_Xactor_IFC #(Wd_Id, Wd_Addr, Wd_Data, Wd_User) slave_xactor <- mkAXI4_Slave_Xactor;

   // ================================================================
   // BEHAVIOR
   // Note: ignoring many AXI4 fields, assuming 32-bit aligned data.

   Reg #(Maybe #(Bit #(32))) rg_wdata_pending <- mkReg (tagged Invalid);

   // ----------------------------------------------------------------
   // Read requests (RD_ADDR)

   rule rl_forward_rd_req_addr (rg_wdata_pending == tagged Invalid);
      let rda <- pop_o (slave_xactor.o_rd_addr);
      Bit #(32) addr = truncate (rda.araddr);
      Bit #(32) req  = ((addr & 32'h_FFFF_FFFC) | 32'h0);    // LSB 0 for 'read' req
      f_to_aws_host.enq (req);
      f_rsps_pending.enq (tuple4 (1'b0, addr, rda.arid, rda.aruser));

      if (verbosity > 0)
	 $display ("AWS_Host_Access.rl_forward_rd_req_addr: req %08h", req);
   endrule

   // ----------------------------------------------------------------
   // Write requests

   // ----------------
   // Write request (WR_ADDR)
   rule rl_forward_wr_req_addr (rg_wdata_pending == tagged Invalid);
      let wra <- pop_o (slave_xactor.o_wr_addr);
      Bit #(32) addr = truncate (wra.awaddr);
      Bit #(32) req  = ((addr & 32'h_FFFF_FFFC) | 32'h1);    // LSB 1 for 'write' req
      f_to_aws_host.enq (req);

      // Enable rl_forward_wr_req_data rule next
      rg_wdata_pending <= tagged Valid addr;

      // Respond 'okay' immediately to CPU; don't wait for host reponse
      let wrd = AXI4_Wr_Resp {bid: wra.awid, bresp: axi4_resp_okay, buser: wra.awuser};
      slave_xactor.i_wr_resp.enq (wrd);

      if (verbosity > 0)
	 $display ("AWS_Host_Access.rl_forward_wr_req_addr: req %08h", req);
   endrule

   // Priortize reads, assuming writes may be used for side-effects after reads
   // Urgency shoudln't matter: CPU won't MMIO reads and writes concurrently anyway
   (* descending_urgency = "rl_forward_rd_req_addr, rl_forward_wr_req_addr, rl_forward_wr_req_data" *)

   // ----------------
   // ---- Write requests (WR_DATA)
   rule rl_forward_wr_req_data (rg_wdata_pending matches tagged Valid .addr);
      let wrd <- pop_o (slave_xactor.o_wr_data);
      Bit #(32) data = wrd.wdata [31:0];

      // Take data from upper 32b of 64b word addr is W but not DW-aligned
      if ((valueOf (Wd_Data) == 64) && (addr [2:0] == 3'b100))
	 data = (wrd.wdata >> 32) [31:0];

      f_to_aws_host.enq (data);

      // Enable rl_forward_rd/wr_req_addr rule next
      rg_wdata_pending <= tagged Invalid;

      if (verbosity > 0)
	 $display ("AWS_Host_Access.rl_forward_wr_req_data: ... data %08h", data);
   endrule

   // ================================================================
   // Forward from AWS host to f_rsp_bufs_from_aws_host

   rule rl_forward_rd_rsp (f_rsps_pending.first matches { 1'b0, .addr, .id, .user });
      Bit #(64) data = zeroExtend (f_from_aws_host.first);
      f_from_aws_host.deq;
      f_rsps_pending.deq;

      if ((valueOf (Wd_Data) == 64) && (addr [2:0] == 3'b100))
	 data = data << 32;

      let rdd = AXI4_Rd_Data {rid: id, rdata: data, rresp: axi4_resp_okay, rlast: True, ruser: user};
      slave_xactor.i_rd_data.enq (rdd);

      if (verbosity > 0)
	 $display ("AWS_Host_Access.rl_forward_rd_rsp: addr %08h => data %08h", addr, data);
   endrule

   /* Use this if we want to wait for write-responses from host
      Don't use this if we 'fire-and-forget' write requests to host
   rule rl_forward_wr_rsp (f_rsps_pending.first matches { 1'b1, .addr, .id, .user });
      Bit #(64) data = zeroExtend (f_from_aws_host.first);
      f_from_aws_host.deq;
      f_rsps_pending.deq;

      let wrd = AXI4_Wr_Resp {bid: id, bresp: axi4_resp_okay, buser: user};
      slave_xactor.i_wr_resp.enq (wrd);

      if (verbosity > 0)
	 $display ("AWS_Host_Access.rl_forward_wr_rsp: addr %08h => data %08h", addr, data);

   endrule
   */

   // ================================================================
   // INTERFACE

   // Main Fabric Reqs/Rsps
   interface  slave = slave_xactor.axi_side;

   // Transport to/from host
   interface Get to_aws_host   = toGet (f_to_aws_host);
   interface Put from_aws_host = toPut (f_from_aws_host);
endmodule

// ================================================================

endpackage
