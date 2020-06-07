// Copyright (c) 2016-2020 Bluespec, Inc. All Rights Reserved
// Author: Rishiyur S. Nikhil

package AWS_DDR4_Adapter;

// ================================================================
// This module is an adapter between a hardware application and the
// AWS DDR4 interfaces.

// Front side: AXI4 slave facing hardware application client (usually
// is a system interconnect fabric):
//    - AXI4_16_32_32_0    (if FABRIC32 is defined)
//    - AXI4_16_64_64_0    (if FABRIC64 is defined)
//    - Single transactions only (awlen = 0, i.e., bursts of length 1)
//        (a separate 'deburster' is available that can be placed in
//         front of this to enable handling bursts)

// Back side (AXI4 master facing AWS DDR4):
//    - AXI4_16_64_512_0    (id, addr, data, user bus widths)
//    - Generates single transactions only, no bursts.
//    - In HW, this connects to a DRAM  (e.g., Amazon aws-fpga's DDR4s)
//      During simulation, this connects instead to a memory model.

// Some of the 'truncate()'s and 'zeroExtend()'s below are no-ops but
// necessary to satisfy type-checking, to accommodate 32b and 64b clients.

// ================================================================
// Implementation notes:

// ----------------
// Although AXI4 read and write channels are independent, this
// implementation merges read and write requests from the client, and
// responds to them in order.

// ----------------
// This module only supports aligned reads/writes from the client, i.e.,
// - 2-byte accesses must have zero in address [0]
// - 4-byte accesses must have zero in address [1:0]
// - 8-byte accesses must have zero in address [2:0]

// ----------------
// Rather than convert front-side AXI4 transactions directly to
// back-side AXI4 transactions, we maintain here a 'cache' of one
// Data_512, the natural width of the DDR4s.

// Front-side transactions only read/write fields of this cached data_512.

// Back-side transactions read/write this entire data_512 (so, always
// 512b aligned, and all bytes enabled).

// A 'dirty' cache data_512 is written back to the DDR4 whenever there
// is a 'miss', or whenever there is an idle cycle (no request from
// front-side), and is marked clean.

// WARNING: this could raise a coherence issue if there is also
// another path to the same AWS DDR4.  But if all accesses to the DDR4
// go through this adapter, there is no problem.

// ================================================================

export Wd_Addr_Fabric,  Fabric_Addr;
export Wd_Data_Fabric,  Fabric_Data;

export Addr_64, Data_512;

export aws_DDR4_adapter_status_ok,
       aws_DDR4_adapter_status_error,
       aws_DDR4_adapter_status_terminated;

export AWS_DDR4_Adapter_IFC (..), mkAWS_DDR4_Adapter;

// ================================================================
// BSV library imports

import  Vector       :: *;
import  FIFOF        :: *;
import  SpecialFIFOs :: *;
import  GetPut       :: *;

// ----------------
// BSV additional libs

import Cur_Cycle  :: *;
import GetPut_Aux :: *;
import Semi_FIFOF :: *;
import ByteLane   :: *;

// ================================================================
// Project imports

import AXI4 :: *;
import SourceSink :: *;
import AWS_BSV_Top_Defs :: *;    // For AXI4 bus widths (id, addr, data, user)

// ================================================================
// The following sizes are chosen to match Amazon AWS DDR interfaces
// DDR address width: 64
// DDR data width:    512 (bits/ 64 x Byte/ 16 x Data_32/ 8 x Data_64)

typedef Bit #(Wd_Data_512)  Data_512;
typedef Bit #(Wd_Addr_64)   Addr_64;

// ================================================================
// Front-side connections are for AXI4 32_32 or 64_64

`ifdef FABRIC32
typedef 32  Wd_Addr_Fabric;
typedef 32  Wd_Data_Fabric;
`endif

`ifdef FABRIC64
typedef 64  Wd_Addr_Fabric;
typedef 64  Wd_Data_Fabric;
`endif

typedef Bit #(Wd_Addr_Fabric) Fabric_Addr;
typedef Bit #(Wd_Data_Fabric) Fabric_Data;

typedef TDiv #(Wd_Data_Fabric,  8)  Data_8s_per_Fabric_Data;

// ================================================================
// The 'status' method returns a (bit-ified) version of this.

Integer aws_DDR4_adapter_status_ok         = 0;
Integer aws_DDR4_adapter_status_terminated = 1;
Integer aws_DDR4_adapter_status_error      = 2;

// ================================================================
// Interface

interface AWS_DDR4_Adapter_IFC;
   // AXI4 interface facing client app/fabric
   interface AXI4_Slave_Synth#( Wd_Id_15, Wd_Addr_Fabric, Wd_Data_Fabric
                              , Wd_AW_User_0, Wd_W_User_0, Wd_B_User_0
                              , Wd_AR_User_0, Wd_R_User_0) slave;

   // AXI4 interface facing DDR
   interface AXI4_15_64_512_0_0_0_0_0_Master_Synth to_ddr4;

   // ----------------
   // Control methods; should be called at beginning (STATE_WAITING)
   // 'ma_ddr4_is_loaded' should be called last.

   // Range of legal addrs for this module
   method Action ma_set_addr_map (Fabric_Addr addr_base, Fabric_Addr addr_lim);

   // For RISC-V ISA tests only: watch memory writes to <tohost> addr
   method Action ma_set_watch_tohost (Bool watch_tohost, Fabric_Addr tohost_addr);

   // This method asserts that 'back-door' loading of DDR (if any) has
   // finished, and it is now safe to use the 'to_ddr4' interface.
   // Until this point, DDR4 Adapter stalls response of first request
   // on 'slave' interface.
   method Action ma_ddr4_ready;

   // ----------------
   // Status methods; can be called at any time.
   // Normal response is 'aws_DDR4_adapter_status_ok'
   // If tohost is watched, and has been written, transitions to 'aws_DDR4_adapter_status_terminated'
   // If any memory error, transitions to 'aws_DDR4_adapter_status_error'

   // Status of module
   (* always_ready *)
   method Bit #(8) mv_status;
endinterface

// ================================================================
// Views of Data_512 DDR4 words as bytes, Data_32s and Data_64s

typedef TDiv #(512,  8)  Data_8s_per_Data_512;            // 64 bytes
typedef TDiv #(512, 32)  Data_32s_per_Data_512;           // 16 x 32b words
typedef TDiv #(512, 64)  Data_64s_per_Data_512;           //  8 x 64b words

// # of addr lsbs to index a byte in a Data_512
typedef TLog #(Data_8s_per_Data_512)   Bits_per_Data_8_in_Data_512;     //  6
// # of addr lsbs to index a Data_32 in a Data_512 viewed as a vector of Data_32s
typedef TLog #(Data_32s_per_Data_512)  Bits_per_Data_32_in_Data_512;    //  4
// # of addr lsbs to index a Data_64 in a Data_512 viewed as a vector of Data_64s
typedef TLog #(Data_64s_per_Data_512)  Bits_per_Data_64_in_Data_512;    //  3

// Type of index of a Data_8 in a Data_512 seen as a vector of Data_8s
typedef Bit #(Bits_per_Data_8_in_Data_512)   Data_8_in_Data_512;
// Type of index of a Data_32 in a Data_512 seen as a vector of Data_32s
typedef Bit #(Bits_per_Data_32_in_Data_512)  Data_32_in_Data_512;
// Type of index of a Data_64 in a Data_512 seen as a vector of Data_64s
typedef Bit #(Bits_per_Data_64_in_Data_512)  Data_64_in_Data_512;

// # of Data_32/Data_64s in a Data_512
typedef TDiv #(Data_8s_per_Data_512, Data_8s_per_Fabric_Data)  Fabric_Data_per_Data_512;

// Integer versions of the above numeric types
Integer bytes_per_Data_512        = valueOf (Data_8s_per_Data_512);
Integer bits_per_byte_in_Data_512 = valueOf (Bits_per_Data_8_in_Data_512);
Integer hi_byte_in_Data_512       = bits_per_byte_in_Data_512 - 1;

Integer data_32s_per_data_512 = valueOf (Data_32s_per_Data_512);
Integer data_64s_per_data_512 = valueOf (Data_64s_per_Data_512);

// Index of bit that selects a Data_64 in an address
`ifdef FABRIC32
Integer  lo_fabric_data = 2;
`endif

`ifdef FABRIC64
Integer  lo_fabric_data = 3;
`endif

// ================================================================
// Address checks

// Check if two addrs are in the same Data_512
function Bool fv_addrs_in_same_Data_512 (Addr_64 addr1, Addr_64 addr2);
   let a1 = (addr1 >> log2 (bytes_per_Data_512));
   let a2 = (addr2 >> log2 (bytes_per_Data_512));
   return (a1 == a2);
endfunction

function Bool fv_addr_is_aligned (Addr_64  addr, AXI4_Size  size);
   Bool is_aligned = (   (size == 1)
		      || ((size == 2)    && (addr [0]   == 1'h0))
		      || ((size == 4)    && (addr [1:0] == 2'h0))
		      || ((size == 8)    && (addr [2:0] == 3'h0))
		      || ((size == 16)   && (addr [3:0] == 4'h0))
		      || ((size == 32)   && (addr [4:0] == 5'h0))
		      || ((size == 64)   && (addr [5:0] == 6'h0))
		      || ((size == 128)  && (addr [6:0] == 7'h0)));
   return is_aligned;
endfunction

function Bool fv_addr_is_ok (Addr_64 addr_base, Addr_64 addr_lim,
			     Addr_64 addr, AXI4_Size  axi4_size);
   Bool ok1 = (axi4_size <= 8);                              // Up to 8-byte requests only
   Bool ok2 = fv_addr_is_aligned (addr, axi4_size);          // Aligned?
   Bool ok3 = ((addr_base <= addr) && (addr < addr_lim));    // Addr in range?
   return (ok1 && ok2 && ok3);
endfunction

// ================================================================
// Local constants and types

// Module state
typedef enum {STATE_START,                 // reset state etc.
	      STATE_WAITING,               // Wait until SoC sets addr map and watch tohost
	      STATE_REFILLING,             // while refilling the Data_512 cache
	      STATE_READY                  // while handling client requests
   } State
deriving (Bits, Eq, FShow);

// ================================================================
// AXI4 has independent read and write channels.
// In this implementation we merge them into a single queue using this
// merged struct.

typedef enum { REQ_OP_RD, REQ_OP_WR } Req_Op
deriving (Bits, Eq, FShow);

typedef struct {Req_Op                     req_op;

		// AW and AR channel info
		Bit #(Wd_Id_15)            id;
		Addr_64                    addr;
		AXI4_Len                   len;
		AXI4_Size                  size;
		AXI4_Burst                 burst;
		AXI4_Lock                  lock;
		AXI4_Cache                 cache;
		AXI4_Prot                  prot;
		AXI4_QoS                   qos;
		AXI4_Region                region;
		Bit #(Wd_AR_User_0)        user;

		// Write data info
		Bit #(TDiv #(Wd_Data_Fabric, 8))  wstrb;
		Fabric_Data                       data;
   } Req
deriving (Bits, FShow);

// ================================================================

(* synthesize *)
module mkAWS_DDR4_Adapter (AWS_DDR4_Adapter_IFC);

   // verbosity 0: quiet
   // verbosity 1: initialzing, initialized
   // verbosity 2: reads, writes
   // verbosity 3: more detail of local DDR interactions (cache read, writeback)
   Integer verbosity = 0;

   Reg #(State)   rg_state     <- mkReg (STATE_START);
   Reg #(Addr_64) rg_addr_base <- mkRegU;
   Reg #(Addr_64) rg_addr_lim  <- mkRegU;

   // Front-side interface to clients
   AXI4_Slave_Xactor#( Wd_Id_15, Wd_Addr_Fabric, Wd_Data_Fabric
                     , Wd_AW_User_0, Wd_W_User_0, Wd_B_User_0
                     , Wd_AR_User_0, Wd_R_User_0)
      slave_xactor <- mkAXI4_Slave_Xactor;

   // Requests merged from client (WrA, WrD) and RdA channels
   FIFOF #(Req) f_reqs <- mkPipelineFIFOF;

   // Back-side interface to memory
   AXI4_Master_Xactor#( Wd_Id_15, Wd_Addr_64, Wd_Data_512
                      , Wd_AW_User_0, Wd_W_User_0, Wd_B_User_0
                      , Wd_AR_User_0, Wd_R_User_0)
      master_xactor <- mkAXI4_Master_Xactor;

   // We maintain a cache of 1 Data_512
   Reg #(Bool)      rg_cached_clean  <- mkRegU;
   Reg #(Addr_64)   rg_cached_addr   <- mkRegU;
   Reg #(Data_512)  rg_cached_data_512   <- mkRegU;

   // Ad hoc RISC-V ISA-test simulation support: watch <tohost> and stop on non-zero write.
   // The default tohost_addr here is fragile (may change on recompilation of tests).
   // Proper value can be provided with 'set_watch_tohost' method from symbol table
   Reg #(Bool)       rg_watch_tohost <- mkReg (False);
   Reg #(Addr_64)    rg_tohost_addr  <- mkReg ('h_8000_1000);

   // Module status
   // Error status is 'sticky', triggered by error response from back-side mem.
   Reg #(Bit #(8)) rg_status <- mkReg (fromInteger (aws_DDR4_adapter_status_ok));

   // ================================================================
   // Function to encapsulate and simplify AXI4 request/response on back-side AXI4 (to mem)
   // Arg 'addr' is an address within this DDR4, not a global address.

   function Action fa_mem_req (Bool write, Bit #(64) addr, Bit #(512) write_data);
      action
	 if (write) begin
	    let wra = AXI4_AWFlit {awid:     0,
				   awaddr:   addr,
				   awlen:    0,                    // 1-beat burst
				   awsize:   64,                   // full 64 bytes
				   awburst:  INCR,
				   awlock:   NORMAL,
				   awcache:  awcache_dev_nonbuf,
				   awprot:   axi4Prot(DATA, SECURE, PRIV),
				   awqos:    0,
				   awregion: 0,
				   awuser:   0};
	    let wrd = AXI4_WFlit {wdata: write_data,
				  wstrb: '1,
				  wlast: True,
				  wuser: 0};
	    master_xactor.slave.aw.put(wra);
	    master_xactor.slave.w.put(wrd);
	 end
	 else begin
	    let rda = AXI4_ARFlit {arid:     0,
				   araddr:   addr,
				   arlen:    0,                    // 1-beat burst
				   arsize:   64,            // full 64 bytes
				   arburst:  INCR,
				   arlock:   NORMAL,
				   arcache:  arcache_dev_nonbuf,
				   arprot:   axi4Prot(DATA, SECURE, PRIV),
				   arqos:    0,
				   arregion: 0,
				   aruser:   0};
	    master_xactor.slave.ar.put(rda);
	 end
      endaction
   endfunction

   // ================================================================
   // Start the module

   rule rl_start (rg_state == STATE_START);
      slave_xactor.clear;
      master_xactor.clear;
      rg_status <= fromInteger (aws_DDR4_adapter_status_ok);
      rg_state  <= STATE_WAITING;

      if (verbosity > 1)
	 $display ("%0d: AWS_DDR4_Adapter.rl_start", cur_cycle);
   endrule

   // ================================================================
   // Merge requests into a single queue, prioritizing reads over writes

   rule rl_merge_rd_req (rg_state == STATE_READY);
      let rda <- get(slave_xactor.master.ar);
      let req = Req {req_op:     REQ_OP_RD,
		     id:         rda.arid,
		     addr:       rda.araddr,
		     len:        rda.arlen,
		     size:       rda.arsize,
		     burst:      rda.arburst,
		     lock:       rda.arlock,
		     cache:      rda.arcache,
		     prot:       rda.arprot,
		     qos:        rda.arqos,
		     region:     rda.arregion,
		     user:       rda.aruser,
		     wstrb:      ?,
		     data:       ?};
      f_reqs.enq (req);

      if (verbosity > 1) begin
	 $display ("%0d: AWS_DDR4_Adapter.rl_merge_rd_req", cur_cycle);
	 $display ("        ", fshow (rda));
      end
   endrule

   (* descending_urgency = "rl_merge_rd_req, rl_merge_wr_req" *)
   rule rl_merge_wr_req (rg_state == STATE_READY);
      let wra <- get(slave_xactor.master.aw);
      let wrd <- get(slave_xactor.master.w);
      let req = Req {req_op:     REQ_OP_WR,
		     id:         wra.awid,
		     addr:       wra.awaddr,
		     len:        wra.awlen,
		     size:       wra.awsize,
		     burst:      wra.awburst,
		     lock:       wra.awlock,
		     cache:      wra.awcache,
		     prot:       wra.awprot,
		     qos:        wra.awqos,
		     region:     wra.awregion,
		     user:       wra.awuser,
		     wstrb:      wrd.wstrb,
		     data:       wrd.wdata};
      f_reqs.enq (req);

      if (verbosity > 1) begin
	 $display ("%0d: AWS_DDR4_Adapter.rl_merge_wr_req", cur_cycle);
	 $display ("        ", fshow (wra));
	 $display ("        ", fshow (wrd));
      end
   endrule

   // ================================================================
   // Writebacks and refills of the cached Data_512.
   // Writebacks happen on misses, and opportunistically on idle cycles.

   // ----------------
   // When there's no client req and the cached Data_512 is dirty;
   // write back the dirty Data_512 and mark it clean.

   rule rl_writeback_dirty_idle (   (rg_state == STATE_READY)
				 && (! f_reqs.notEmpty)           // Idle
				 && (! rg_cached_clean));
      fa_mem_req (True, rg_cached_addr, rg_cached_data_512);
      rg_cached_clean <= True;
      if (verbosity > 2) begin
	 $display ("%0d: AWS_DDR4_Adapter.rl_writeback_dirty_idle addr 0x%0h",
		   cur_cycle, rg_cached_addr);
	 $display ("    cache data %0h: ", rg_cached_data_512);
      end
   endrule

   // ----------------
   // When there's a client req for an addr outside the cached
   // Data_512 and the cached Data_512 is dirty, write back the dirty
   // Data_512 and mark it clean (which will enable rl_miss_clean_req
   // next, which does a refill).

   rule rl_writeback_dirty_miss (   (rg_state == STATE_READY)
				 && fv_addr_is_ok (rg_addr_base, rg_addr_lim,
						   f_reqs.first.addr, f_reqs.first.size)
				 && (! fv_addrs_in_same_Data_512 (f_reqs.first.addr, rg_cached_addr))
				 && (! rg_cached_clean));
      fa_mem_req (True, rg_cached_addr, rg_cached_data_512);
      rg_cached_clean <= True;
      if (verbosity > 2)
	 $display ("%0d: AWS_DDR4_Adapter.rl_writeback_dirty_miss addr 0x%0h",
		   cur_cycle, rg_cached_addr);
   endrule

   // ----------------
   // When there's a client req for an addr outside the cached
   // Data_512 and the cached Data_512 is clean, refill the cached
   // Data_512 by reading the correct Data_512 from memory; the new
   // cached Data_512 is clean.

   rule rl_miss_clean_req (   (rg_state == STATE_READY)
			   && fv_addr_is_ok (rg_addr_base, rg_addr_lim,
					     f_reqs.first.addr, f_reqs.first.size)
			   && (! fv_addrs_in_same_Data_512 (f_reqs.first.addr, rg_cached_addr))
			   && rg_cached_clean);
      fa_mem_req (False, f_reqs.first.addr, ?);
      rg_cached_addr <= f_reqs.first.addr;
      rg_state       <= STATE_REFILLING;
      if (verbosity > 2)
	 $display ("%0d: AWS_DDR4_Adapter.rl_miss_clean_req: read addr %0h",
		   cur_cycle, f_reqs.first.addr);
   endrule

   rule rl_refill (rg_state == STATE_REFILLING);
      let rdd <- get(master_xactor.slave.r);
      if (rdd.rresp != OKAY)
	 rg_status <= fromInteger (aws_DDR4_adapter_status_error);
      else begin
	 rg_cached_data_512  <= rdd.rdata;
	 rg_cached_clean     <= True;
      end
      rg_state <= STATE_READY;

      if (verbosity > 2) begin
	 $display ("%0d: AWS_DDR4_Adapter.rl_refill: addr 0x%0h",
		   cur_cycle, rg_cached_addr);
	 $display ("    %0h", rdd.rdata);
      end
   endrule

   // ================================================================
   // Process reads and writes, once the cache has the correct Data_512 ('hit')

   // ----------------
   // When there's a client READ request for an addr in the cached
   // Data_512 ('hit'), whether clean or dirty, return the full
   // Fabric_Data containing the byte specified by the address.  i.e.,
   // we do not extract relevant bytes here, leaving that to the
   // requestor.

   rule rl_process_rd_req  (   (rg_state == STATE_READY)
			    && fv_addr_is_ok (rg_addr_base, rg_addr_lim,
					      f_reqs.first.addr, f_reqs.first.size)
			    && fv_addrs_in_same_Data_512 (f_reqs.first.addr, rg_cached_addr)
			    && (f_reqs.first.req_op == REQ_OP_RD));

      // View the cached Data_512 as a vector of Fabric_Data
      Vector #(Fabric_Data_per_Data_512, Fabric_Data) v_fabric_data = unpack (rg_cached_data_512);

      // Byte offset of addr in Data_512
      Data_8_in_Data_512 n = truncate (f_reqs.first.addr);
      // Fabric_Data offset of addr in Data_512
      n = (n >> lo_fabric_data);

      // Select the Fabric_Data of interest
      Fabric_Data rdata = v_fabric_data [n];

      let rdr = AXI4_RFlit {rid:   f_reqs.first.id,
			    rdata: rdata,
			    rresp: ((rg_status == fromInteger (aws_DDR4_adapter_status_ok))
			            ? OKAY
			            : SLVERR),
			    rlast: True,
			    ruser: f_reqs.first.user};
      slave_xactor.master.r.put(rdr);
      f_reqs.deq;

      if (verbosity > 1) begin
	 $display ("%0d: AWS_DDR4_Adapter.rl_process_rd_req: ", cur_cycle);
	 $display ("    ", fshow (f_reqs.first));
	 $display (" => ", fshow (rdr));
      end
   endrule

   // ----------------
   // When there's a client WRITE request for an addr in the cached
   // Data_512 ('hit'), whether clean or dirty, do the appropriate
   // read-modify-write of the cached Data_512 and mark it dirty.

   rule rl_process_wr_req  (   (rg_state == STATE_READY)
			    && fv_addr_is_ok (rg_addr_base, rg_addr_lim,
					      f_reqs.first.addr, f_reqs.first.size)
			    && fv_addrs_in_same_Data_512 (f_reqs.first.addr, rg_cached_addr)
			    && (f_reqs.first.req_op == REQ_OP_WR));

      // Index of relevant Data_64 from the cached Data_512
      Data_64_in_Data_512 data_64_in_Data_512 = f_reqs.first.addr [hi_byte_in_Data_512 : 3];
      // View the cached Data_512 as a vector of 64-bit words
      Vector #(Data_64s_per_Data_512, Bit #(64)) v_data_64 = unpack (rg_cached_data_512);
      // Extract the relevant Data_64
      Bit #(64) data_64_old = v_data_64 [data_64_in_Data_512];

      Bit #(64) data_64_new = zeroExtend (f_reqs.first.data);
      Bit #(8)  strobe      = zeroExtend (f_reqs.first.wstrb);

      // In case of FABRIC32, lane-adjust data and strobe for 64b view
      if ((valueOf (Wd_Data_Fabric) == 32) && (f_reqs.first.addr [2] == 1'b1)) begin
	 // Upper 32b only
	 data_64_new = { data_64_new [31:0], 32'b0 };
	 strobe      = { strobe      [3:0],  4'b0 };
      end
      Bit #(64) mask      = fn_strobe_to_mask (strobe);
      let updated_data_64 = ((data_64_old & (~ mask)) | (data_64_new & mask));
      v_data_64 [data_64_in_Data_512] = updated_data_64;

      // Write it back into the cached Data_512 (if we're not in the error state)
      if (rg_status == fromInteger (aws_DDR4_adapter_status_ok)) begin
	 rg_cached_data_512  <= pack (v_data_64);
	 rg_cached_clean <= False;
      end

      // Respond to client
      let wrr = AXI4_BFlit {bid:   f_reqs.first.id,
			    bresp: OKAY,
			    buser: f_reqs.first.user};
      slave_xactor.master.b.put(wrr);

      // Done with this request
      f_reqs.deq;

      if (verbosity > 1) begin
	 $display ("%0d: AWS_DDR4_Adapter.rl_process_wr_req: ", cur_cycle);
	 $display ("    ", fshow (f_reqs.first));
	 $display (" => ", fshow (wrr));
      end

      // For simulation testing of riscv-tests/isa only:
      if ((rg_watch_tohost)
	  && (zeroExtend (f_reqs.first.addr) == rg_tohost_addr)
	  && (f_reqs.first.data != 0)
	  && (rg_status != fromInteger (aws_DDR4_adapter_status_terminated)))
	 begin
	    $display ("%0d: AWS_DDR4_Adapter.rl_process_wr_req: addr 0x%0h (<tohost>) data 0x%0h",
		      cur_cycle, f_reqs.first.addr, f_reqs.first.data);
	    let exit_value = (f_reqs.first.data >> 1);
	    if (exit_value == 0)
	       $display ("PASS ISA Test");
	    else
	       $display ("FAIL ISA Test, sub-test number %0d", exit_value);
	    rg_status <= fromInteger (aws_DDR4_adapter_status_terminated);
	 end
   endrule

   // ================================================================
   // Drain write-responses from mem, recording error if any.

   rule rl_drain_mem_wr_resps;
      let wrr <- get(master_xactor.slave.b);
      if (wrr.bresp != OKAY) begin
	 rg_status <= fromInteger (aws_DDR4_adapter_status_error);
	 $finish (1);
      end
   endrule

   // ================================================================
   // Invalid address

   rule rl_invalid_rd_address (   (rg_state == STATE_READY)
			       && (! fv_addr_is_ok (rg_addr_base, rg_addr_lim,
						    f_reqs.first.addr, f_reqs.first.size))
			       && (f_reqs.first.req_op == REQ_OP_RD));
      Fabric_Data rdata = zeroExtend (f_reqs.first.addr);
      let rdr = AXI4_RFlit {rid:   f_reqs.first.id,
			    rdata: rdata,                 // for debugging only
			    rresp: SLVERR,
			    rlast: True,
			    ruser: f_reqs.first.user};
      slave_xactor.master.r.put(rdr);
      f_reqs.deq;

      $write ("%0d: ERROR: AWS_DDR4_Adapter:", cur_cycle);
      if (! fv_addr_is_aligned (f_reqs.first.addr, f_reqs.first.size))
	 $display (" read-addr is misaligned");
      else
	 $display (" read-addr is out of bounds");
      $display ("        rg_addr_base 0x%0h  rg_addr_lim 0x%0h", rg_addr_base, rg_addr_lim);
      $display ("        ", fshow (f_reqs.first));
      $display ("     => ", fshow (rdr));
   endrule

   rule rl_invalid_wr_address (   (rg_state == STATE_READY)
			       && (! fv_addr_is_ok (rg_addr_base, rg_addr_lim,
						    f_reqs.first.addr, f_reqs.first.size))
			       && (f_reqs.first.req_op == REQ_OP_WR));
      let wrr = AXI4_BFlit {bid:   f_reqs.first.id,
			    bresp: SLVERR,
			    buser: f_reqs.first.user};
      slave_xactor.master.b.put(wrr);
      f_reqs.deq;

      $write ("%0d: ERROR: AWS_DDR4_Adapter:", cur_cycle);
      if (! fv_addr_is_aligned (f_reqs.first.addr, f_reqs.first.size))
	 $display (" write-addr is misaligned");
      else
	 $display (" write-addr is out of bounds");
      $display ("        rg_addr_base 0x%0h  rg_addr_lim 0x%0h", rg_addr_base, rg_addr_lim);
      $display ("        ", fshow (f_reqs.first));
      $display ("     => ", fshow (wrr));
   endrule

   // ================================================================
   // INTERFACE

   // AXI4 interface facing client
   interface  slave = slave_xactor.slaveSynth;

   // AXI4 interface facing DDR
   interface  to_ddr4 = master_xactor.masterSynth;

   // ----------------
   // Control methods; should be called at beginning (STATE_WAITING)
   // 'ma_ddr4_is_loaded' should be called last.

   // Range of legal addrs for this module
   method Action ma_set_addr_map (Fabric_Addr addr_base,
				  Fabric_Addr addr_lim) if (rg_state == STATE_WAITING);
      rg_addr_base    <= addr_base;
      rg_addr_lim     <= addr_lim;
      $display ("%0d: AWS_DDR4_Adapter.ma_set_addr_map: addr_base %0h lim %0h",
		cur_cycle, addr_base, addr_lim);
   endmethod

   // For RISC-V ISA tests only: watch memory writes to <tohost> addr
   method Action ma_set_watch_tohost (Bool watch_tohost,
				      Fabric_Addr tohost_addr) if (rg_state == STATE_WAITING);
      // Start refilling local cache of single 512b word
      rg_watch_tohost <= watch_tohost;
      rg_tohost_addr  <= tohost_addr;
      if (watch_tohost)
	 $display ("AWS_DDR4_Adapter.ma_set_watch_tohost: tohost_addr %0h", tohost_addr);
   endmethod

   // This method asserts that 'back-door' loading of DDR (if any) has
   // finished, and it is now safe to use the 'to_ddr4' interface.
   // Until this point, DDR4 Adapter stalls response of first request
   // on 'slave' interface.
   method Action ma_ddr4_ready () if (rg_state == STATE_WAITING);
      rg_cached_addr  <= 0;
      fa_mem_req (False, 0, ?);
      rg_state <= STATE_REFILLING;
      $display ("AWS_DDR4_Adapater.ma_ddr4_ready; start serving requests.");
   endmethod

   // ----------------
   // Status methods; can be called at any time.
   // Normal response is OK.
   // If tohost is watched, and has been written, transitions to TERMINATED
   // If any memory error, goes to ERR.

   method Bit #(8) mv_status;
      return rg_status;
   endmethod
endmodule

// ================================================================

endpackage
