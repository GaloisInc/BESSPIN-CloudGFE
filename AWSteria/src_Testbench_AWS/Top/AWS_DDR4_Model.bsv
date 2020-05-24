// Copyright (c) 2016-2020 Bluespec, Inc. All Rights Reserved.
// Author: Rishiyur S. Nikhil

package AWS_DDR4_Model;

// ================================================================
// This package is a model of the AWS DDR4s (at the AXI4 interface)
// for use in simulation.
// WARNING: This is a simplified model: does not support AXI4 bursts.

// ================================================================

import Vector          :: *;
import RegFile         :: *;
import Connectable     :: *;
import StmtFSM         :: *;

import Semi_FIFOF      :: *;
import Cur_Cycle       :: *;
import AXI4_Types      :: *;
import AXI4_Lite_Types :: *;

import AWS_BSV_Top_Defs :: *;
import AWS_BSV_Top      :: *;

// ================================================================

function Bit #(512) fv_new_data (Bit #(512) old_data, Bit #(512) new_data, Bit #(64) strb);
   function Bit #(8) f (Integer j);
      return ((strb [j] == 1'b1) ? 'hFF : 'h00);
   endfunction
   Vector #(64, Bit #(8)) v_mask = genWith (f);
   Bit #(512)             mask   = pack (v_mask);
   return ((old_data & (~ mask)) | (new_data & mask));
endfunction

// ================================================================

(* synthesize *)
module mkMem_Model #(parameter Bit #(2) ddr4_num) (AXI4_16_64_512_0_Slave_IFC);

   Integer verbosity = 0;

   // Note: each 'word' in the RegFile is 512b = 64B => uses 6 lsbs of address.

   Bit #(64) implemented_words = 'h_0100_0000;    // 16M words, each 64 B => 1 GB size

   RegFile #(Bit #(64), Bit #(512)) rf <- mkRegFile (0, implemented_words - 1);

   AXI4_16_64_512_0_Slave_Xactor_IFC  axi4_xactor <- mkAXI4_Slave_Xactor;

   // base and last are the full 16 GB space logically served by this
   // DDR model, regardless of how much of the space is implemented.
   // Thus, the stride from one DDR to the next is 16GB.

   Bit #(64) addr_base      = { 28'b0, ddr4_num, 34'h_0_0000_0000 };
   Bit #(64) addr_last      = { 28'b0, ddr4_num, 34'h_3_FFFF_FFFF };

   // impl_last is the last actually implemented addr in this model,
   // which could be < addr_last.
   Bit #(64) addr_impl_last = addr_base + ((implemented_words << 6) - 1);

   // ================================================================
   // BEHAVIOR

   // ----------------
   // Read requests

   rule rl_rd_req;
      let rda <- pop_o (axi4_xactor.o_rd_addr);

      Bool ok1      = ((addr_base <= rda.araddr) && (rda.araddr <= addr_last));
      let  offset_b = rda.araddr - addr_base;
      Bool ok2      = (ok1 && (offset_b <= addr_impl_last));
      let  offset_W = (offset_b >> 6);

      // Default error response
      let rdd = AXI4_Rd_Data {rid:   rda.arid,
			      rdata: zeroExtend (rda.araddr),    // To help debugging
			      rresp: axi4_resp_slverr,
			      rlast: True,
			      ruser: ?};

      if (! ok1)
	 $display ("%0d: Mem_Model [%0d]: rl_rd_req: @ %0h -> OUT OF BOUNDS",
		   cur_cycle, ddr4_num, rda.araddr);
      else if (! ok2)
	 $display ("%0d: Mem_Model [%0d]: rl_rd_req: @ %0h -> OUT OF IMPLEMENTED BOUNDS",
		   cur_cycle, ddr4_num, rda.araddr);
      else begin
	 let data = rf.sub (offset_W);
	 rdd = AXI4_Rd_Data {rid:   rda.arid,
			     rdata: data,
			     rresp: axi4_resp_okay,
			     rlast: True,
			     ruser: ?};
	 if (verbosity > 0)
	    $display ("%0d: Mem_Model [%0d]: rl_rd_req: @ %0h -> %0h",
		      cur_cycle, ddr4_num, rda.araddr, data);
      end

      axi4_xactor.i_rd_data.enq (rdd);
   endrule

   // ----------------
   // Write requests

   rule rl_wr_req;
      let wra <- pop_o (axi4_xactor.o_wr_addr);
      let wrd <- pop_o (axi4_xactor.o_wr_data);

      Bool ok1      = ((addr_base <= wra.awaddr) && (wra.awaddr <= addr_last));
      let  offset_b = wra.awaddr - addr_base;
      Bool ok2      = (ok1 && (offset_b <= addr_impl_last));
      let  offset_W = (offset_b >> 6);

      // Default error response
      let wrr = AXI4_Wr_Resp {bid:   wra.awid, bresp: axi4_resp_slverr, buser: ?};

      if (! ok1)
	 $display ("%0d: Mem_Model [%0d]: rl_wr_req: @ %0h <= %0h strb %0h: OUT OF BOUNDS",
		   cur_cycle, ddr4_num, wra.awaddr, wrd.wdata, wrd.wstrb);
      else if (! ok2)
	 $display ("%0d: Mem_Model [%0d]: rl_wr_req: @ %0h <= %0h strb %0h: OUT OF IMPLEMENTED BOUNDS",
		   cur_cycle, ddr4_num, wra.awaddr, wrd.wdata, wrd.wstrb);
      else begin
	 let old_data = rf.sub (offset_W);
	 let new_data = fv_new_data (old_data, wrd.wdata, wrd.wstrb);
	 rf.upd (offset_W, new_data);
	 if (verbosity > 0) begin
	    $display ("    Old: %h", old_data);
	    $display ("    New: %h", new_data);
	 end
	 wrr = AXI4_Wr_Resp {bid: wra.awid, bresp: axi4_resp_okay, buser: ?};

	 if (verbosity > 0)
	    $display ("%0d: Mem_Model [%0d]: rl_wr_req: @ %0h <= %0h strb %0h",
		      cur_cycle, ddr4_num, wra.awaddr, wrd.wdata, wrd.wstrb);
      end

      axi4_xactor.i_wr_resp.enq (wrr);
   endrule

   // ================================================================
   // INTERFACE

   return axi4_xactor.axi_side;
endmodule

// ================================================================

endpackage
