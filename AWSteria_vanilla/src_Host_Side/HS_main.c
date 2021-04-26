// Copyright (c) 2020-2021 Bluespec, Inc.  All Rights Reserved
// Author: Rishiyur S. Nikhil

// This module encapsulates communication with a tty (keyboard + screen)

// For now, it's very limited, just for testing: no keyboard input,
// and screen data is immediately written to stdout.  Eventually, this
// should connect to a separate terminal window.

// ================================================================
// C lib includes

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <sys/time.h>

// ----------------
// Virtio library includes

#include "virtio.h"
#include "temu.h"

// ----------------
// Includes for PCI communications

#ifdef IN_F1
#include "fpga_pci.h"
// int fpga_pci_attach(int slot_id, int pf_id, int bar_id, uint32_t flags, pci_bar_handle_t *handle);
// int fpga_pci_poke(pci_bar_handle_t handle, uint64_t offset, uint32_t value);
// int fpga_pci_peek(pci_bar_handle_t handle, uint64_t offset, uint32_t *value);
// int fpga_pci_detach(pci_bar_handle_t handle);

#include "fpga_mgmt.h"
#include "fpga_dma.h"
#include "utils/lcd.h"
#endif

#ifdef IN_SIMULATION
// Simulation library replacing AWS' actual FPGA interaction library
// AWS_Sim_Lib simulates the fpga peek, poke, dma_read and dma_write calls provided by AWS.
#include "AWS_Sim_Lib.h"
#endif

// ----------------
// Project includes

#include "Memhex32_read.h"
#include "SimpleQueue.h"
#include "HS_syscontrol.h"
#include "HS_tty.h"
#include "HS_pc_trace.h"
#include "HS_virtio.h"
#include "HS_msg.h"

// ================================================================
// A constant for the size of each of the 4 AWS DDRs

#define MEM_16G              (1ULL << 34)

// ================================================================
// PCIe parameters and variables

#ifdef IN_F1
pci_bar_handle_t  pci_bar_handle = PCI_BAR_HANDLE_INIT;
#endif

#ifdef IN_SIMULATION
typedef int  pci_bar_handle_t;
pci_bar_handle_t  pci_bar_handle = -1;
#endif


int  pci_slot_id  = 0;
int  pci_pf_id    = 0;
int  pci_bar_id   = 0;
int  pci_read_fd  = -1;    // For DMA over AXI4
int  pci_write_fd = -1;    // For DMA over AXI4

// ================================================================
// Load memory using DMA

#define BUF_SIZE 0x400000000llu

int load_mem_hex32_using_DMA (int slot_id, char *filename)
{
    int rc;
    // int channel = 0;

    fprintf (stdout, "%s: Reading Mem Hex32 file into local buffer: %s\n",
	     __FUNCTION__, filename);

    // Allocate a buffer to read memhex contents
    uint8_t *buf = (uint8_t *) malloc  (BUF_SIZE);
    if (buf == NULL) {
	fprintf (stdout, "%s: ERROR allocating memhex buffer of size: %0lld (0x%0llx)\n",
		 __FUNCTION__, BUF_SIZE, BUF_SIZE);
	rc = 1;
	goto out;
    }

    // Read the memhex file
    uint64_t  addr_base, addr_lim;
    rc = memhex32_read (filename, buf, BUF_SIZE, & addr_base, & addr_lim);
    if (rc != 0) {
	fprintf (stdout, "%s: ERROR reading Mem_hex32 file: %s\n", __FUNCTION__, filename);
	rc = 1;
	goto out;
    }
    fprintf (stdout, "Mem_hex32 file read ok.\n");
    fprintf (stdout, "    addr_base 0x%0lx  addr_lim 0x%0lx (%0ld bytes)\n",
	     addr_base, addr_lim, addr_lim - addr_base);
    if (addr_base >= addr_lim) {
	fprintf (stdout, "    But this is empty! Abandoning download\n");
	rc = 1;
	goto out;
    }

    // ================
    // Download to DDR4:
    // - in chunks that do not cross 4K boundaries
    // - destination addrs must be 64-byte aligned

    fprintf (stdout, "%s: downloading to AWS DDR4\n", __FUNCTION__);
    rc = fpga_dma_burst_write (pci_write_fd, & (buf [addr_base]), addr_lim - addr_base, addr_base);
    if (rc != 0) {
	fprintf (stdout, "%s: DMA write failed on channel 0\n", __FUNCTION__);
	goto out;
    }

    // ================
    // Sanity check: readback a small amount and cross-check

    size_t read_size = addr_lim - addr_base;
    if (read_size > 128) read_size = 128;

    uint8_t *read_buf = (uint8_t *) malloc (read_size);
    if (read_buf == NULL) {
	fprintf (stdout, "%s: ERROR could not malloc %0ld buf\n", __FUNCTION__, read_size);
	rc = 1;
	goto out;
    }

    fprintf (stdout, "%s: reading back previously downloaded data to spot-check\n", __FUNCTION__);
    fprintf (stdout, "    DMA (pci_read_fd = %0d) %0ld bytes from addr 0x%0lx\n",
	     pci_read_fd, read_size, addr_base);

    rc = fpga_dma_burst_read (pci_read_fd, read_buf, read_size, addr_base);
    if (rc != 0) {
	fprintf (stdout, "DMA read failed on channel 0");
	goto out;
    }

    fprintf (stdout, "%s: checking readback-data of %0ld bytes ...\n", __FUNCTION__, read_size);
    for (uint64_t j = 0; j < read_size; j += 4) {
	uint32_t *p1 = (uint32_t *) (buf + addr_base + j);
	uint32_t *p2 = (uint32_t *) (read_buf + j);
	if (*p1 != *p2) {
	    fprintf (stdout, "%s: read-back of mem data differs at addr %0lx\n",
		     __FUNCTION__, addr_base + j);
	    fprintf (stdout, "    Original  word: 0x%08x\n", *p1);
	    fprintf (stdout, "    Read-back word: 0x%08x\n", *p2);
	    rc = 1;
	    goto out;
	}
	fprintf (stdout, "    %08lx: %08x\n", addr_base + j, *p1);
    }
    fprintf (stdout, "%s: checking readback-data of %0ld bytes: OK\n", __FUNCTION__, read_size);

    // ================

out:
    return (rc != 0 ? 1 : 0);
}

// ================================================================
// Startup sequence over OCL

int start_hw (const char *tun_iface,
	      const int   enable_virtio_console,
	      const int   xdma_enabled,
	      const char *block_files [],
	      const int   num_block_files)
{
    const int debug_main_loop_virtio = 0;

    int err;
    HS_SysControl_State *syscontrol_state = HS_syscontrol_init ();
    HS_tty_State        *tty_state        = HS_tty_init ();
    HS_pc_trace_State   *pc_trace_state   = HS_pc_trace_init ();
    HS_Virtio_State     *virtio_state     = HS_virtio_init (tun_iface,
							    enable_virtio_console,
							    xdma_enabled,
							    block_files,
							    num_block_files);

    // ----------------
    // Main work loop.
    // "Round-robin" service of logically independent "processes"
    // For each "process", call do_some_work() and move packets from
    // producers to consumers.

    fprintf (stdout, "%s: starting main work loop\n", __FUNCTION__);
    bool      notEmpty, notFull;
    uint32_t  data;
    
    struct timeval  tv;
    const uint64_t  TERMINATION_DELAY_USEC          = 100000000;    // 100 msecs (SWAG)
    uint64_t        termination_delay_start_usec    = 0;
    uint64_t        idle_iterations_before_shutdown = 0;

    // 0: running
    // 1: termination started
    // 2: sent SHUTDOWN to HW
    uint8_t  termination_state = 0;

    while (true) {
	bool did_some_work = false;

	// ================
	// Check termination and do termination protocol
	if (termination_state == 0) {
	    if (HS_syscontrol_terminating ()) {
		gettimeofday (& tv, NULL);
		uint64_t cur_usec            = (tv.tv_sec * 1000000000 + tv.tv_usec);
		termination_delay_start_usec = cur_usec;
		termination_state            = 1;
		fprintf (stdout, "Termination signal received; delaying %0ld usecs before sending shutdown\n",
			 TERMINATION_DELAY_USEC);
	    }
	}
	else if (termination_state == 1) {
	    gettimeofday (& tv, NULL);
	    uint64_t cur_usec = (tv.tv_sec * 1000000000 + tv.tv_usec);
	    if ((cur_usec - termination_delay_start_usec) > TERMINATION_DELAY_USEC) {
		fprintf (stdout, "Termination delay (%0ld usecs) elapsed; shutting down\n",
			 TERMINATION_DELAY_USEC);
		fprintf (stdout, "%ld idle iterations before shutdown\n",
			 idle_iterations_before_shutdown);

		break;
	    }
	}

	// ================================
	// HW System Control (this is not the TTY for CPU!)

	did_some_work |= HS_syscontrol_do_some_work (syscontrol_state);

	// ----------------
	// Move commands from System Control to hw

	err = HS_syscontrol_to_hw_notEmpty (syscontrol_state, & notEmpty);
	if (err) break;
	err = HS_msg_host_to_hw_CONTROL_notFull (& notFull);
	if (err) break;

	if (notEmpty && notFull) {
	    err = HS_syscontrol_to_hw_data (syscontrol_state, & data);
	    if (err) break;
	    err = HS_msg_host_to_hw_CONTROL_data (data);
	    if (err) break;
	}

	// ----------------
	// Move status/responses from hw to System Control

	err = HS_msg_hw_to_host_STATUS_notEmpty (& notEmpty);
	if (err) break;
	err = HS_syscontrol_from_hw_notFull (syscontrol_state, & notFull);
	if (err) break;

	if (notEmpty && notFull) {
	    err = HS_msg_hw_to_host_STATUS_data (& data);
	    if (err) break;
	    err = HS_syscontrol_from_hw_data (syscontrol_state, data);
	    if (err) break;
	}

	// ================================
	// TTY work

	did_some_work |= HS_tty_do_some_work (tty_state);

	// ----------------
	// Move characters from tty to hw
	err = HS_tty_to_hw_notEmpty (tty_state, & notEmpty);
	if (err) break;
	err = HS_msg_host_to_hw_UART_notFull (& notFull);
	if (err) break;

	if (notEmpty && notFull) {
	    err = HS_tty_to_hw_data (tty_state, & data);
	    if (err) break;
	    err = HS_msg_host_to_hw_UART_data (data);
	    if (err) break;
	}

	// ----------------
	// Move characters from hw to tty

	err = HS_msg_hw_to_host_UART_notEmpty (& notEmpty);
	if (err) break;
	err = HS_tty_from_hw_notFull (tty_state, & notFull);
	if (err) break;

	if (notEmpty && notFull) {
	    err = HS_msg_hw_to_host_UART_data (& data);
	    if (err) break;
	    err = HS_tty_from_hw_data (tty_state, data);
	    if (err) break;
	}

	// ================================
	// PC Trace work

	did_some_work |= HS_pc_trace_do_some_work (pc_trace_state);

	// ----------------
	// Move PC Trace words from hw to host

	err = HS_msg_hw_to_host_PC_TRACE_notEmpty (& notEmpty);
	if (err) break;
	err = HS_pc_trace_from_hw_notFull (pc_trace_state, & notFull);
	if (err) break;

	if (notEmpty && notFull) {
	    err = HS_msg_hw_to_host_PC_TRACE_data (& data);
	    if (err) break;
	    err = HS_pc_trace_from_hw_data (pc_trace_state, data);
	    if (err) break;
	}

	// ================================
	// VIRTIO work

	did_some_work |= HS_virtio_do_some_work (virtio_state);

	// ----------------
	// Move Virtio requests from hw (guest) to virtio

	err = HS_msg_hw_to_host_VIRTIO_MMIO_REQ_notEmpty (& notEmpty);
	if (err) break;
	err = HS_virtio_req_from_hw_notFull (virtio_state, & notFull);
	if (err) break;

	if (notEmpty && notFull) {
	    if (debug_main_loop_virtio > 0)
		fprintf (stdout, "Main loop: HW req to virtio MMIO regs:\n");
	    err = HS_msg_hw_to_host_VIRTIO_MMIO_REQ_data (& data);
	    if (err) break;
	    err = HS_virtio_req_from_hw_data (virtio_state, data);
	    if (err) break;
	    if (debug_main_loop_virtio > 0)
		fprintf (stdout, "    0x%0x\n", data);
	}

	// ----------------
	// Move Virtio MMIO responses from virtio to hw (guest)

	err = HS_virtio_rsp_to_hw_notEmpty (virtio_state, & notEmpty);
	if (err) break;
	err = HS_msg_host_to_hw_VIRTIO_MMIO_RSP_notFull (& notFull);
	if (err) break;

	if (notEmpty && notFull) {
	    if (debug_main_loop_virtio > 0)
		fprintf (stdout, "Main loop: virtio MMIO regs response to HW:\n");
	    err = HS_virtio_rsp_to_hw_data (virtio_state, & data);
	    if (err) break;
	    err = HS_msg_host_to_hw_VIRTIO_MMIO_RSP_data (data);
	    if (err) break;
	    if (debug_main_loop_virtio > 0)
		fprintf (stdout, "    0x%0x\n", data);
	}

	// ----------------
	// Move Virtio MMIO interrupt requests from virtio to hw (guest)

	err = HS_virtio_irq_to_hw_notEmpty (virtio_state, & notEmpty);
	if (err) break;
	err = HS_msg_host_to_hw_VIRTIO_IRQ_notFull (& notFull);
	if (err) break;

	if (notEmpty && notFull) {
	    err = HS_virtio_irq_to_hw_data (virtio_state, & data);
	    if (err) break;
	    err = HS_msg_host_to_hw_VIRTIO_IRQ_data (data);
	    if (err) break;
	}

	// ================================
	if (! did_some_work) {
	    idle_iterations_before_shutdown++;
	    usleep (100);
	}
	else {
	    idle_iterations_before_shutdown = 0;
	}

    }

    fprintf (stdout, "%s: Sending SHUTDOWN to hardware\n", __FUNCTION__);
    err = HS_msg_host_to_hw_CONTROL_data (HS_syscontrol_tag_shutdown);

    return err;
}

// ================================================================

void print_help (int argc, char *argv [])
{
    fprintf (stdout, "Usage:  %s  <optional memhexfile>  <>\n", argv [0]);
}

// ****************************************************************
// argv [1] is memhex file
// argv [2] is block device image file (.img)
// argv [3] is name for tun interface (Ethernet connection)

int main (int argc, char *argv [])
{
    int rc;

    int slot_id = 0;    // TODO: what exactly is this?

    if ((argc > 1)
	&& ((strcmp (argv [1], "--help") == 0)
	    || (strcmp (argv [1], "-h") == 0))) {
	print_help (argc, argv);
	return 0;
    }

    rc = HS_msg_initialize ();
    if (rc != 0) {
	return 1;
    }

    // ================================================================
    // Load memhex file (named in argv [1])

    if (argc > 1) {
	rc = load_mem_hex32_using_DMA (slot_id, argv [1]);
	if (rc != 0) {
	    fprintf (stdout, "Loading the mem hex32 file failed\n");
	    goto out;
	}
    }
    else {
	fprintf (stdout, "No memhex file specified: skipping loading\n");
    }

    // ================================================================
    // Start the work loop

    // TODO: the following should come from command-line args
    const char *tun_iface = NULL;    // network tunnel driver, cf. https://en.wikipedia.org/wiki/TUN/TAP
    const int   enable_virtio_console = 0;
    const int   xdma_enabled          = 1;

    const char *block_files [1] = { NULL };
    int   num_block_files = 0;

    // Get the block-file name (in argv [2])
    if (argc >= 3) {
	block_files [0] = argv [2];
	num_block_files = 1;
    }

    // Get the Ethernet tun interface name (in argv [3])
    if (argc >= 4) {
	tun_iface = argv [3];
    }

    // Start the hardware
    rc = start_hw (tun_iface,
		   enable_virtio_console,
		   xdma_enabled,
		   block_files,
		   num_block_files);
    if (rc != 0) {
	fprintf (stdout, "starting the HW failed");
	goto out;
    }

    // ================================================================

out:

    if (rc != 0) {
        fprintf (stdout, "TEST FAILED\n");
    }
    else {
        fprintf (stdout, "TEST PASSED\n");
    }

    rc = HS_msg_finalize ();
    if (rc != 0) {
	return 1;
    }
}

// ================================================================
