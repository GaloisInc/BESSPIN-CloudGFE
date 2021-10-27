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

// ----------------
// AXI

import AXI4_Types     :: *;
import AXI4_Fabric    :: *;
import AXI4_Deburster :: *;

// ================================================================
// Project imports

// MMIO fabric
import SoC_Map        :: *;
import AXI_Param_Defs :: *;
import MMIO_Fabric    :: *;

// Core
import Core_IFC     :: *;
import Core         :: *;

import Interrupt_Defs :: *;

// IPs on the mmio fabric (other than memory)
import PLIC             :: *;    // For interface to PLIC interrupt sources, in Core_IFC
import Boot_ROM         :: *;
import UART_Model       :: *;
import AWS_MMIO_to_Host :: *;

`ifdef INCLUDE_PC_TRACE
import PC_Trace :: *;
`endif

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
   interface AXI4_Slave_IFC  #(AXI4_Wd_Id, AXI4_Wd_Addr, AXI4_Wd_Data_A, AXI4_Wd_User)
      dma_server;

   // AXI4 interface facing DDR
   interface AXI4_Master_IFC #(AXI4_Wd_Id,
			       AXI4_Wd_Addr,
			       AXI4_Wd_Data_A,
			       AXI4_Wd_User)    to_ddr4;

   // AXI4 64-bit interface facing uncached DDR
   interface AXI4_Master_IFC #(AXI4_Wd_Id,
			       AXI4_Wd_Addr,
			       AXI4_Wd_Data_B,
			       AXI4_Wd_User)    to_ddr4_0_uncached;

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

   // Interrupts from AWS host to hardware
   // x[31] is set/clear; x[3:0] is intr number
   method Action ma_aws_host_to_hw_interrupt (Bit #(32) x);

`ifdef INCLUDE_GDB_CONTROL
   // To external controller (E.g., GDB)
   interface Server #(Control_Req, Control_Rsp) server_external_control;
`endif

`ifdef INCLUDE_PC_TRACE
   interface Get #(PC_Trace) g_pc_trace;
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
   Reset dm_power_on_reset <- exposeCurrentReset;    // TODO: plumb this in from outside
   Core_IFC #(N_External_Interrupt_Sources)  core <- mkCore (dm_power_on_reset);

   // AXI4 Deburster in front of coherent DMA port
   AXI4_Deburster_IFC #(AXI4_Wd_Id,
			AXI4_Wd_Addr,
			AXI4_Wd_Data_A,
			AXI4_Wd_User)   dma_server_axi4_deburster <- mkAXI4_Deburster_A;
   mkConnection (dma_server_axi4_deburster.to_slave, core.dma_server);

   // MMIO Fabric
   MMIO_Fabric_IFC mmio_fabric <- mkMMIO_Fabric;

   // SoC Boot ROM
   Boot_ROM_IFC  boot_rom <- mkBoot_ROM;
   // AXI4 Deburster in front of Boot_ROM
   AXI4_Deburster_IFC #(AXI4_Wd_Id,
			AXI4_Wd_Addr,
			AXI4_Wd_Data_B,
			AXI4_Wd_User)    boot_rom_axi4_deburster <- mkAXI4_Deburster_B;

   // SoC IPs
   UART_IFC              uart0        <- mkUART;
   AWS_MMIO_to_Host_IFC  mmio_to_host <- mkAWS_MMIO_to_Host;

   // ----------------
   // MMIO fabric initiator connections

   // CPU IMem initiator (MMIO) to mmio_fabric
   mkConnection (core.cpu_imem_master,  mmio_fabric.v_from_masters [core_initiator_num]);

   // ----------------
   // MMIO fabric target connections
   // Note: see 'SoC_Map' for 'target_num' definitions

   // MMIO fabric to Boot ROM
   mkConnection (mmio_fabric.v_to_slaves [boot_rom_target_num], boot_rom_axi4_deburster.from_master);
   mkConnection (boot_rom_axi4_deburster.to_slave,         boot_rom.slave);

   // MMIO fabric to UART0
   mkConnection (mmio_fabric.v_to_slaves [uart16550_0_target_num],  uart0.slave);

   // MMIO fabric to AWS Host Access
   mkConnection (mmio_fabric.v_to_slaves [host_access_target_num], mmio_to_host.axi4_S);

   // ----------------
   // Connect interrupt sources for CPU external interrupt request inputs.

   FIFOF #(Bit #(1)) f_irq_virtio_1 <- mkFIFOF;
   FIFOF #(Bit #(1)) f_irq_virtio_2 <- mkFIFOF;
   FIFOF #(Bit #(1)) f_irq_virtio_3 <- mkFIFOF;
   FIFOF #(Bit #(1)) f_irq_virtio_4 <- mkFIFOF;

   (* fire_when_enabled, no_implicit_conditions *)
   rule rl_connect_external_interrupt_requests;
      // UART
      Bool intr = uart0.intr;
      core.core_external_interrupt_sources [irq_num_uart16550_0].m_interrupt_req (intr);

      // Integer last_irq_num = irq_num_uart16550_0;
      Integer last_irq_num = 4;

      // Tie off remaining interrupt request lines (2..N)
      for (Integer j = last_irq_num + 1; j < valueOf (N_External_Interrupt_Sources); j = j + 1)
	 core.core_external_interrupt_sources [j].m_interrupt_req (False);

      // Non-maskable interrupt request. [Tie-off; TODO: connect to genuine sources]
      core.nmi_req (False);
   endrule

   rule rl_connect_external_interrupt_1;
      let x <- pop (f_irq_virtio_1);
      core.core_external_interrupt_sources [1].m_interrupt_req (unpack (x));
   endrule

   rule rl_connect_external_interrupt_2;
      let x <- pop (f_irq_virtio_2);
      core.core_external_interrupt_sources [2].m_interrupt_req (unpack (x));
   endrule

   rule rl_connect_external_interrupt_3;
      let x <- pop (f_irq_virtio_3);
      core.core_external_interrupt_sources [3].m_interrupt_req (unpack (x));
   endrule

   rule rl_connect_external_interrupt_4;
      let x <- pop (f_irq_virtio_4);
      core.core_external_interrupt_sources [4].m_interrupt_req (unpack (x));
   endrule

   // ================================================================
   // SOFT RESET

   function Action fa_reset_start_actions (Bool running);
      action
	 core.cpu_reset_server.request.put (running);
	 uart0.server_reset.request.put (?);
	 mmio_fabric.reset;
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
   interface to_ddr4_0_uncached = mmio_fabric.v_to_slaves [ddr4_0_uncached_target_num];

   // UART to external console
   interface get_to_console   = uart0.get_to_console;
   interface put_from_console = uart0.put_from_console;

   // AWS host memory access
   interface Get to_aws_host   = mmio_to_host.to_aws_host;
   interface Put from_aws_host = mmio_to_host.from_aws_host;

   // Interrupts from AWS host to hardware
   // x[31] is set/clear; x[3:0] is intr number
   method Action ma_aws_host_to_hw_interrupt (Bit #(32) x);
      Bit #(1)  irq_set = x [31];
      Bit #(4)  irq_num = x [3:0];    // Virtio device's interrupt numbering

      case (irq_num)
	 1: f_irq_virtio_1.enq (irq_set);
	 2: f_irq_virtio_2.enq (irq_set);
	 3: f_irq_virtio_3.enq (irq_set);
	 4: f_irq_virtio_4.enq (irq_set);
	 default: begin
		     $display ("%0d: ERROR: AWS_SoC_Top.ma_aws_host_to_hw_interrupt: ", cur_cycle);
		     $display ("    Unsupported irq_num %0d (irq_set = %0d)", irq_num, irq_set);
		  end
      endcase

      if (verbosity != 0) begin
	 $display ("%0d: %m: ma_aws_host_to_hw_interrupt: irq_num %02d  irq_set %02d",
	    cur_cycle, irq_num, irq_set);
      end
   endmethod

   // To external controller (E.g., GDB)
`ifdef INCLUDE_GDB_CONTROL
   interface server_external_control = toGPServer (f_external_control_reqs, f_external_control_rsps);
`endif

`ifdef INCLUDE_PC_TRACE
   interface Get  g_pc_trace = core.g_pc_trace;
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
// Specialization of parameterized AXI4 Debursters for this SoC.

(* synthesize *)
module mkAXI4_Deburster_A (AXI4_Deburster_IFC #(AXI4_Wd_Id,
						AXI4_Wd_Addr,
						AXI4_Wd_Data_A,
						AXI4_Wd_User));
   let m <- mkAXI4_Deburster;
   return m;
endmodule

(* synthesize *)
module mkAXI4_Deburster_B (AXI4_Deburster_IFC #(AXI4_Wd_Id,
						AXI4_Wd_Addr,
						AXI4_Wd_Data_B,
						AXI4_Wd_User));
   let m <- mkAXI4_Deburster;
   return m;
endmodule

// ================================================================

endpackage
