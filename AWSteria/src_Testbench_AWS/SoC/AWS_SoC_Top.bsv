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
import Vector        :: *;
import Clocks        :: *;

// ----------------
// BSV additional libs

import Cur_Cycle   :: *;
import GetPut_Aux  :: *;
import Routable    :: *;
import AXI4        :: *;

// ================================================================
// Project imports

import Fabric_Defs :: *;
import SoC_Map     :: *;

// SoC components (CPU, mem, and IPs)
import Core_IFC :: *;
import Core     :: *;
import PLIC     :: *;    // For interface to PLIC interrupt sources, in Core_IFC

// IPs on the fabric (other than memory)
import Boot_ROM        :: *;
import UART_Model      :: *;
import AWS_Host_Access :: *;
import AXI4_ClockCrossing ::*;


// IPs on the fabric (memory)
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
   interface AXI4_Master #( Wd_Id_14, Wd_Addr_64, Wd_Data_512
                          , Wd_AW_User_0, 4, Wd_B_User_0
                          , Wd_AR_User_0, 4) to_ddr4;

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
module mkAWS_SoC_Top #(Clock core_clk) (AWS_SoC_Top_IFC);
   Reset core_rstn <- mkAsyncResetFromCR(2, core_clk);

   Integer verbosity = 0;    // Normally 0; non-zero for debugging

   Reg #(SoC_State) rg_state <- mkReg (SOC_START);

   // SoC address map specifying base and limit for memories, IPs, etc.
   SoC_Map_IFC soc_map <- mkSoC_Map;

   // Core: CPU + Near_Mem_IO (CLINT) + PLIC + Debug module (optional) + TV (optional)
   Core_IFC #(N_External_Interrupt_Sources)  core <- mkCore (clocked_by core_clk,
							     reset_by   core_rstn);

   // SoC Boot ROM
   Boot_ROM_IFC  boot_rom <- mkBoot_ROM;
   // AXI4 Deburster in front of Boot_ROM
   AXI4_Shim#( Wd_SId, Wd_Addr, Wd_Data
             , Wd_AW_User_0, Wd_W_User_0, Wd_B_User_0
             , Wd_AR_User_0, Wd_R_User_0)
      boot_rom_axi4_deburster <- mkBurstToNoBurst;

   // SoC Memory
   AWS_DDR4_Adapter_IFC  mem0_controller <- mkAWS_DDR4_Adapter;
   // AXI4 Deburster in front of SoC Memory
   AXI4_Shim#( Wd_SId, Wd_Addr, Wd_Data
             , Wd_AW_User_ext, Wd_W_User_ext, Wd_B_User_ext
             , Wd_AR_User_ext, Wd_R_User_ext)
      mem0_controller_axi4_deburster <- mkBurstToNoBurst;

   // SoC IPs
   UART_IFC   uart0  <- mkUART;

   AWS_Host_Access_IFC  aws_host_access <- mkAWS_Host_Access;

`ifdef INCLUDE_ACCEL0
   // Accel0 master to fabric
   AXI4_Accel_IFC  accel0 <- mkAXI4_Accel;
`endif

   // ----------------
   // SoC fabric master connections
   // Note: see 'SoC_Map' for 'master_num' definitions

   Vector#(Num_Masters, AXI4_Master #( Wd_MId_ext, Wd_Addr, Wd_Data
                                     , Wd_AW_User_ext, Wd_W_User_ext, Wd_B_User_ext
                                     , Wd_AR_User_ext, Wd_R_User_ext))
      master_vector = newVector;

   // CPU IMem master to fabric
   AXI4_Master #( Wd_MId_ext, Wd_Addr, Wd_Data
               , Wd_AW_User_ext, Wd_W_User_ext, Wd_B_User_ext
               , Wd_AR_User_ext, Wd_R_User_ext)
      cpu_imem_master = zeroMasterUserFields (extendIDFields (core.cpu_imem_master, 0));
   let imem_crossing <- mkAXI4_ClockCrossingToCC (core_clk, core_rstn);
   mkConnection ( cpu_imem_master, imem_crossing.slave
                , clocked_by core_clk, reset_by core_rstn);
   master_vector[imem_master_num] = imem_crossing.master;

   // CPU DMem master to fabric
   let dmem_crossing <- mkAXI4_ClockCrossingToCC (core_clk, core_rstn);
   mkConnection ( core.core_mem_master, dmem_crossing.slave
                , clocked_by core_clk, reset_by core_rstn);
   master_vector[dmem_master_num] = dmem_crossing.master;

   // ----------------
   // SoC fabric slave connections
   // Note: see 'SoC_Map' for 'slave_num' definitions

   Vector#(Num_Slaves, AXI4_Slave #( Wd_SId, Wd_Addr, Wd_Data
                                   , Wd_AW_User_ext, Wd_W_User_ext, Wd_B_User_ext
                                   , Wd_AR_User_ext, Wd_R_User_ext))
      slave_vector = newVector;
   Vector#(Num_Slaves, Range#(Wd_Addr))   route_vector = newVector;

   // Fabric to Boot ROM
   mkConnection (boot_rom_axi4_deburster.master, boot_rom.slave);
   slave_vector[boot_rom_slave_num] = zeroSlaveUserFields (boot_rom_axi4_deburster.slave);
   route_vector[boot_rom_slave_num] = soc_map.m_boot_rom_addr_range;

   // Fabric to Mem Controller
   AXI4_Master #( Wd_Id_14, Wd_Addr, Wd_Data
                , Wd_AW_User_ext, Wd_W_User_ext, Wd_B_User_ext
                , Wd_AR_User_ext, Wd_R_User_ext)
      tmp = extendIDFields(mem0_controller_axi4_deburster.master, 0);
   mkConnection (tmp, mem0_controller.slave);
   slave_vector[mem0_controller_slave_num] = mem0_controller_axi4_deburster.slave;
   route_vector[mem0_controller_slave_num] = soc_map.m_mem0_controller_addr_range;

   // Fabric to UART0
   slave_vector[uart16550_0_slave_num] = zeroSlaveUserFields (uart0.slave);
   route_vector[uart16550_0_slave_num] = soc_map.m_uart16550_0_addr_range;

   // Fabric to AWS Host Access
   slave_vector[host_access_slave_num] = zeroSlaveUserFields (aws_host_access.slave);
   route_vector[host_access_slave_num] = soc_map.m_host_access_addr_range;

`ifdef INCLUDE_ACCEL0
   // Fabric to accel0
   mkConnection (fabric.v_to_slaves [accel0_slave_num], accel0.slave);
`endif

`ifdef HTIF_MEMORY
   AXI4_Slave_IFC#(Wd_Id, Wd_Addr, Wd_Data, WdUser_0) htif <- mkAxi4LRegFile(bytes_per_htif);

   slave_vector[htif_slave_num] = htif;
   route_vector[htif_slave_num] = soc_map.m_htif_addr_range;
`endif

   // SoC Fabric
   let bus <- mkAXI4Bus ( routeFromMappingTable(route_vector)
                        , master_vector, slave_vector);

   // ----------------
   // Connect interrupt sources for CPU external interrupt request inputs.

   // Interrupt lines are independent (no inter-bit consistency issues), so we
   // can get away with per-bit synchronizers. The Verilog is parameterised on
   // the reset value, though this is not exposed, but the default of 0 is what
   // we want.

   Reg #(Bool) rg_aws_host_to_hw_interrupt <- mkReg (False);

   let uartSync <- mkSyncBitFromCC(core_clk);
   let awsSync  <- mkSyncBitFromCC(core_clk);

`ifdef INCLUDE_ACCEL0
   let accel0Sync <- mkSyncBitFromCC(core_clk);
`endif

   // In SoC clock domain:
   (* fire_when_enabled, no_implicit_conditions *)
   rule rl_connect_external_interrupt_sources;
      // UART
      Bool intr_uart = uart0.intr;
      uartSync.send(intr_uart);

      // AWS Host-to-HW interrupt
      awsSync.send (rg_aws_host_to_hw_interrupt);

`ifdef INCLUDE_ACCEL0
      Bool intr_accel0 = accel0.interrupt_req;
      accel0Sync.send(intr_accel0);
`endif
   endrule

   // In core_clk domain:
   (* fire_when_enabled, no_implicit_conditions *)
   rule rl_connect_external_interrupt_requests;
      // UART
      Bool intr_uart = uartSync.read();
      core.core_external_interrupt_sources [irq_num_uart16550_0].m_interrupt_req (intr_uart);
      Integer last_irq_num = irq_num_uart16550_0;

      // AWS Host-to-HW interrupt
      Bool intr_aws = awsSync.read();
      core.core_external_interrupt_sources [irq_num_host_to_hw].m_interrupt_req (intr_aws);
      last_irq_num = irq_num_host_to_hw;

`ifdef INCLUDE_ACCEL0
      Bool intr_accel0 = accel0Sync.read();
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

   // A little mechanism to transmit CPU reset request and response
   // between the two clock domains

   Reg#(Tuple2#(Bool, Bool)) fromCC <- mkSyncRegFromCC(unpack(0), core_clk);
   Reg#(Bool)                  toCC <- mkSyncRegToCC  (unpack(0), core_clk,core_rstn);

   Reg#(Bool) stateCPUs <- mkReg(False, clocked_by core_clk, reset_by core_rstn);
   Reg#(Bool) stateCPUe <- mkReg(False, clocked_by core_clk, reset_by core_rstn);
   Reg#(Bool) stateSoCs <- mkReg(False);
   Reg#(Bool) stateSoCe <- mkReg(False);

   // in Core domain
   rule start_cpu_reset (fromCC matches {.s, .running} &&& s != stateCPUs);
      stateCPUs <= s;
      core.cpu_reset_server.request.put (running);
   endrule

   // in Core domain
   rule end_cpu_reset;
      let cpu_rsp <- core.cpu_reset_server.response.get;
      let s = !stateCPUe;
      toCC <= s;
      stateCPUe <= s;
   endrule

   function Action fa_reset_start_actions (Bool running);
      action
	 // in SoC domain:
	 let s = !stateSoCs;
	 fromCC   <= tuple2(s, running);
	 stateSoCs <= s;

	 uart0.server_reset.request.put (?);
         boot_rom_axi4_deburster.clear;
         mem0_controller_axi4_deburster.clear;
      endaction
   endfunction

   function Action fa_reset_complete_actions ();
      return
      when (toCC != stateSoCe,
	 action
	    // in SoC domain:
	    stateSoCe <= toCC;

	    let uart0_rsp <- uart0.server_reset.response.get;

	    // Initialize address maps of slave IPs
	    boot_rom.set_addr_map (rangeBase(soc_map.m_boot_rom_addr_range),
				   rangeTop(soc_map.m_boot_rom_addr_range));

	    mem0_controller.ma_set_addr_map (rangeBase(soc_map.m_mem0_controller_addr_range),
					     rangeTop(soc_map.m_mem0_controller_addr_range));

	    uart0.set_addr_map (rangeBase(soc_map.m_uart16550_0_addr_range),
				rangeTop(soc_map.m_uart16550_0_addr_range));

	 `ifdef INCLUDE_ACCEL0
	    accel0.init (fabric_default_id,
			 soc_map.m_accel0_addr_base,
			 soc_map.m_accel0_addr_lim);
	 `endif

	    if (verbosity != 0) begin
	 $display ("  SoC address map:");
	 $display ("  Boot ROM:        0x%0h .. 0x%0h",
		   rangeBase(soc_map.m_boot_rom_addr_range),
		   rangeTop(soc_map.m_boot_rom_addr_range));
	 $display ("  Mem0 Controller: 0x%0h .. 0x%0h",
		   rangeBase(soc_map.m_mem0_controller_addr_range),
		   rangeTop(soc_map.m_mem0_controller_addr_range));
	 $display ("  UART0:           0x%0h .. 0x%0h",
		   rangeBase(soc_map.m_uart16550_0_addr_range),
		   rangeTop(soc_map.m_uart16550_0_addr_range));
	    end
	 endaction);
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

   // Domain crossing for set_verbosity method
   Reg#(Tuple2#(Bit#(4), Bit#(64))) verbReg <- mkSyncRegFromCC(unpack(0), core_clk);

   // In core domain
   rule setVerb;
      match {.v, .d} = verbReg;
      core.set_verbosity (v, d);
   endrule

   // ================================================================
   // INTERFACE

   // External real memory
   interface to_ddr4 = mem0_controller.to_ddr4;

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

   // ----------------
   // Misc. control

   method Action ma_set_verbosity (Bit #(4)   verbosity1, Bit #(64)  logdelay1);
      verbReg <= tuple2 (verbosity1, logdelay1);
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

endpackage
