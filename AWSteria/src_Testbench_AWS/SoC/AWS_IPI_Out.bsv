// Copyright (c) 2016-2020 Bluespec, Inc. All Rights Reserved.
// Author: Rishiyur S. Nikhil

package AWS_IPI_Out;

// mkAWS_IPI_Out creates a simple AXI4 slave fielding one location.  A
// write to this location is interpreted as a request to deliver an
// inter-processor interrupt to some other actor.

// ================================================================
// BSV library imports

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

interface AWS_IPI_Out_IFC;
   // set_addr_map should be called after this module's reset
   method Action  set_addr_map (Fabric_Addr addr_base, Fabric_Addr addr_lim);

   // Main Fabric Reqs/Rsps
   interface AXI4_Slave_IFC #(Wd_Id, Wd_Addr, Wd_Data, Wd_User) slave;

   // IPIs to other actor
   interface Get #(Bit #(1)) ipi_out_get;
endinterface

// ================================================================

(* synthesize *)
module mkAWS_IPI_Out (AWS_IPI_Out_IFC);

   // 0: quiet; 1 rules
   Integer verbosity = 0;

   // These regs represent where this IP is placed in the address space.
   Reg #(Fabric_Addr)  rg_addr_base <- mkRegU;
   Reg #(Fabric_Addr)  rg_addr_lim  <- mkRegU;

   FIFOF #(Bit #(1)) f_ipi <- mkFIFOF;

   // ----------------
   // Connector to AXI4 fabric

   AXI4_Slave_Xactor_IFC #(Wd_Id, Wd_Addr, Wd_Data, Wd_User) slave_xactor <- mkAXI4_Slave_Xactor;

   // ================================================================
   // BEHAVIOR

   // ----------------------------------------------------------------
   // Handle fabric read requests: always return SLVERR

   rule rl_process_rd_req;
      let rda <- pop_o (slave_xactor.o_rd_addr);

      AXI4_Resp rresp = axi4_resp_slverr;
      if ((rda.araddr < rg_addr_base) || (rda.araddr >= rg_addr_lim)) begin
	 $display ("%0d: AWS_IPI_Out.rl_process_rd_req: ERROR: addr out of bounds", cur_cycle);
	 $display ("    base addr 0x%0h  limit addr 0x%0h", rg_addr_base, rg_addr_lim);
	 $display ("    AXI4 request: ", fshow (rda));
	 rresp = axi4_resp_decerr;
      end
      else begin
	 $display ("%0d: AWS_IPI_Out.rl_process_rd_req: ERROR: unsupported addr", cur_cycle);
	 $display ("            ", fshow (rda));
	 rresp = axi4_resp_decerr;
      end

      // Send read-response to bus
      Fabric_Data rdata = 0;
      let rdr = AXI4_Rd_Data {rid:   rda.arid,
			      rdata: rdata,
			      rresp: rresp,
			      rlast: True,
			      ruser: rda.aruser};
      slave_xactor.i_rd_data.enq (rdr);

      if (verbosity > 1) begin
	 $display ("%0d: AWS_IPI_Out.rl_process_rd_req", cur_cycle);
	 $display ("            ", fshow (rda));
	 $display ("            ", fshow (rdr));
      end
   endrule

   // ----------------------------------------------------------------
   // Handle fabric write requests

   rule rl_process_wr_req;
      let wra <- pop_o (slave_xactor.o_wr_addr);
      let wrd <- pop_o (slave_xactor.o_wr_data);

      Bit #(64) wdata = zeroExtend (wrd.wdata);
      AXI4_Resp bresp = axi4_resp_okay;

      if ((wra.awaddr < rg_addr_base) || (wra.awaddr >= rg_addr_lim)) begin
	 $display ("%0d: %m.rl_process_rd_req: ERROR: UART addr out of bounds", cur_cycle);
	 $display ("    UART base addr 0x%0h  limit addr 0x%0h", rg_addr_base, rg_addr_lim);
	 $display ("    AXI4 request: ", fshow (wra));
	 bresp = axi4_resp_decerr;
      end
      else begin
	 f_ipi.enq (wdata [0]);
	 if (verbosity != 0)
	    $display ("%0d: AWS_IPI_Out.rl_process_wr_req: enqueueing outgoing IPI: %0h",
		      cur_cycle, wdata);
      end

      // Send write-response to bus
      let wrr = AXI4_Wr_Resp {bid:   wra.awid,
			      bresp: bresp,
			      buser: wra.awuser};
      slave_xactor.i_wr_resp.enq (wrr);

      if (verbosity > 1) begin
	 $display ("%0d: AWS_IPI_Out.rl_process_wr_req", cur_cycle);
	 $display ("            ", fshow (wra));
	 $display ("            ", fshow (wrd));
	 $display ("            ", fshow (wrr));
      end
   endrule

   // ================================================================
   // INTERFACE

   // set_addr_map should be called after this module's reset
   method Action  set_addr_map (Fabric_Addr addr_base, Fabric_Addr addr_lim);
      if (addr_base [2:0] != 0)
	 $display ("%0d: WARNING: UART.set_addr_map: addr_base 0x%0h is not 8-Byte-aligned",
		   cur_cycle, addr_base);

      if (addr_lim [2:0] != 0)
	 $display ("%0d: WARNING: UART.set_addr_map: addr_lim 0x%0h is not 8-Byte-aligned",
		   cur_cycle, addr_lim);

      rg_addr_base <= addr_base;
      rg_addr_lim  <= addr_lim;
   endmethod

   // Main Fabric Reqs/Rsps
   interface  slave = slave_xactor.axi_side;

   // IPIs to other actor
   interface Get ipi_out_get = toGet (f_ipi);
endmodule

// ================================================================

endpackage
