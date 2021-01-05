// Copyright (c) 2016-2020 Bluespec, Inc. All Rights Reserved.
// Author: Rishiyur S. Nikhil

package Mem_Model;

// ================================================================
// This package is a parameterisable model of a DDR4 controller (at
// the AXI4 interface) for use in simulation.
// WARNING: This is a simplified model: does not support AXI4 bursts.

// ================================================================
// BSV lib imports

import Vector          :: *;
import RegFile         :: *;

// ----------------
// BSV additional libs

import Semi_FIFOF      :: *;
import Cur_Cycle       :: *;

// ================================================================
// Project imports

import AXI4_Types     :: *;
import AXI4_Deburster :: *;

import AWS_BSV_Top_Defs :: *;

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
// Implementation
// - ddr4_num is unique id for each DDR4 (A=0, B=1, ...)
// - init_with_memhex and memhex_file are for optional initialization from a memhex512
// - byte_addr_base and byte_addr_lim are the range of byte-addrs served by this DDR (16GB in AWS)
// - bytes_implemented are the # of bytes implemented (on top of byte_addr_base)
//     which need not cover until addr_last

module mkMem_Model #(Integer    verbosity,
                     Integer    ddr4_num,
		     Bool       init_with_memhex,
		     String     memhex_filename,
		     Bit #(64)  byte_addr_base,
		     Bit #(64)  byte_addr_lim,
                     Bit #(64)  bytes_implemented)
                   (AXI4_16_64_512_0_Slave_IFC);

   // Note: each 'word' in the RegFile is 512b = 64B => uses 6 lsbs of address.
   Bit #(64) words_implemented = (bytes_implemented >> 6);
   Bit #(64) addr_align_mask   = (~ 'h3F);

   RegFile #(Bit #(64), Bit #(512)) rf <- (init_with_memhex
					   ? mkRegFileLoad (memhex_filename, 0, words_implemented - 1)
					   : mkRegFile (0, words_implemented - 1));

   AXI4_16_64_512_0_Slave_Xactor_IFC  axi4_xactor <- mkAXI4_Slave_Xactor;

   Bit #(64) implem_addr_lim = byte_addr_base + (bytes_implemented & addr_align_mask);

   // ================================================================
   // BEHAVIOR

   Reg #(Bool) rg_info_done <- mkReg (False);

   rule rl_info (! rg_info_done);
      rg_info_done <= True;

      $display ("INFO: %0d: %m", cur_cycle);
      $display ("    base %016h  lim %016h    implemented %016h",
		byte_addr_base, byte_addr_lim, bytes_implemented);
      if (init_with_memhex)
	 $display ("    initialized from: %s", memhex_filename);
   endrule

   // ----------------
   // Read requests

   rule rl_rd_req;
      let rda <- pop_o (axi4_xactor.o_rd_addr);

      Bool ok1      = ((byte_addr_base <= rda.araddr) && (rda.araddr < byte_addr_lim));
      Bool ok2      = (rda.araddr < implem_addr_lim);
      let  offset_b = rda.araddr - byte_addr_base;
      let  offset_W = (offset_b >> 6);

      // Default error response
      let rdd = AXI4_Rd_Data {rid:   rda.arid,
			      rdata: zeroExtend (rda.araddr),    // To help debugging
			      rresp: axi4_resp_slverr,
			      rlast: True,
			      ruser: ?};

      if (! ok1) begin
	 $display ("%0d: Mem_Model [%0d]: rl_rd_req: @ %0h -> OUT OF BOUNDS",
		   cur_cycle, ddr4_num, rda.araddr);
	 $display ("    base %016h  lim %016h", byte_addr_base, byte_addr_lim);
      end
      else if (! ok2) begin
	 $display ("%0d: Mem_Model [%0d]: rl_rd_req: @ %0h -> OUT OF IMPLEMENTED BOUNDS",
		   cur_cycle, ddr4_num, rda.araddr);
	 $display ("    base %016h  implementation lim %016h", byte_addr_base, implem_addr_lim);
      end
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

      Bool ok1      = ((byte_addr_base <= wra.awaddr) && (wra.awaddr < byte_addr_lim));
      Bool ok2      = (wra.awaddr < implem_addr_lim);
      let  offset_b = wra.awaddr - byte_addr_base;
      let  offset_W = (offset_b >> 6);

      // Default error response
      let wrr = AXI4_Wr_Resp {bid: wra.awid, bresp: axi4_resp_slverr, buser: ?};

      if (! ok1) begin
	 $display ("%0d: Mem_Model [%0d]: rl_wr_req: @ %0h <= %0h strb %0h: OUT OF BOUNDS",
		   cur_cycle, ddr4_num, wra.awaddr, wrd.wdata, wrd.wstrb);
	 $display ("    base %016h  lim %016h", byte_addr_base, byte_addr_lim);
      end
      else if (! ok2) begin
	 $display ("%0d: Mem_Model [%0d]: rl_wr_req: @ %0h <= %0h strb %0h: OUT OF IMPLEMENTED BOUNDS",
		   cur_cycle, ddr4_num, wra.awaddr, wrd.wdata, wrd.wstrb);
	 $display ("    base %016h  implementation lim %016h", byte_addr_base, implem_addr_lim);
      end
      else begin
	 let old_data = rf.sub (offset_W);
	 let new_data = fv_new_data (old_data, wrd.wdata, wrd.wstrb);
	 rf.upd (offset_W, new_data);
	 if (verbosity > 1) begin
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
