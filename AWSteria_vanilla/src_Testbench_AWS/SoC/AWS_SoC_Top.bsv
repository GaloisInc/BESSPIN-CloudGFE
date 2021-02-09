// Copyright (c) 2016-2021 Bluespec, Inc. All Rights Reserved.
// Author: Rishiyur S. Nikhil

package AWS_SoC_Top;

// ================================================================
// This package is the SoC "top-level".

// (Note: there will be further layer(s) above this for
//    simulation top-level, FPGA top-level, etc.)

// ================================================================
// Exports

export AWS_SoC_Top_IFC (..), mkAWS_SoC_Top;

// ================================================================
// BSV library imports

import FIFOF         :: *;
import GetPut        :: *;
import ClientServer  :: *;
import Connectable   :: *;

// ----------------
// BSV additional libs

import Cur_Cycle   :: *;
import GetPut_Aux  :: *;

// ================================================================
// Project imports

// Main fabric
import AXI4_Types     :: *;
import AXI4_Fabric    :: *;
import AXI4_Deburster :: *;

import Fabric_Defs    :: *;
import SoC_Map        :: *;
import AWS_SoC_Fabric :: *;

// SoC components (CPU, mem, and IPs)

import Core_IFC     :: *;
import Core         :: *;
import PLIC         :: *;    // For interface to PLIC interrupt sources, in Core_IFC
import Near_Mem_IFC :: *;    // For Wd_{Id,Addr,Data,User}_Dma

// IPs on the fabric (other than memory)
import Boot_ROM        :: *;
import UART_Model      :: *;
import AWS_Host_Access :: *;


// IPs on the fabric (memory)
import AXI4_Types        :: *;
import AWS_BSV_Top_Defs  :: *;    // For AXI4 bus widths (id, addr, data, user)
import AWS_DDR4_Adapter  :: *;

`ifdef INCLUDE_TANDEM_VERIF
import TV_Info :: *;
`endif

`ifdef INCLUDE_GDB_CONTROL
import External_Control :: *;    // Control requests/responses from HSFE
import Debug_Module     :: *;
`endif

// ================================================================
// The outermost interface of the SoC

interface AWS_SoC_Top_IFC;
   // Interface to 'coherent DMA' port of optional L2 cache
   interface AXI4_Slave_IFC #(Wd_Id_Dma, Wd_Addr_Dma, Wd_Data_Dma, Wd_User_Dma)  dma_server;

   // AXI4 interface facing DDR
   interface AXI4_16_64_512_0_Master_IFC  to_ddr4;

   // AXI4 64-bit interface facing uncached DDR
   interface AXI4_16_64_64_0_Master_IFC  to_ddr4_0_uncached;

   // UART0 to external console
   interface Get #(Bit #(8)) get_to_console;
   interface Put #(Bit #(8)) put_from_console;

   // AWS host memory access
   // Stream of AXI4 WR_ADDR, WR_DATA and RD_ADDR requests,
   //     serialized into 32-bit words.
   interface Get #(Bit #(32)) to_aws_host;
   // Stream of AXI4 WR_RESP and RD_DATA responses,
   //     serialized into 32-bit words.
   interface Put #(Bit #(32)) from_aws_host;

   // Interrupt from AWS host to hardware
   method Action ma_aws_host_to_hw_interrupt (Bit #(1) x);

`ifdef INCLUDE_GDB_CONTROL
   // To external controller (E.g., GDB)
   interface Server #(Control_Req, Control_Rsp) server_external_control;
`endif

`ifdef INCLUDE_TANDEM_VERIF
   // To tandem verifier
   interface Get #(Info_CPU_to_Verifier) tv_verifier_info_get;
`endif

   // ----------------------------------------------------------------
   // Misc. control and status

   // ----------------
   // Debugging: set core's verbosity
   method Action ma_set_verbosity (Bit #(4)   verbosity1, Bit #(64)  logdelay1);

   // ----------------
   // For ISA tests: watch memory writes to <tohost> addr
`ifdef WATCH_TOHOST
   method Action ma_set_watch_tohost (Bool  watch_tohost, Bit #(64)  tohost_addr);
   method Bit #(64) mv_tohost_value;
`endif

   // ----------------
   // Inform core that DDR4 has been initialized by AWS and is ready to accept requests
   method Action ma_ddr4_ready;

   // ----------------
   // Environment says ddr4 has been loaded (program memory, ...)
   method Action ma_ddr4_is_loaded;

   // ----------------
   // Misc. status; 0 = running, no error.
   (* always_ready *)
   method Bit #(8) mv_status;
endinterface

// ================================================================
// Local types and constants

typedef enum {SOC_START,
	      SOC_RESETTING,
`ifdef INCLUDE_GDB_CONTROL
	      SOC_RESETTING_NDM,
`endif
	      SOC_IDLE} SoC_State
deriving (Bits, Eq, FShow);

// ================================================================
// The module

(* synthesize *)
module mkAWS_SoC_Top (AWS_SoC_Top_IFC);
   Integer verbosity = 0;    // Normally 0; non-zero for debugging

   Reg #(SoC_State) rg_state          <- mkReg (SOC_START);
   Reg #(Bool)      rg_ddr4_is_loaded <- mkReg (False);

   // SoC address map specifying base and limit for memories, IPs, etc.
   SoC_Map_IFC soc_map <- mkSoC_Map;

   // Core: CPU + Near_Mem_IO (CLINT) + PLIC + Debug module (optional) + TV (optional)
   Core_IFC #(N_External_Interrupt_Sources)  core <- mkCore;

   // AXI4 Deburster in front of coherent DMA port
   AXI4_Deburster_IFC #(Wd_Id_Dma,
			Wd_Addr_Dma,
			Wd_Data_Dma,
			Wd_User_Dma)  dma_server_axi4_deburster <- mkAXI4_Deburster_B;
   mkConnection (dma_server_axi4_deburster.to_slave, core.dma_server);

   // SoC Fabric
   AWS_SoC_Fabric_IFC  fabric <- mkAWS_SoC_Fabric;

   // SoC Boot ROM
   Boot_ROM_IFC  boot_rom <- mkBoot_ROM;
   // AXI4 Deburster in front of Boot_ROM
   AXI4_Deburster_IFC #(Wd_Id,
			Wd_Addr,
			Wd_Data,
			Wd_User)  boot_rom_axi4_deburster <- mkAXI4_Deburster_A;

   // SoC IPs
   UART_IFC   uart0  <- mkUART;

   AWS_Host_Access_IFC  aws_host_access <- mkAWS_Host_Access;

   // ----------------
   // SoC fabric initiator connections
   // Note: see 'SoC_Map' for 'initator_num' definitions

   // CPU IMem initiator (MMIO) to fabric
   mkConnection (core.cpu_imem_master,  fabric.v_from_masters [core_initiator_num]);

   // ----------------
   // SoC fabric target connections
   // Note: see 'SoC_Map' for 'target_num' definitions

   // Fabric to Boot ROM
   mkConnection (fabric.v_to_slaves [boot_rom_target_num], boot_rom_axi4_deburster.from_master);
   mkConnection (boot_rom_axi4_deburster.to_slave,         boot_rom.slave);

   // Fabric to UART0
   mkConnection (fabric.v_to_slaves [uart16550_0_target_num],  uart0.slave);

   // Fabric to AWS Host Access
   mkConnection (fabric.v_to_slaves [host_access_target_num], aws_host_access.slave);

   // ----------------
   // Connect interrupt sources for CPU external interrupt request inputs.

   Reg #(Bool) rg_aws_host_to_hw_interrupt <- mkReg (False);

   (* fire_when_enabled, no_implicit_conditions *)
   rule rl_connect_external_interrupt_requests;
      // UART
      Bool intr = uart0.intr;
      core.core_external_interrupt_sources [irq_num_uart16550_0].m_interrupt_req (intr);
      Integer last_irq_num = irq_num_uart16550_0;

      // AWS Host-to-HW interrupt
      core.core_external_interrupt_sources [irq_num_host_to_hw].m_interrupt_req (rg_aws_host_to_hw_interrupt);
      last_irq_num = irq_num_host_to_hw;

      // Tie off remaining interrupt request lines (2..N)
      for (Integer j = last_irq_num + 1; j < valueOf (N_External_Interrupt_Sources); j = j + 1)
	 core.core_external_interrupt_sources [j].m_interrupt_req (False);

      // Non-maskable interrupt request. [Tie-off; TODO: connect to genuine sources]
      core.nmi_req (False);

      /* For debugging only
      if ((! rg_intr_prev) && intr)
	 $display ("AWS_SoC_Top: intr posedge");
      else if (rg_intr_prev && (! intr))
	 $display ("AWS_SoC_Top: intr negedge");

      rg_intr_prev <= intr;
      */
   endrule

   // ================================================================
   // SOFT RESET

   function Action fa_reset_start_actions (Bool running);
      action
	 core.cpu_reset_server.request.put (running);
	 uart0.server_reset.request.put (?);
	 fabric.reset;
      endaction
   endfunction

   function Action fa_reset_complete_actions ();
      action
	 let cpu_rsp             <- core.cpu_reset_server.response.get;
	 let uart0_rsp           <- uart0.server_reset.response.get;

	 // Initialize address maps of slave IPs
	 boot_rom.set_addr_map (soc_map.m_boot_rom_addr_base,
				soc_map.m_boot_rom_addr_lim);

	 uart0.set_addr_map (soc_map.m_uart16550_0_addr_base, soc_map.m_uart16550_0_addr_lim);

	 if (verbosity != 0) begin
	    $display ("  SoC address map:");
	    $display ("  Boot ROM:        0x%0h .. 0x%0h",
		      soc_map.m_boot_rom_addr_base,
		      soc_map.m_boot_rom_addr_lim);
	    $display ("  UART0:           0x%0h .. 0x%0h",
		      soc_map.m_uart16550_0_addr_base,
		      soc_map.m_uart16550_0_addr_lim);
	    $display ("  Host Access      0x%0h .. 0x%0h",
		      soc_map.m_host_access_addr_base,
		      soc_map.m_host_access_addr_lim);
	 end
      endaction
   endfunction

   // ----------------
   // Initial reset; CPU comes up running.

   rule rl_reset_start_initial (rg_ddr4_is_loaded && (rg_state == SOC_START));
      Bool running = True;
      fa_reset_start_actions (running);
      rg_state <= SOC_RESETTING;

      $display ("%0d: %m.rl_reset_start_initial ...", cur_cycle);
   endrule

   rule rl_reset_complete_initial (rg_state == SOC_RESETTING);
      fa_reset_complete_actions;
      rg_state <= SOC_IDLE;

      $display ("%0d: %m.rl_reset_complete_initial", cur_cycle);
   endrule

   // ----------------
   // NDM (non-debug-module) reset (requested from Debug Module)
   // Request argument indicates if CPU comes up running or halted

`ifdef INCLUDE_GDB_CONTROL
   Reg #(Bool) rg_running <- mkRegU;

   rule rl_ndm_reset_start (rg_state == SOC_IDLE);
      let running <- core.ndm_reset_client.request.get;
      rg_running <= running;

      fa_reset_start_actions (running);
      rg_state <= SOC_RESETTING_NDM;

      $display ("%0d: %m.rl_ndm_reset_start (non-debug-module) running = ",
		cur_cycle, fshow (running));
   endrule

   rule rl_ndm_reset_complete (rg_state == SOC_RESETTING_NDM);
      fa_reset_complete_actions;
      rg_state <= SOC_IDLE;

      core.ndm_reset_client.response.put (rg_running);

      $display ("%0d: %m.rl_ndm_reset_complete (non-debug-module) running = ",
		cur_cycle, fshow (rg_running));
   endrule
`endif

   // ================================================================
   // BEHAVIOR WITH DEBUG MODULE

`ifdef INCLUDE_GDB_CONTROL
   // ----------------------------------------------------------------
   // External debug requests and responses (e.g., GDB)

   FIFOF #(Control_Req) f_external_control_reqs <- mkFIFOF;
   FIFOF #(Control_Rsp) f_external_control_rsps <- mkFIFOF;

   Control_Req req = f_external_control_reqs.first;

   rule rl_handle_external_req_read_request (req.op == external_control_req_op_read_control_fabric);
      f_external_control_reqs.deq;
      core.dm_dmi.read_addr (truncate (req.arg1));
      if (verbosity != 0) begin
	 $display ("%0d: %m.rl_handle_external_req_read_request", cur_cycle);
         $display ("    ", fshow (req));
      end
   endrule

   rule rl_handle_external_req_read_response;
      let x <- core.dm_dmi.read_data;
      let rsp = Control_Rsp {status: external_control_rsp_status_ok, result: signExtend (x)};
      f_external_control_rsps.enq (rsp);
      if (verbosity != 0) begin
	 $display ("%0d: %m.rl_handle_external_req_read_response", cur_cycle);
         $display ("    ", fshow (rsp));
      end
   endrule

   rule rl_handle_external_req_write (req.op == external_control_req_op_write_control_fabric);
      f_external_control_reqs.deq;
      core.dm_dmi.write (truncate (req.arg1), truncate (req.arg2));
      // let rsp = Control_Rsp {status: external_control_rsp_status_ok, result: 0};
      // f_external_control_rsps.enq (rsp);
      if (verbosity != 0) begin
         $display ("%0d: %m.rl_handle_external_req_write", cur_cycle);
         $display ("    ", fshow (req));
      end
   endrule

   rule rl_handle_external_req_err (   (req.op != external_control_req_op_read_control_fabric)
				    && (req.op != external_control_req_op_write_control_fabric));
      f_external_control_reqs.deq;
      let rsp = Control_Rsp {status: external_control_rsp_status_err, result: 0};
      f_external_control_rsps.enq (rsp);

      $display ("%0d: %m.rl_handle_external_req_err: unknown req.op", cur_cycle);
      $display ("    ", fshow (req));
   endrule
`endif

   // ================================================================
   // INTERFACE

   // Interface to 'coherent DMA' port of optional L2 cache
   interface AXI4_Slave_IFC dma_server = dma_server_axi4_deburster.from_master;

   // External real memory
   interface to_ddr4 = core.core_mem_master;

   // External uncached memory
   interface to_ddr4_0_uncached = fabric.v_to_slaves [ddr4_0_uncached_target_num];

   // UART to external console
   interface get_to_console   = uart0.get_to_console;
   interface put_from_console = uart0.put_from_console;

   // AWS host memory access
   // Stream of 32-bit words: every 4 words encapsulates an AXI4
   //     WR_ADDR, WR_DATA or RD_ADDR request.
   interface Get to_aws_host   = aws_host_access.to_aws_host;
   // Stream of 32-bit words: every 4 words encapsulates an AXI4
   //     WR_RESP or RD_DATA response.
   interface Put from_aws_host = aws_host_access.from_aws_host;

   method Action ma_aws_host_to_hw_interrupt (Bit #(1) x);
      rg_aws_host_to_hw_interrupt <= unpack (x);
   endmethod


   // To external controller (E.g., GDB)
`ifdef INCLUDE_GDB_CONTROL
   interface server_external_control = toGPServer (f_external_control_reqs, f_external_control_rsps);
`endif

`ifdef INCLUDE_TANDEM_VERIF
   // To tandem verifier
   interface tv_verifier_info_get = core.tv_verifier_info_get;
`endif

   // ----------------------------------------------------------------
   // Misc. control and status

   // ----------------
   // Debugging: set core's verbosity
   method Action ma_set_verbosity (Bit #(4)   verbosity1, Bit #(64)  logdelay1);
      core.set_verbosity (verbosity1, logdelay1);
   endmethod

   // ----------------
   // For ISA tests: watch memory writes to <tohost> addr
`ifdef WATCH_TOHOST
   method Action ma_set_watch_tohost (Bool  watch_tohost, Bit #(64)  tohost_addr);
      core.set_watch_tohost (watch_tohost, tohost_addr);
   endmethod

   method Bit #(64) mv_tohost_value = core.mv_tohost_value;
`endif

   // ----------------
   // Inform core that DDR4 has been initialized by AWS and is ready to accept requests
   method Action ma_ddr4_ready;
      core.ma_ddr4_ready;
   endmethod

   // ----------------
   // Environment says ddr4 has been loaded (program memory, ...)
   method Action ma_ddr4_is_loaded;
      rg_ddr4_is_loaded <= True;
   endmethod

   // ----------------
   // Misc. status; 0 = running, no error.
   method Bit #(8) mv_status;
      return core.mv_status;
   endmethod
endmodule: mkAWS_SoC_Top

// ****************************************************************
// Specialization of parameterized AXI4 Deburster for this SoC.

(* synthesize *)
module mkAXI4_Deburster_A (AXI4_Deburster_IFC #(Wd_Id,
						Wd_Addr,
						Wd_Data,
						Wd_User));
   let m <- mkAXI4_Deburster;
   return m;
endmodule

// ****************************************************************
// Specialization of parameterized AXI4 Deburster for this SoC.

(* synthesize *)
module mkAXI4_Deburster_B (AXI4_Deburster_IFC #(Wd_Id_Dma,
						Wd_Addr_Dma,
						Wd_Data_Dma,
						Wd_User_Dma));
   let m <- mkAXI4_Deburster;
   return m;
endmodule

// ================================================================

endpackage
