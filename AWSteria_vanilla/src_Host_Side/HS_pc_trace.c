// Copyright (c) 2020-2021 Bluespec, Inc.  All Rights Reserved
// Author: Rishiyur S. Nikhil

// This module encapsulates collecting a stream of 32-bit words from
// the HW and interpreting them as PC trace packets, and saving them
// in a file.

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
#include "HS_pc_trace.h"

// ================================================================

static int verbosity_pc_trace = 0;

// ================================================================

HS_pc_trace_State *HS_pc_trace_init (void)
{
    HS_pc_trace_State *state = (HS_pc_trace_State *) malloc (sizeof (HS_pc_trace_State));
    if (state == NULL) {
	fprintf (stdout, "%s: ERROR: unable to malloc pc_trace state struct\n", __FUNCTION__);
	exit (1);
    }

    state->queue_pc_trace_from_hw = SimpleQueueInit ();

    /*
    state->fp = fopen ("pc_trace.txt", "w");
    if (state->fp == NULL) {
	fprintf (stdout, "%s: ERROR: unable to open pc_trace.txt for writing\n", __FUNCTION__);
	exit (1);
    }
    */
    state->fp = stdout;

    return state;
}

// ================================================================
// Check if word is available from hw

int HS_pc_trace_from_hw_notFull (HS_pc_trace_State *state, bool *p_notFull)
{
    *p_notFull = true;
    return 0;
}

// ================================================================
// Collect word from hw and

int HS_pc_trace_from_hw_data (HS_pc_trace_State *state, uint32_t data)
{
    if (verbosity_pc_trace > 0)
	fprintf (stdout, "HS_pc_trace_from_hw_data: output word: %08x\n", data);

    SimpleQueuePut (state->queue_pc_trace_from_hw, data);
    return 0;
}

// ================================================================
// This function moves data from the pc_trace output queue to the
// recording screen.

bool HS_pc_trace_do_some_work (HS_pc_trace_State *state)
{
    bool did_some_work = false;

    bool ready = false;

    static uint32_t cycle_lo, cycle_hi, instret_lo, instret_hi, pc_lo, pc_hi;
    static int      index = 0;

    // ----------------
    // Move data from output queue to pc trace file

    while (! SimpleQueueEmpty (state->queue_pc_trace_from_hw)) {
	uint64_t data;
	SimpleQueueGet (state->queue_pc_trace_from_hw, & data);
	switch (index) {
	case 0: cycle_lo   = data; break;
	case 1: cycle_hi   = data; break;
	case 2: instret_lo = data; break;
	case 3: instret_hi = data; break;
	case 4: pc_lo      = data; break;
	case 5: pc_hi      = data; ready = true; break;
	default: fprintf (stdout, "HS_pc_trace_do_some_work: INTERNAL ERROR: index is not 0..5\n");
	}

	if (verbosity_pc_trace > 0)
	    fprintf (stdout, "HS_pc_trace_do_some_work: pc trace data word [%0d] from hw: %08lx\n", index, data);

	if (ready) {
	    uint64_t cycle, instret, pc;

	    cycle   = cycle_hi;    cycle   = ((cycle   << 32) | cycle_lo);
	    instret = instret_hi;  instret = ((instret << 32) | instret_lo);
	    pc      = pc_hi;       pc      = ((pc      << 32) | pc_lo);
	    fprintf (stdout, "PC Trace: cycle %0ld  instret %0ld  pc %0lx\n", cycle, instret, pc);

	    ready = false;
	    index = 0;
	}
	else {
	    index ++;
	}

	did_some_work = true;
    }
    fflush (stdout);

    return did_some_work;
}

// ================================================================
