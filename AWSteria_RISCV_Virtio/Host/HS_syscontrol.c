// Copyright (c) 2020-2021 Bluespec, Inc.  All Rights Reserved
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

#include "HS_msg.h"
#include "HS_syscontrol.h"

// ================================================================
// For debugging this module

static int verbosity = 0;

// ================================================================
// On the 'Control and Status' channel to OCL, control commands are 32-bit words
// formatted as:    { 28'b_data, 4'b_tag }

// Control tags:

#define HS_syscontrol_tag_ddr4_is_loaded   0
//       [31:4]  = ?:    ddr4 has been loaded from host

#define HS_syscontrol_tag_verbosity        1
//       [31:8]  = logdelay, [7:4] = verbosity

#define HS_syscontrol_tag_no_watch_tohost  2
//       [31:4]  = ?:    set 'watch_tohost' to False

#define HS_syscontrol_tag_watch_tohost     3
//       [31:4]  = x     set 'watch_tohost' to True; tohost_addr = (x << 2)

#define HS_syscontrol_tag_shutdown         4

#define HS_syscontrol_tag_pc_trace         5
//       [7:4]   = off (0) or on (non-zero)
//       [31:8]  = pc trace interval max

// ================================================================

HS_SysControl_State *HS_syscontrol_init (void)
{
    HS_SysControl_State *state = (HS_SysControl_State *) malloc (sizeof (HS_SysControl_State));
    state->terminating = false;
    return state;
}

// ================================================================
// This function performs 'syscontrol work'

bool HS_syscontrol_do_some_work (void *comms_state, HS_SysControl_State *state)
{
    static bool first_time = true;

    bool did_some_work = false;

    if (first_time) {
	// Initialize with some commands
	uint32_t command;

	// ----------------
	// Set up CPU verbosity and logdelay
	uint32_t cpu_verbosity = 0;
	uint32_t logdelay      = 0;    // # of instructions after which to set verbosity
	command = ((logdelay << 24)                   // 24'h_log_delay
		   | (cpu_verbosity << 4)             // 4'h_verbosity
		   | HS_syscontrol_tag_verbosity);


	if (verbosity > 0)
	    fprintf (stdout,
		     "%s: (first time) logdelay = %0x, set verbosity = %0x (chan command: %0x)\n",
		     __FUNCTION__, logdelay, cpu_verbosity, command);

	HS_msg_host_to_hw_chan_put (comms_state, HS_MSG_HOST_TO_HW_CHAN_CONTROL, command);

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
	    command = (tohost_addr             // 29'h_to_host_addr_DW
		       | 0x0                   // 1'b0
		       | HS_syscontrol_tag_watch_tohost);
	    if (verbosity > 0)
		fprintf (stdout, "%s: (first time) set watch tohost, tohost_addr = %0x (chan command: %0x)\n",
			 __FUNCTION__, tohost_addr, command);
	}
	else {
	    command = (0                          // 28'h_0
		       | HS_syscontrol_tag_no_watch_tohost);
	    if (verbosity > 0)
		fprintf (stdout, "%s: (first time) set NO watch tohost (chan command: %0x)\n",
			 __FUNCTION__, command);
	}

	HS_msg_host_to_hw_chan_put (comms_state, HS_MSG_HOST_TO_HW_CHAN_CONTROL, command);

	// ----------------
	// Set up PC trace

	bool     pc_trace_on           = false;
	uint32_t pc_trace_interval_max = 100 - 1;    // 1000000 - 1;

	if (pc_trace_on) {
	    command = ((pc_trace_interval_max << 8) | (0x1 << 4) | HS_syscontrol_tag_pc_trace);
	    if (verbosity > 0)
		fprintf (stdout, "%s: (first time) set pc_trace on; interval_max = %0x (chan command: %0x)\n",
			 __FUNCTION__, pc_trace_interval_max, command);
	}
	else {
	    command = HS_syscontrol_tag_pc_trace;
	    if (verbosity > 0)
		fprintf (stdout, "%s: (first time) set pc_trace off; (chan command: %0x)\n",
			 __FUNCTION__, command);
	}

	HS_msg_host_to_hw_chan_put (comms_state, HS_MSG_HOST_TO_HW_CHAN_CONTROL, command);

	// ----------------
	// Go! Inform hw that DDR4 is loaded, allow the CPU to access it

	command = (0                          // 28'h_0
		   | HS_syscontrol_tag_ddr4_is_loaded);
	if (verbosity > 0)
	    fprintf (stdout,
		     "%s: (first time) send 'DDR4 Loaded', releasing CPU (chan command: %0x)\n",
		     __FUNCTION__, command);

	HS_msg_host_to_hw_chan_put (comms_state, HS_MSG_HOST_TO_HW_CHAN_CONTROL, command);

	first_time    = false;
	did_some_work = true;
    }

    // ----------------
    // Look for syscontrol commands to send control/requests to hw

    // Nothing yet

    // ----------------
    // Process status/responses from hw

    int       err;
    uint32_t  data;
    bool      valid;

    // Check if any status available
    err = HS_msg_hw_to_host_chan_get_nb (comms_state,
					 HS_MSG_HW_TO_HOST_CHAN_STATUS,
					 & data,
					 & valid);
    if (err) {
	fprintf (stdout, "ERROR: %s: HS_msg read HW status err %0d\n", __FUNCTION__, err);
	return false;
    }
    if (! valid) return false;

    // Process the status data.  Encoding:
    //     { 16'tohost_value,
    //       4'ddr4_ready, 2'b0, 1'ddr4_is_loaded, 1'initialized_2, 8'soc_status}

    uint8_t  soc_status     = (data & 0xFF);
    uint8_t  hw_initialized = ((data >> 8) & 0x1);
    uint8_t  ddr4_is_loaded = ((data >> 9) & 0x1);
    uint16_t tohost_value   = ((data >> 16) & 0xFFFF);

    if (soc_status != 0) {
	// Error termination signal from HW
	fprintf (stdout, "HS_syscontrol: soc_status (non-zero, ERROR): 0x%0x\n", soc_status);
	fprintf (stdout, "HS_syscontrol: hw_initialized = %0d\n", hw_initialized);
	fprintf (stdout, "HS_syscontrol: ddr4_is_loaded = %0d\n", ddr4_is_loaded);

	state->terminating = true;
	did_some_work = true;
    }
    else if ((tohost_value != 0) && (! state->terminating)) {
	fprintf (stdout, "HS_syscontrol: tohost_value = 0x%0x", tohost_value);
	uint16_t testnum = (tohost_value >> 1);
	if (testnum == 0)
	    fprintf (stdout, "    (PASS)\n");
	else
	    fprintf (stdout, "    (FAIL on test %0d)\n", testnum);
	fflush (stdout);

	state->terminating = true;
	did_some_work = true;
    }

    return did_some_work;
}

// ================================================================

int HS_syscontrol_finish (void *comms_state, HS_SysControl_State *state)
{
    if (verbosity > 0)
	fprintf (stdout, "%s: Sending SHUTDOWN to hardware\n", __FUNCTION__);

    int err = HS_msg_host_to_hw_chan_put (comms_state,
					  HS_MSG_HOST_TO_HW_CHAN_CONTROL,
					  HS_syscontrol_tag_shutdown);
    return err;
}

// ================================================================
