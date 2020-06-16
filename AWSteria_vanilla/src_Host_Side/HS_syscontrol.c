// Copyright (c) 2020 Bluespec, Inc.  All Rights Reserved
// Author: Rishiyur S. Nikhil

// This module encapsulates the syscontrol for the whole Host-plus-HW system.
// Note: this is NOT the tty of the HW CPU!

// For now, it's very limited.
// Just initializes some commands at the start.
// Waits for 'completion' from the HW and initiates a shutdown.

// ================================================================
// C lib includes

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <unistd.h>

// ================================================================
// Project includes

#include "SimpleQueue.h"
#include "HS_syscontrol.h"

// ================================================================

HS_SysControl_State *HS_syscontrol_init (void)
{
    HS_SysControl_State *state = (HS_SysControl_State *) malloc (sizeof (HS_SysControl_State));
    state->queue_syscontrol_to_hw   = SimpleQueueInit ();
    state->queue_syscontrol_from_hw = SimpleQueueInit ();
    return state;
}

// ================================================================
// Check if char is a command is available from syscontrol to hw

int HS_syscontrol_to_hw_notEmpty (HS_SysControl_State *state, bool *p_notEmpty)
{
    *p_notEmpty = (! SimpleQueueEmpty (state->queue_syscontrol_to_hw));
    return 0;
}

// ================================================================
// Send command from syscontrol to hw

int HS_syscontrol_to_hw_data (HS_SysControl_State *state, uint32_t *p_data)
{
    uint64_t data;
    SimpleQueueGet (state->queue_syscontrol_to_hw, & data);
    *p_data = data;
    return 0;
}

// ================================================================
// Check if status can be sent to syscontrol from hw

int HS_syscontrol_from_hw_notFull (HS_SysControl_State *state, bool *p_notFull)
{
    *p_notFull = true;
    return 0;
}

// ================================================================
// Send status from hw to syscontrol

int HS_syscontrol_from_hw_data (HS_SysControl_State *state, uint32_t data)
{
    SimpleQueuePut (state->queue_syscontrol_from_hw, data);
}

// ================================================================
// This function performs 'syscontrol work'

bool HS_syscontrol_do_some_work (HS_SysControl_State *state)
{
    static bool first_time = true;
    bool did_some_work = false;
    bool terminate     = false;

    if (first_time) {
	// Initialize with some commands
	uint32_t command;

	// ----------------
	// Set up CPU verbosity and logdelay
	uint32_t cpu_verbosity = 0;
	uint32_t logdelay      = 0;    // # of instructions after which to set verbosity
	command = ((logdelay << 24) | (cpu_verbosity << 2) | 0x1);    // { 24'h_log_delay, 6'h_verbosity, 2'b01 }


	fprintf (stdout, "%s: (first time) logdelay = %0x, set verbosity = %0x (chan command: %0x)\n",
		 __FUNCTION__, logdelay, cpu_verbosity, command);

	SimpleQueuePut (state->queue_syscontrol_to_hw, command);

	// ----------------
	// Set up 'watch tohost' and 'tohost addr'
	// We send a 'tohost' addr with the following convention
	//     misaligned => don't watch any tohost addr
	//     aligned    => watch the given tohost addr
	// TODO: this address should come from a command-line argument; shoudn't be constant here
	bool     watch_tohost = true;
	uint32_t tohost_addr  = 0xbffff000;    // GFE SoC Map
	// uint32_t tohost_addr  = 0x80001000;    // WindSoC SoC map

	if (watch_tohost) {
	    command = (tohost_addr | 0x0 | 0x3);    // { 29'h_to_host_addr_DW, 1'b0, 2'b11 }
	    fprintf (stdout, "%s: (first time) set watch tohost, tohost_addr = %0x (chan command: %0x)\n",
		     __FUNCTION__, tohost_addr, command);
	}
	else {
	    command = (0 | 0x4 | 0x3);    // { 29'h_0, 1'b1, 2'b11 }
	    fprintf (stdout, "%s: (first time) set NO watch tohost (chan command: %0x)\n",
		     __FUNCTION__, command);
	}

	SimpleQueuePut (state->queue_syscontrol_to_hw, command);

	// ----------------
	// Go! Inform hw that DDR4 is loaded, allow the CPU to access it

	command = 0;
	fprintf (stdout,
		 "%s: (first time) send 'DDR4 Loaded' message, allowing CPU access to DDR4 (chan command: %0x)\n",
		 __FUNCTION__, command);
	SimpleQueuePut (state->queue_syscontrol_to_hw, command);

	first_time    = false;
	did_some_work = true;
    }

    // ----------------
    // Look for syscontrol commands to send control/requests to hw

    // Nothing yet

    // ----------------
    // Process status/responses from hw

    while (! SimpleQueueEmpty (state->queue_syscontrol_from_hw)) {
	uint64_t data;
	SimpleQueueGet (state->queue_syscontrol_from_hw, & data);

	if ((data & 0xFF) != 0) {
	    // Termination signal from HW
	    fprintf (stdout, "Final HW status 0x%0lx\n", data);
	    if (data == 1) {
		fprintf (stdout, "    (Non-zero write tohost)\n");
	    }
	    else if (data == 2) {
		fprintf (stdout, "    (Memory system error)\n");
	    }
	    terminate = true;
	}
    }
    fflush (stdout);

    if (terminate)
	fprintf (stdout, "Terminating\n");

    return did_some_work;
}

// ================================================================
