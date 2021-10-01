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

#include "AWSteria_Host_lib.h"

// ----------------
// Project includes

#include "Memhex32_read.h"

#include "HS_msg.h"
#include "HS_syscontrol.h"
#include "HS_tty.h"
#include "HS_pc_trace.h"
#include "HS_virtio.h"
#include "HS_virtio.h"
#include "HS_gdbstub.h"

// ================================================================
// A constant for the size of each of the 4 AWS DDRs

#define MEM_16G              (1ULL << 34)

// Verbosity for functions in this file

static int verbosity = 0;

// ================================================================

int readback_check (void *comms_state, uint8_t *buf, uint64_t addr_base, uint64_t addr_lim)
{
#define READBACK_BUFSIZE 0x1000        // 4KB = 1 page = 1 AXI4 burst
    static uint8_t *readback_buf = NULL;

    if (verbosity > 0)
	fprintf (stdout, "%s: Readback downloaded data to cross-check: base 0x%0lx lim 0x%0lx (size 0x%0lx bytes)\n",
		 __FUNCTION__, addr_base, addr_lim, addr_lim - addr_base);

    int rc;
    if (readback_buf == NULL) {
	readback_buf = (uint8_t *) malloc (READBACK_BUFSIZE);
	if (readback_buf == NULL) {
	    fprintf (stdout, "%s: ERROR could not malloc 0x%0x bytes for readback_buf\n",
		     __FUNCTION__, READBACK_BUFSIZE);
	    rc = 1;
	    return 1;
	}
    }
    memset (readback_buf, 0, READBACK_BUFSIZE);

    size_t read_size = READBACK_BUFSIZE;
    int    errs      = 0;
    for (uint64_t  addr_readback = addr_base;
	 addr_readback < addr_lim;
	 addr_readback += read_size) {
	if ((addr_lim - addr_readback) < READBACK_BUFSIZE)
	    read_size = addr_lim - addr_readback;

	rc = AWSteria_AXI4_read (comms_state, readback_buf, read_size, addr_readback);
	if (rc != 0) {
	    fprintf (stdout, "ERROR: DMA read failed on channel 0");
	    return rc;
	}

	// fprintf (stdout, "        checking readback-data of %0ld bytes ...\n", read_size);
	for (uint64_t j = 0; j < read_size; j += 4) {
	    uint32_t *p1 = (uint32_t *) (buf + addr_readback + j);
	    uint32_t *p2 = (uint32_t *) (readback_buf + j);
	    if (*p1 != *p2) {
		if (verbosity > 0)
		    fprintf (stdout, "        ERROR: read-back at addr %0lx: 0x%08x expected, 0x%08x actual\n",
                             addr_readback + j, *p1, *p2);
		errs++;
	    }
	    else {
		// fprintf (stdout, "        %08lx: %08x\n", addr_readback + j, *p1);
	    }
	}
    }
    if (errs > 0)
	fprintf (stdout, "Number of readback errors: %0d words (ignore if ROM addrs)\n", errs);

    return ((errs == 0) ?  0 : 1);
}

// ================================================================
// Load memory using DMA

#define BUF_SIZE 0x400000000llu

int load_mem_hex32_using_DMA (void *comms_state, char *filename)
{
    int rc;
    // int channel = 0;

    if (verbosity > 0)
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
    memset (buf, 0, BUF_SIZE);

    // Read the memhex file
    uint64_t  addr_base, addr_lim;
    rc = memhex32_read (filename, buf, BUF_SIZE, & addr_base, & addr_lim);
    if (rc != 0) {
	fprintf (stdout, "%s: ERROR reading Memhex32 file: %s\n", __FUNCTION__, filename);
	rc = 1;
	goto out;
    }
    if (verbosity > 0) {
	fprintf (stdout, "Memhex32 file read ok.\n");
	fprintf (stdout, "    addr_base 0x%0lx  addr_lim 0x%0lx (%0ld bytes)\n",
		 addr_base, addr_lim, addr_lim - addr_base);
    }
    if (addr_base >= addr_lim) {
	fprintf (stdout, "    Memhex32 file is empty! Abandoning download\n");
	rc = 1;
	goto out;
    }

    // ================
    // Download to DDR4:
    // - in chunks that do not cross 4K boundaries
    // - destination addrs must be 64-byte aligned

    fprintf (stdout, "%s: downloading to DDR addr 0x%0lx, 0x%0lx bytes\n",
	     __FUNCTION__, addr_base, addr_lim - addr_base);
    rc = AWSteria_AXI4_write (comms_state, & (buf [addr_base]), addr_lim - addr_base, addr_base);
    if (rc != 0) {
	fprintf (stdout, "%s: DMA write failed on channel 0\n", __FUNCTION__);
	goto out;
    }
    fprintf (stdout, "... done\n");

    // ================
    // Sanity check: readback a small amount and cross-check

    rc = readback_check (comms_state, buf, addr_base, addr_lim);

    rc = 0;    // TODO: RESTORE AFTER DEBUG

    // ================

out:
    return (rc != 0 ? 1 : 0);
}

// ================================================================
// Run the hardware and interact with it

int run_hardware (void          *comms_state,
		  const uint16_t gdbport,
		  const char    *tun_iface,
		  const int      enable_virtio_console,
		  const int      xdma_enabled,
		  const char    *block_files [],
		  const int      num_block_files)
{
    int err;
    HS_SysControl_State *syscontrol_state = HS_syscontrol_init ();
    HS_tty_State        *tty_state        = HS_tty_init ();
    HS_pc_trace_State   *pc_trace_state   = HS_pc_trace_init (NULL);
    HS_Virtio_State     *virtio_state     = HS_virtio_init (comms_state,
							    tun_iface,
							    enable_virtio_console,
							    xdma_enabled,
							    block_files,
							    num_block_files);
    HS_Gdbstub_State    *gdbstub_state    = ((gdbport == 0)
					     ? NULL
					     : HS_gdbstub_init (comms_state, gdbport));

    // ----------------
    // Main work loop.
    // "Round-robin" service of logically independent "processes"
    // For each "process", call do_some_work() and move packets from
    // producers to consumers.

    if (verbosity > 0)
	fprintf (stdout, "%s: starting main work loop\n", __FUNCTION__);
    
    struct timeval  tv;
    const uint64_t  TERMINATION_DELAY_USEC          = 1000000;    // 1 sec (SWAG)
    uint64_t        termination_delay_start_usec    = 0;
    uint64_t        idle_iterations_before_shutdown = 0;

    // 0: running
    // 1: termination started
    // 2: sent SHUTDOWN to HW
    uint8_t  termination_state = 0;

    // Main loop
    for (uint64_t  iter_num = 0; true; iter_num++) {
	bool did_some_work = false;

	// ================
	// Check termination and do termination protocol

	if ((termination_state == 0) && syscontrol_state->terminating) {
	    if (verbosity > 0)
		fprintf (stdout, "Termination signal received; delaying %0ld usecs before shutdown\n",
			 TERMINATION_DELAY_USEC);
	    fflush (stdout);
	    gettimeofday (& tv, NULL);
	    uint64_t cur_usec            = (tv.tv_sec * 1000000 + tv.tv_usec);
	    termination_delay_start_usec = cur_usec;
	    termination_state            = 1;
	}

	if (termination_state == 1) {
	    gettimeofday (& tv, NULL);
	    uint64_t cur_usec = (tv.tv_sec * 1000000 + tv.tv_usec);
	    if ((cur_usec - termination_delay_start_usec) > TERMINATION_DELAY_USEC) {
		if (verbosity > 0) {
		    fprintf (stdout, "Termination delay (%0ld usecs) elapsed; shutting down\n",
			     TERMINATION_DELAY_USEC);
		    fprintf (stdout, "%ld idle iterations before shutdown\n",
			     idle_iterations_before_shutdown);
		}
		break;
	    }
	}

	// ================================
	// VIRTIO work

	did_some_work |= HS_virtio_do_some_work_A (comms_state, virtio_state);

	// Keep doing Virtio MMIO work at highest priority
	if (did_some_work)
	    continue;

	// ================================
	// TTY work

	did_some_work |= HS_tty_do_some_work_from_HW (comms_state, tty_state);
	did_some_work |= HS_tty_do_some_work_towards_HW (comms_state, tty_state);

	// ================================
	// PC Trace work

	did_some_work |= HS_pc_trace_do_some_work (comms_state, pc_trace_state);

	// ================================
	// HW System Control (this is not the TTY for CPU!)

	did_some_work |= HS_syscontrol_do_some_work (comms_state, syscontrol_state);

	// ================================
	// gdbstub <=> HW Debug Module communication

	if (gdbstub_state != NULL)
	    did_some_work |= HS_gdbstub_do_some_work (comms_state, gdbstub_state);

	// ================================
	if (! did_some_work) {
	    idle_iterations_before_shutdown++;
	    // usleep (10);    TODO: Fixup?
	}
	else {
	    idle_iterations_before_shutdown = 0;
	}
    }

    err = HS_syscontrol_finish (comms_state, syscontrol_state);

    return err;
}

// ****************************************************************

void print_help (int argc, char *argv [])
{
    fprintf (stdout, "Usage:  %s  [args]    where args are:\n", argv [0]);
    fprintf (stdout, "  --help, -h                   Print this help message\n");
    fprintf (stdout, "  --elf        <foo.elf>       filename to be loaded on startup\n");
    fprintf (stdout, "  --memhex32   <foo.memhex32>  filename to be loaded on startup\n");
    fprintf (stdout, "  --gdbport    <n>             TCP port number to listen for GDB connection\n");
    fprintf (stdout, "  --blockdev   <foo.img>       filename for Virtio block device\n");
    fprintf (stdout, "  --tundev     </dev...>       device filename for Virtio network tunnel driver\n");
}

bool get_arg (int argc, char *argv [], const char *argname, char **argval)
{
    if (argval != NULL)
	*argval = NULL;

    for (int j = 0; j < argc; j++) {
	if (strcmp (argname, argv [j]) == 0) {
	    if ((strcmp (argname,  "--help") == 0)
		|| (strcmp (argname,  "-h") == 0)) {
		return true;
	    }
	    if ((j + 1) == argc) {
		fprintf (stdout, "ERROR: command line flag %s requires an argument\n", argname);
		return false;
	    }
	    if (argv [j+1][0] == '-') {
		// Next word looks like a flag, not an arg value
		fprintf (stdout, "ERROR: command line flag %s requires an argument\n", argname);
		return false;
	    }
	    *argval = argv [j+1];
	    return true;
	}
    }
    return false;
}

// ****************************************************************
// MAIN

// For logging virtio transactions
extern FILE *f_debug_virtio;

int main (int argc, char *argv [])
{
    int rc;

    if (get_arg (argc, argv, "--help", NULL)
	|| get_arg (argc, argv, "-h", NULL)) {
	print_help (argc, argv);
	return 0;
    }

    char *elf, *memhex32, *gdbport_s, *blockdev, *tundev;
    get_arg (argc, argv, "--elf",       & elf);
    get_arg (argc, argv, "--memhex32",  & memhex32);
    get_arg (argc, argv, "--gdbport",   & gdbport_s);
    get_arg (argc, argv, "--blockdev",  & blockdev);
    get_arg (argc, argv, "--tundev",    & tundev);

    uint16_t gdbport = 0;
    if (gdbport_s != NULL) {
	gdbport = strtoul (gdbport_s, NULL, 0);
	if (gdbport == 0) {
	    fprintf (stdout, "ERROR: invalid TCP port number: %s\n", gdbport_s);
	    return -1;
	}
    }

    if (verbosity > 0) {
	fprintf (stdout, "Command-line args are:\n");
	if (elf != NULL)       fprintf (stdout, "  elf        %s\n", elf);
	if (memhex32 != NULL)  fprintf (stdout, "  memhex32   %s\n", memhex32);
	if (gdbport_s != NULL) fprintf (stdout, "  gdbport  %s (= %0d)\n", gdbport_s, gdbport);
	if (blockdev != NULL)  fprintf (stdout, "  blockdev   %s\n", blockdev);
	if (tundev != NULL)    fprintf (stdout, "  tundev     %s\n", tundev);
    }

    // ----------------------------------------------------------------
    // Initialize host-HW comms

    void *comms_state = HS_msg_initialize ();
    if (comms_state == NULL) {
	return 1;
    }

    // ----------------
    // For logging virtio transactions, for debugging
    /*
    f_debug_virtio = fopen ("log_virtio.txt", "w");
    if (f_debug_virtio != NULL)
        fprintf (stdout, "%s: logging virtio debug messages to log_virtio.txt\n", __FUNCTION__);
    */

    /*
    // This version interleaves virtio trace with UART output
    f_debug_virtio = stdout;
    fprintf (stdout, "%s: logging virtio debug messages to stdout\n", __FUNCTION__);
    */

    // ================================================================
    // Load memhex file, if given

    if (memhex32 != NULL) {
	rc = load_mem_hex32_using_DMA (comms_state, memhex32);
	if (rc != 0) {
	    fprintf (stdout, "ERROR: loading memhex32 file %s failed\n", memhex32);
	    goto out;
	}
    }
    else {
	fprintf (stdout, "No memhex32 file specified: skipping loading\n");
    }

    // ================================================================
    // Start the work loop

    // TODO: the following should come from command-line args
    const int   enable_virtio_console = 0;
    const int   xdma_enabled          = 1;

    const char *block_files [1] = { NULL };
    int   num_block_files = 0;

    if (blockdev != NULL) {
	block_files [0] = blockdev;
	num_block_files = 1;
    }

    // Start the hardware
    rc = run_hardware (comms_state,
		       gdbport,
		       tundev,
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

    rc = HS_msg_finalize (comms_state);
    if (rc != 0) {
	return 1;
    }
}

// ================================================================
