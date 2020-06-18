// Copyright (c) 2016-2020 Bluespec, Inc. All Rights Reserved.
// Author: Rishiyur S. Nikhil

package AWS_Host_Access;

// mkAWS_Host_Access is a simple AXI4 slave that is a 'proxy' for a
// the AWS host, which actually services all the AXI4 transactions.
// It simply forwards the Wr_Addr, Wr_Data, and Rd_Addr request
// structs (from the SoC fabric) to the AWS host, and forwards the
// Wr_Resp and Rd_Data response structs from the AWS host back into
// the SoC fabric.

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

import AXI4        :: *;
import SourceSink  :: *;
import Fabric_Defs :: *;
import SoC_Map     :: *; // for Wd_SId
import AWS_BSV_Top_Defs :: *;    // For AXI4 bus widths (id, addr, data, user)

// ================================================================

interface AWS_Host_Access_IFC;
   // Main Fabric Reqs/Rsps
   interface AXI4_Slave #( Wd_SId, Wd_Addr, Wd_Data
                         , Wd_AW_User_0, Wd_W_User_0, Wd_B_User_0
                         , Wd_AR_User_0, Wd_R_User_0) slave;

   // Transport to/from host
   interface Get #(Bit #(32)) to_aws_host;
   interface Put #(Bit #(32)) from_aws_host;
endinterface

// ================================================================

// From SoC_Fabric to AWS host
typedef union tagged {
   AXI4_AWFlit#(Wd_SId, Wd_Addr, Wd_AW_User_0) WAddr;
   AXI4_WFlit#(Wd_Data, Wd_W_User_0)           WData;
   AXI4_ARFlit#(Wd_SId, Wd_Addr, Wd_AR_User_0) RAddr;
   } Tagged_AXI4_Req
deriving (Bits, FShow);

// The following should be the size of a 32-bit vector that is large
// enough to hold a packed version of an Tagged_AXI4_Req object.
typedef 4 VMax_Req;

typedef Vector #(VMax_Req, Bit #(32)) Req_Buf;

// From AWS host to SoC_Fabric
typedef union tagged {
   AXI4_BFlit#(Wd_SId, Wd_B_User_0)          WResp;
   AXI4_RFlit#(Wd_SId, Wd_Data, Wd_R_User_0) RData;
   } Tagged_AXI4_Rsp
deriving (Bits, FShow);

// The following should be the size of a 32-bit vector that is large
// enough to hold a packed version of an Tagged_AXI4_Rsp object
typedef 4 VMax_Rsp;

typedef Vector #(VMax_Rsp, Bit #(32)) Rsp_Buf;

// ================================================================

(* synthesize *)
module mkAWS_Host_Access (AWS_Host_Access_IFC);

   // 0: quiet; 1 rules
   Integer verbosity = 0;

   FIFOF #(Bit #(32)) f_to_aws_host   <- mkFIFOF;
   FIFOF #(Bit #(32)) f_from_aws_host <- mkFIFOF;

   // # of 32-bit words to send, vector of 32-bit words
   FIFOF #(Tuple2 #(Bit #(8), Req_Buf)) f_req_bufs_to_aws_host <- mkFIFOF;

   // Vector of 32-bit words
   FIFOF #(Rsp_Buf) f_rsp_bufs_from_aws_host <- mkFIFOF;

   // ----------------
   // Connector to AXI4 fabric

   let slavePortShim <- mkAXI4ShimFF;

   // ================================================================
   // BEHAVIOR

   // ---- RD_ADDR
   rule rl_forward_rd_addr;
      let rda <- get(slavePortShim.master.ar);
      let tagged_req = tagged RAddr rda;
      Req_Buf  req_buf = unpack (zeroExtend (pack (tagged_req)));
      f_req_bufs_to_aws_host.enq (tuple2 (4, req_buf));
   endrule

   // ---- WR_ADDR
   rule rl_forward_wr_addr;
      let wra <- get(slavePortShim.master.aw);
      let tagged_req = tagged WAddr wra;
      Req_Buf  req_buf = unpack (zeroExtend (pack (tagged_req)));
      f_req_bufs_to_aws_host.enq (tuple2 (4, req_buf));
   endrule

   // ---- WR_DATA
   rule rl_forward_wr_data;
      let wrd <- get(slavePortShim.master.w);
      let tagged_req = tagged WData wrd;
      Req_Buf  req_buf = unpack (zeroExtend (pack (tagged_req)));
      f_req_bufs_to_aws_host.enq (tuple2 (4, req_buf));
   endrule

   // ================================================================
   // Forward f_req_bufs_to_aws_host to AWS host

   Reg #(Bit #(8)) rg_sent <- mkReg (0);

   rule rl_forward_to_aws_host;
      match { .size, .req_buf } = f_req_bufs_to_aws_host.first;
      f_to_aws_host.enq (req_buf [rg_sent]);
      if (rg_sent + 1 == size) begin
	 f_req_bufs_to_aws_host.deq;
	 rg_sent <= 0;
      end
      else
	 rg_sent <= rg_sent + 1;
   endrule

   // ================================================================
   // Forward from AWS host to f_rsp_bufs_from_aws_host

   Reg #(Bit #(8)) rg_received <- mkReg (0);

   Reg #(Rsp_Buf)  rg_rsp_buf <- mkRegU;

   rule rl_unserialize_from_aws_host;
      let x32 <- pop (f_from_aws_host);
      let rsp_buf = rg_rsp_buf;
      rsp_buf [rg_received] = x32;
      rg_rsp_buf <= rsp_buf;

      if (rg_received == fromInteger (valueOf (VMax_Rsp) - 1)) begin
	 f_rsp_bufs_from_aws_host.enq (rg_rsp_buf);
	 rg_received <= 0;
      end
      else
	 rg_received <= rg_received + 1;
   endrule

   rule rl_distribute_from_aws_host;
      Rsp_Buf          rsp_buf   <- pop (f_rsp_bufs_from_aws_host);
      Tagged_AXI4_Rsp  tagged_rsp = unpack (truncate (pack (rsp_buf)));
      case (tagged_rsp) matches
	 tagged WResp .wr: slavePortShim.master.b.put(wr);
	 tagged RData .rd: slavePortShim.master.r.put(rd);
      endcase
   endrule

   // ================================================================
   // INTERFACE

   // Main Fabric Reqs/Rsps
   interface  slave = slavePortShim.slave;

   // Transport to/from host
   interface Get to_aws_host   = toGet (f_to_aws_host);
   interface Put from_aws_host = toPut (f_from_aws_host);
endmodule

// ================================================================

endpackage
