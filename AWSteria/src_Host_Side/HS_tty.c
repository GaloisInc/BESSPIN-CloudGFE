// Copyright (c) 2020 Bluespec, Inc.  All Rights Reserved
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
#include <unistd.h>

// ================================================================
// Project includes

#include "SimpleQueue.h"
#include "HS_tty.h"

// ================================================================

static int verbosity_tty = 0;

// ================================================================

HS_tty_State *HS_tty_init (void)
{
    HS_tty_State *state = (HS_tty_State *) malloc (sizeof (HS_tty_State));
    state->queue_tty_to_hw   = SimpleQueueInit ();
    state->queue_tty_from_hw = SimpleQueueInit ();
    return state;
}

// ================================================================
// Check if a char is available from tty keyboard to hw

int HS_tty_to_hw_notEmpty (HS_tty_State *state, bool *p_notEmpty)
{
    *p_notEmpty = (! SimpleQueueEmpty (state->queue_tty_to_hw));
    return 0;
}

// ================================================================
// Send char from tty keyboard to hw

int HS_tty_to_hw_data (HS_tty_State *state, uint32_t *p_data)
{
    uint64_t data;
    SimpleQueueGet (state->queue_tty_to_hw, & data);
    *p_data = data;

    if (verbosity_tty > 0)
	fprintf (stdout, "HS_tty_to_hw_data: input char: %02x\n", *p_data);

    return 0;
}

// ================================================================
// Check if char can be sent to tty screen from hw

int HS_tty_from_hw_notFull (HS_tty_State *state, bool *p_notFull)
{
    *p_notFull = true;
    return 0;
}

// ================================================================
// Send character from hw to tty screen

int HS_tty_from_hw_data (HS_tty_State *state, uint32_t data)
{
    if (verbosity_tty > 0)
	fprintf (stdout, "HS_tty_from_hw_data: output char: %02x\n", data);

    SimpleQueuePut (state->queue_tty_from_hw, data);
}

// ================================================================
// This function moves data from the 'terminal' keyboard to the tty
// input queue, and from the tty output queue to the 'terminal' screen

bool HS_tty_do_some_work (HS_tty_State *state)
{
    bool did_some_work = false;

    // ----------------
    // Move data from terminal keyboard to input queue

    int stdin_fd = 0;
    int fd_max = -1;
    fd_set rfds,  wfds, efds;
    int delay = 10; // ms
    struct timeval tv;

    FD_ZERO (& rfds);
    FD_ZERO (& wfds);
    FD_ZERO (& efds);
    FD_SET  (stdin_fd, & rfds);
    fd_max = stdin_fd;

    tv.tv_sec  = delay / 1000;
    tv.tv_usec = (delay % 1000) * 1000;
    int ret = select (fd_max + 1, & rfds, & wfds, & efds, & tv);
    if (FD_ISSET (stdin_fd, & rfds) &&
	(! SimpleQueueFull (state->queue_tty_to_hw))) {
	// Read a char from stdin and enqueue
	char buf;
	int ret = read (0, & buf, 1);
	if (ret == 1) {
	    SimpleQueuePut (state->queue_tty_to_hw, buf);
	    did_some_work = true;

	    if (verbosity_tty > 0)
		fprintf (stdout, "HS_tty_do_some_work: char keyboard to input queue: %02x\n", buf);

	}
    }

    // ----------------
    // Move data from output queue to terminal screen

    while (! SimpleQueueEmpty (state->queue_tty_from_hw)) {
	uint64_t data;
	SimpleQueueGet (state->queue_tty_from_hw, & data);
	int ch = data;

	if (verbosity_tty > 0)
	    fprintf (stdout, "HS_tty_do_some_work: char output queue to screen: %02x\n", ch);

	/*
	fprintf (stdout, "TTY output: %02x", ch);
	if ((' ' <= ch) && (ch < 0x7F))
	    fprintf (stdout, " '%c'", ch);
	else if (data == '\n')
	    fprintf (stdout, " '\\n'");
	else if (data == '\t')
	    fprintf (stdout, " '\\t'");
	else if (data == '\r')
	    fprintf (stdout, " '\\r'");
	fprintf (stdout, "\n");
	*/
	fputc (ch, stdout);

	did_some_work = true;
    }
    fflush (stdout);

    return did_some_work;
}

// ================================================================
