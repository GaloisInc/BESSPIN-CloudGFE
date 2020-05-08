// Copyright (c) 2016-2020 Bluespec, Inc. All Rights Reserved.
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

import Core_IFC :: *;
import Core     :: *;
import PLIC     :: *;    // For interface to PLIC interrupt sources, in Core_IFC

// IPs on the fabric (other than memory)
import Boot_ROM    :: *;
import UART_Model  :: *;
import AWS_IPI_Out :: *;


// IPs on the fabric (memory)
import AXI4_Types        :: *;
import AWS_BSV_Top_Defs  :: *;    // For AXI4 bus widths (id, addr, data, user)
import AWS_DDR4_Adapter  :: *;

`ifdef INCLUDE_CAMERA_MODEL
import Camera_Model   :: *;
`endif

`ifdef INCLUDE_ACCEL0
import AXI4_Accel_IFC :: *;
import AXI4_Accel     :: *;
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
   // AXI4 interface facing DDR
   interface AXI4_16_64_512_0_Master_IFC  to_ddr4;

   // UART0 to external console
   interface Get #(Bit #(8)) get_to_console;
   interface Put #(Bit #(8)) put_from_console;

   // Inter-processor interrupts
   interface Put #(Bit #(1)) host_to_hw_interrupt;
   interface Get #(Bit #(1)) hw_to_host_interrupt;

`ifdef INCLUDE_GDB_CONTROL
   // To external controller (E.g., GDB)
   interface Server #(Control_Req, Control_Rsp) server_external_control;
`endif

`ifdef INCLUDE_TANDEM_VERIF
   // To tandem verifier
   interface Get #(Info_CPU_to_Verifier) tv_verifier_info_get;
`endif

   // ----------------
   // Misc. control

   method Action ma_set_verbosity (Bit #(4)   verbosity1, Bit #(64)  logdelay1);

   method Action ma_set_watch_tohost (Bool  watch_tohost, Bit #(64)  tohost_addr);

   method Action ma_ddr4_ready;

   // Misc. status; 0 = running, no error
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

   Reg #(SoC_State) rg_state <- mkReg (SOC_START);

   // SoC address map specifying base and limit for memories, IPs, etc.
   SoC_Map_IFC soc_map <- mkSoC_Map;

   // Core: CPU + Near_Mem_IO (CLINT) + PLIC + Debug module (optional) + TV (optional)
   Core_IFC #(N_External_Interrupt_Sources)  core <- mkCore;

   // SoC Fabric
   AWS_SoC_Fabric_IFC  fabric <- mkAWS_SoC_Fabric;

   // SoC Boot ROM
   Boot_ROM_IFC  boot_rom <- mkBoot_ROM;
   // AXI4 Deburster in front of Boot_ROM
   AXI4_Deburster_IFC #(Wd_Id,
			Wd_Addr,
			Wd_Data,
			Wd_User)  boot_rom_axi4_deburster <- mkAXI4_Deburster_A;

   // SoC Memory
   AWS_DDR4_Adapter_IFC  mem0_controller <- mkAWS_DDR4_Adapter;
   // AXI4 Deburster in front of SoC Memory
   AXI4_Deburster_IFC #(Wd_Id,
			Wd_Addr,
			Wd_Data,
			Wd_User)  mem0_controller_axi4_deburster <- mkAXI4_Deburster_A;

   // SoC IPs
   UART_IFC   uart0  <- mkUART;

   AWS_IPI_Out_IFC  ipi_out <- mkAWS_IPI_Out;

`ifdef INCLUDE_ACCEL0
   // Accel0 master to fabric
   AXI4_Accel_IFC  accel0 <- mkAXI4_Accel;
`endif

   // ----------------
   // SoC fabric master connections
   // Note: see 'SoC_Map' for 'master_num' definitions

   // CPU IMem master to fabric
   mkConnection (core.cpu_imem_master,  fabric.v_from_masters [imem_master_num]);

   // CPU DMem master to fabric
   mkConnection (core.cpu_dmem_master,  fabric.v_from_masters [dmem_master_num]);

`ifdef INCLUDE_ACCEL0
   // accel_aes0 to fabric
   mkConnection (accel0.master,  fabric.v_from_masters [accel0_master_num]);
`endif

   // ----------------
   // SoC fabric slave connections
   // Note: see 'SoC_Map' for 'slave_num' definitions

   // Fabric to Boot ROM
   mkConnection (fabric.v_to_slaves [boot_rom_slave_num], boot_rom_axi4_deburster.from_master);
   mkConnection (boot_rom_axi4_deburster.to_slave,        boot_rom.slave);

   // Fabric to Deburster to Mem Controller
   mkConnection (fabric.v_to_slaves [mem0_controller_slave_num], mem0_controller_axi4_deburster.from_master);
   mkConnection (mem0_controller_axi4_deburster.to_slave,        mem0_controller.slave);

   // Fabric to UART0
   mkConnection (fabric.v_to_slaves [uart0_slave_num],  uart0.slave);

   // Fabric to IPI_out
   mkConnection (fabric.v_to_slaves [ipi_out_slave_num], ipi_out.slave);

`ifdef INCLUDE_ACCEL0
   // Fabric to accel0
   mkConnection (fabric.v_to_slaves [accel0_slave_num], accel0.slave);
`endif

`ifdef HTIF_MEMORY
   AXI4_Slave_IFC#(Wd_Id, Wd_Addr, Wd_Data, Wd_User) htif <- mkAxi4LRegFile(bytes_per_htif);

   mkConnection (fabric.v_to_slaves [htif_slave_num], htif);
`endif

   // ----------------
   // Connect interrupt sources for CPU external interrupt request inputs.

   Reg #(Bool) rg_host_to_hw_interrupt <- mkReg (False);

   (* fire_when_enabled, no_implicit_conditions *)
   rule rl_connect_external_interrupt_requests;
      // UART
      Bool intr = uart0.intr;
      core.core_external_interrupt_sources [irq_num_uart0].m_interrupt_req (intr);
      Integer last_irq_num = irq_num_uart0;

      // Host-to-HW inter-processor interrupt
      core.core_external_interrupt_sources [irq_num_host_to_hw_ipi].m_interrupt_req (rg_host_to_hw_interrupt);
      last_irq_num = irq_num_host_to_hw_ipi;

`ifdef INCLUDE_ACCEL0
      Bool intr_accel0 = accel0.interrupt_req;
      core.core_external_interrupt_sources [irq_num_accel0].m_interrupt_req (intr_accel0);
      last_irq_num = irq_num_accel0;
`endif

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

	 mem0_controller.ma_set_addr_map (soc_map.m_mem0_controller_addr_base,
					  soc_map.m_mem0_controller_addr_lim);

	 uart0.set_addr_map (soc_map.m_uart0_addr_base, soc_map.m_uart0_addr_lim);

`ifdef INCLUDE_ACCEL0
	 accel0.init (fabric_default_id,
		      soc_map.m_accel0_addr_base,
		      soc_map.m_accel0_addr_lim);
`endif

	 if (verbosity != 0) begin
	    $display ("  SoC address map:");
	    $display ("  Boot ROM:        0x%0h .. 0x%0h",
		      soc_map.m_boot_rom_addr_base,
		      soc_map.m_boot_rom_addr_lim);
	    $display ("  Mem0 Controller: 0x%0h .. 0x%0h",
		      soc_map.m_mem0_controller_addr_base,
		      soc_map.m_mem0_controller_addr_lim);
	    $display ("  UART0:           0x%0h .. 0x%0h",
		      soc_map.m_uart0_addr_base,
		      soc_map.m_uart0_addr_lim);
	 end
      endaction
   endfunction

   // ----------------
   // Initial reset; CPU comes up running.

   rule rl_reset_start_initial (rg_state == SOC_START);
      Bool running = True;
      fa_reset_start_actions (running);
      rg_state <= SOC_RESETTING;

      $display ("%0d: AWS_SoC_Top.rl_reset_start_initial ...", cur_cycle);
   endrule

   rule rl_reset_complete_initial (rg_state == SOC_RESETTING);
      fa_reset_complete_actions;
      rg_state <= SOC_IDLE;

      $display ("%0d: AWS_SoC_Top.rl_reset_complete_initial", cur_cycle);
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

      $display ("%0d: AWS_SoC_Top.rl_ndm_reset_start (non-debug-module) running = ",
		cur_cycle, fshow (running));
   endrule

   rule rl_ndm_reset_complete (rg_state == SOC_RESETTING_NDM);
      fa_reset_complete_actions;
      rg_state <= SOC_IDLE;

      core.ndm_reset_client.response.put (rg_running);

      $display ("%0d: AWS_SoC_Top.rl_ndm_reset_complete (non-debug-module) running = ",
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
	 $display ("%0d: AWS_SoC_Top.rl_handle_external_req_read_request", cur_cycle);
         $display ("    ", fshow (req));
      end
   endrule

   rule rl_handle_external_req_read_response;
      let x <- core.dm_dmi.read_data;
      let rsp = Control_Rsp {status: external_control_rsp_status_ok, result: signExtend (x)};
      f_external_control_rsps.enq (rsp);
      if (verbosity != 0) begin
	 $display ("%0d: AWS_SoC_Top.rl_handle_external_req_read_response", cur_cycle);
         $display ("    ", fshow (rsp));
      end
   endrule

   rule rl_handle_external_req_write (req.op == external_control_req_op_write_control_fabric);
      f_external_control_reqs.deq;
      core.dm_dmi.write (truncate (req.arg1), truncate (req.arg2));
      // let rsp = Control_Rsp {status: external_control_rsp_status_ok, result: 0};
      // f_external_control_rsps.enq (rsp);
      if (verbosity != 0) begin
         $display ("%0d: AWS_SoC_Top.rl_handle_external_req_write", cur_cycle);
         $display ("    ", fshow (req));
      end
   endrule

   rule rl_handle_external_req_err (   (req.op != external_control_req_op_read_control_fabric)
				    && (req.op != external_control_req_op_write_control_fabric));
      f_external_control_reqs.deq;
      let rsp = Control_Rsp {status: external_control_rsp_status_err, result: 0};
      f_external_control_rsps.enq (rsp);

      $display ("%0d: AWS_SoC_Top.rl_handle_external_req_err: unknown req.op", cur_cycle);
      $display ("    ", fshow (req));
   endrule
`endif

   // ================================================================
   // INTERFACE

   // External real memory
   interface to_ddr4 = mem0_controller.to_ddr4;

   // UART to external console
   interface get_to_console   = uart0.get_to_console;
   interface put_from_console = uart0.put_from_console;

   // Inter-processor interrupts
   interface Put host_to_hw_interrupt;
      method Action put (Bit #(1) x);
	 rg_host_to_hw_interrupt <= unpack (x);
      endmethod
   endinterface

   interface Get hw_to_host_interrupt = ipi_out.ipi_out_get;

   // To external controller (E.g., GDB)
`ifdef INCLUDE_GDB_CONTROL
   interface server_external_control = toGPServer (f_external_control_reqs, f_external_control_rsps);
`endif

`ifdef INCLUDE_TANDEM_VERIF
   // To tandem verifier
   interface tv_verifier_info_get = core.tv_verifier_info_get;
`endif

   // ----------------
   // Misc. control

   method Action ma_set_verbosity (Bit #(4)   verbosity1, Bit #(64)  logdelay1);
      core.set_verbosity (verbosity1, logdelay1);
   endmethod

   method Action ma_set_watch_tohost (Bool  watch_tohost, Bit #(64)  tohost_addr);
      mem0_controller.ma_set_watch_tohost (watch_tohost, tohost_addr);
   endmethod

   method Action ma_ddr4_ready;
      mem0_controller.ma_ddr4_ready;
   endmethod

   // ----------------
   // Misc. status; 0 = running, no error
   method Bit #(8) mv_status;
      return mem0_controller.mv_status;
   endmethod
endmodule: mkAWS_SoC_Top

// ================================================================
// Specialization of parameterized AXI4 Deburster for this SoC.

(* synthesize *)
module mkAXI4_Deburster_A (AXI4_Deburster_IFC #(Wd_Id,
						Wd_Addr,
						Wd_Data,
						Wd_User));
   let m <- mkAXI4_Deburster;
   return m;
endmodule

// ================================================================

endpackage
