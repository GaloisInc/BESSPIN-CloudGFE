// Copyright (c) 2020-2021 Bluespec, Inc.  All Rights Reserved
// Author: Rishiyur S. Nikhil

// This module encapsulates communication with a tty (keyboard + screen)

// For now, it's very limited, just for testing: keyboard input is
// taken from stdin, and screen data is immediately written to stdout.
// Eventually, this should connect to a separate terminal window.

// ================================================================
// C lib includes

// This define-macro is needed to avoid this compiler warning:
//   warning: implicit declaration of function ‘pthread_setname_np’
#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <pthread.h>
#include <unistd.h>
#include <assert.h>

// ================================================================
// Project includes

#include "HS_msg.h"
#include "HS_tty.h"

// ================================================================

static int verbosity_tty = 0;

extern FILE *f_debug_virtio;

// ================================================================
// Thread to poll and read keyboard chars

static pthread_t        tty_input_thread;
static pthread_mutex_t  queue_lock         = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t   queue_cond_all_sent = PTHREAD_COND_INITIALIZER;

static void *tty_input_worker (void *opaque)
{
    HS_tty_State *state = (HS_tty_State *) opaque;

    while (true) {
	// Wait while there are still buffered chars not yet sent to HW
	pthread_mutex_lock (& queue_lock);
	while (state->n != 0)
	    pthread_cond_wait (& queue_cond_all_sent, & queue_lock);
	pthread_mutex_unlock (& queue_lock);

	assert (state->n      == 0);
	assert (state->n_sent == 0);

	// Read up to KEYBOARD_LINEBUF_SIZE chars from keyboard,
	// using an ordinary blocking read().
	// This is outside the lock, but the consumer won't be
	// changing anything in 'state' until we read something.
	int stdin_fd = 0;
	state->n = read (stdin_fd, & state->linebuf, KEYBOARD_LINEBUF_SIZE);
	// fprintf (stdout, "%s: Buffered %0d chars\n", __FUNCTION__, state->n);
    }
    return NULL;
}

// ================================================================

HS_tty_State *HS_tty_init (void)
{
    HS_tty_State *state = (HS_tty_State *) malloc (sizeof (HS_tty_State));
    state->n      = 0;
    state->n_sent = 0;

    pthread_create (& tty_input_thread, NULL, & tty_input_worker, state);
    pthread_setname_np (tty_input_thread, "TTY input thread");
    if (verbosity_tty > 0)
	fprintf (stdout, "%s: created TTY input pthread\n", __FUNCTION__);

    return state;
}

// ================================================================
// This function moves data from the tty output queue to the 'terminal' screen

bool HS_tty_do_some_work_from_HW (void *comms_state, HS_tty_State *state)
{
    bool did_some_work = false;

    // ----------------
    // Move data from output queue to terminal screen

    static char linebuf [256];
    static int  linebuf_j       = 0;
    static int  num_idle_passes = 0;

    assert (linebuf_j < 256);    // next char can be inserted at [j]

    // Process at most a certain number of chars for this call
    for (int num_iters = 0; num_iters < 1024; num_iters++) {
	bool      valid;
	uint32_t  data;
	int       err = 0;

	// Get the HW UART chars if available
	err = HS_msg_hw_to_host_chan_get_nb (comms_state, HS_MSG_HW_TO_HOST_CHAN_UART,
					     & data, & valid);
	if (err || (! valid)) break;
	if (verbosity_tty > 0)
	    fprintf (stdout, "%s: chars UART to screen: %08x\n", __FUNCTION__, data);

	// 'data' contains up to 4 chars in its 4 bytes.
	// For each byte, the MSB is a 'valid' bit.
	for (int j = 0; (j < 4) && (data != 0); j++) {
	    int ch = ((data >> 24) & 0xFF);
	    if ((ch & 0x80) != 0) {
		linebuf [linebuf_j] = (ch & 0x7F);

		// Flush linebuf to screen if full,
		// or if char is a "control" char (including '\n')
		if ((linebuf_j == 254) || ((ch & 0x7F) < ' ')) {
		    linebuf [linebuf_j + 1] = 0;
		    fprintf (stdout, "%s", linebuf);
		    if (f_debug_virtio != NULL)
			fprintf (f_debug_virtio, "%s", linebuf);
		    linebuf_j = 0;
		}
		else
		    linebuf_j++;
	    }
	    data = (data << 8);
	}
	did_some_work = true;
    }

    // If we have many idle passes with chars in linebuf, flush linebuf
    // (e.g., for command prompts that do not end in '\n')

    if ((! did_some_work) && (linebuf_j != 0)) {
	if (num_idle_passes > 8) {
	    linebuf [linebuf_j] = 0;

	    fprintf (stdout, "%s", linebuf);
	    fflush (stdout);

	    if (f_debug_virtio != NULL)
		fprintf (f_debug_virtio, "%s", linebuf);

	    linebuf_j       = 0;
	    num_idle_passes = 0;
	}
	else {
	    num_idle_passes++;
	}
    }
    return did_some_work;
}

// ================================================================
// This function moves data from the 'terminal' keyboard towards the HW.

bool HS_tty_do_some_work_towards_HW (void *comms_state, HS_tty_State *state)
{
    bool did_some_work = false;

    // Send as many chars as we can
    pthread_mutex_lock (& queue_lock);
    while (state->n_sent < state->n) {
	int      err;
	bool     valid;

	// Send UART char if possible
	err = HS_msg_host_to_hw_chan_put_nb (comms_state,
					     HS_MSG_HOST_TO_HW_CHAN_UART,
					     state->linebuf [state->n_sent],
					     & valid);
	if (err) break;
	if (! valid) break;

	state->n_sent++;
	did_some_work = true;

	if (state->n_sent == state->n) {
	    state->n      = 0;
	    state->n_sent = 0;
	    pthread_cond_signal (& queue_cond_all_sent);
	}
    }
    pthread_mutex_unlock (& queue_lock);
    return did_some_work;
}

// ================================================================
