// Copyright (c) 2020-2021 Bluespec, Inc.  All Rights Reserved
// Author: Rishiyur S. Nikhil

// This module encapsulates gdbstub (which communicates with GDB)

// ================================================================
// C lib includes

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
#include "HS_gdbstub.h"

#include "gdbstub.h"

// ================================================================
// Comms state remembered here during _init, for use by dmi_write() and dmi_read()

static void *local_comms_state;

// ================================================================

HS_Gdbstub_State *HS_gdbstub_init (void *comms_state, unsigned short port)
{
    HS_Gdbstub_State *state = (HS_Gdbstub_State *) malloc (sizeof (HS_Gdbstub_State));

    FILE *logfile = fopen ("log_gdbstub.txt", "w");
    assert (logfile != NULL);
    fprintf (stdout, "%s: opened log_gdbstub.txt\n", __FUNCTION__);

    int retval = gdbstub_start_tcp (logfile, port);
    if (retval < 0) {
	fprintf (stdout, "ERROR: %s:%s: gdbstub_start_tcp failed\n",
		 __FILE__, __FUNCTION__);
	return NULL;
    }
    fprintf (stdout, "%s: gdbstub_start_tcp returned port %0d\n", __FUNCTION__, retval);

    // Remember comms_state object, for use by dmi_write() and dmi_read();
    local_comms_state = comms_state;

    return state;
}

// ================================================================
// This function performs gdbstub actions (DMI reads and writes)

static int do_some_work_verbosity = 0;

// ----------------
// The following represent queues of DMI requests and responses between:
// - the gdbstub thread (enqueues DMI requests and dequeues DMI read-responses)
// - 'do_some_work()' in the main thread:
//      - dequeues DMI requests and performs them
//      - enqueues DMI responses (for DMI reads)

// ----

typedef struct {
    bool      op_read;
    uint16_t  addr;
    uint32_t  wdata;
} DMI_Req;

#define DMI_REQ_QUEUE_SIZE 1024
static DMI_Req dmi_req_queue [DMI_REQ_QUEUE_SIZE];
static uint32_t dmi_req_queue_hd = 0;
static uint32_t dmi_req_queue_n  = 0;    // current occupancy

static pthread_mutex_t  req_lock         = PTHREAD_MUTEX_INITIALIZER;
// only non-blocking deq, so no need of cond_notEmpty
static pthread_cond_t   req_cond_notFull = PTHREAD_COND_INITIALIZER;

// ----

#define DMI_RSP_QUEUE_SIZE 1024
static uint32_t dmi_rsp_queue [DMI_RSP_QUEUE_SIZE];
static uint32_t dmi_rsp_queue_hd = 0;
static uint32_t dmi_rsp_queue_n  = 0;    // current occupancy

static pthread_mutex_t  rsp_lock          = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t   rsp_cond_notFull  = PTHREAD_COND_INITIALIZER;
static pthread_cond_t   rsp_cond_notEmpty = PTHREAD_COND_INITIALIZER;


// ----------------

bool HS_gdbstub_do_some_work (void *comms_state, HS_Gdbstub_State *p_state)
{
    assert (comms_state != NULL);
    assert (p_state != NULL);

    int  rc;
    bool did_some_work = false;

    // ----------------
    // Forward DMI requests from gdbstub to HW

    bool      avail = false;
    bool      op_read;
    uint16_t  addr;
    uint32_t  wdata;

    // Non-blocking dequeue of DMI Read/Write request from gdbstub
    pthread_mutex_lock (& req_lock);
    avail = (dmi_req_queue_n != 0);
    if (avail) {
	op_read = dmi_req_queue [dmi_req_queue_hd].op_read;
	addr    = dmi_req_queue [dmi_req_queue_hd].addr;
	wdata   = dmi_req_queue [dmi_req_queue_hd].wdata;
	dmi_req_queue_hd = ((dmi_req_queue_hd + 1) % DMI_REQ_QUEUE_SIZE);
	dmi_req_queue_n--;
	pthread_cond_signal (& req_cond_notFull);
    }
    pthread_mutex_unlock (& req_lock);

    // If there is a request, blocking-send it to HW
    if (avail) {
	did_some_work = true;

	if (do_some_work_verbosity > 0) {
	    if (op_read) {
		fprintf (stdout, "%s: DMI req READ addr 0x%0x\n",
			 __FUNCTION__, addr);
	    }
	    else {
		fprintf (stdout, "%s: DMI req WRITE addr 0x%0x data 0x%0x\n",
			 __FUNCTION__, addr, wdata);
	    }
	}

	// Encode 32b: { 8'b_r/w_op, 24'b_dm_addr }
	uint32_t  x = (op_read ? 0x0 : 0x01);
	x  = ((x << 24) | (addr & 0xFFFFFF));

	// Send it
	rc = HS_msg_host_to_hw_chan_put (local_comms_state,
					 HS_MSG_HOST_TO_HW_CHAN_DEBUG_MODULE,
					 x);
	if ((rc == 0) && (! op_read)) {
	    // write-req: also send write-data
	    rc = HS_msg_host_to_hw_chan_put (local_comms_state,
					     HS_MSG_HOST_TO_HW_CHAN_DEBUG_MODULE,
					     wdata);
	}
    }

    // ----------------
    // Forward DMI responses from HW to gdbstub

    // Non-blocking check for DMI Read response data from HW
    uint32_t rdata = 0;
    bool     valid = false;
    rc = HS_msg_hw_to_host_chan_get_nb (local_comms_state,
					HS_MSG_HW_TO_HOST_CHAN_DEBUG_MODULE,
					& rdata, & valid);
    if ((rc == 0) && valid) {
	// HW response available: blocking-send to gdbstub
	pthread_mutex_lock (& rsp_lock);
	while (dmi_rsp_queue_n >= DMI_RSP_QUEUE_SIZE)
	    pthread_cond_wait (& rsp_cond_notFull, & rsp_lock);
	uint32_t tl = ((dmi_rsp_queue_hd + dmi_rsp_queue_n) % DMI_RSP_QUEUE_SIZE);
	dmi_rsp_queue [tl] = rdata;
	dmi_rsp_queue_n++;
	pthread_cond_signal (& rsp_cond_notEmpty);
	pthread_mutex_unlock (& rsp_lock);

	did_some_work = true;
	if (do_some_work_verbosity > 0) {
	    fprintf (stdout, "%s: DMI read resp 0x%0x\n", __FUNCTION__, rdata);
	}
    }

    return did_some_work;
}

// ================================================================

void HS_gdbstub_finish (void *comms_state, HS_Gdbstub_State *p_state)
{
    assert (comms_state != NULL);
    assert (p_state != NULL);

    // Wait for thread to exit
    fprintf (stdout, "%s: waiting in gdbstub_join\n", __FUNCTION__);
    gdbstub_stop ();
    gdbstub_join ();
}

// ****************************************************************
// ****************************************************************
// ****************************************************************
// These functions are invoked by the gdbstub thread
// They only enqueue DMI requests and dequeue responses for the main
// thread to execute.

static int dmi_verbosity = 0;

// ================================================================
// DMI read

void dmi_write (FILE *logfile_fp, uint16_t addr, uint32_t wdata)
{
    if (logfile_fp != NULL) {
	fprintf (logfile_fp, "        ");
	if (dmi_verbosity > 1) fprintf (logfile_fp, "--> ");
	fprintf (logfile_fp, "%s: (addr %0x, wdata %0x)\n",
		 __FUNCTION__, addr, wdata);
	fflush (logfile_fp);
    }

    // Blocking enq of request
    pthread_mutex_lock (& req_lock);
    while (dmi_req_queue_n >= DMI_REQ_QUEUE_SIZE)
	pthread_cond_wait (& req_cond_notFull, & req_lock);
    uint32_t tl = ((dmi_req_queue_hd + dmi_req_queue_n) % DMI_REQ_QUEUE_SIZE);
    dmi_req_queue [tl].op_read = false;
    dmi_req_queue [tl].addr    = addr;
    dmi_req_queue [tl].wdata   = wdata;
    dmi_req_queue_n++;
    pthread_mutex_unlock (& req_lock);

    if ((dmi_verbosity > 1) && (logfile_fp != NULL)) {
	fprintf (logfile_fp, "        <-- %s: (addr %0x, wdata %0x)\n",
		 __FUNCTION__, addr, wdata);
	fflush (logfile_fp);
    }
}

// ================================================================
// DMI read

uint32_t  dmi_read  (FILE *logfile_fp, uint16_t addr)
{
    if ((dmi_verbosity > 1) && (logfile_fp != NULL)) {
	fprintf (logfile_fp, "        --> %s: (addr %0x) ...\n", __FUNCTION__, addr);
	fflush (logfile_fp);
    }

    // Blocking enq of request
    pthread_mutex_lock (& req_lock);
    while (dmi_req_queue_n >= DMI_REQ_QUEUE_SIZE)
	pthread_cond_wait (& req_cond_notFull, & req_lock);
    uint32_t tl = ((dmi_req_queue_hd + dmi_req_queue_n) % DMI_REQ_QUEUE_SIZE);
    dmi_req_queue [tl].op_read = true;
    dmi_req_queue [tl].addr    = addr;
    dmi_req_queue_n++;
    pthread_mutex_unlock (& req_lock);

    if ((dmi_verbosity > 2) && (logfile_fp != NULL)) {
	fprintf (logfile_fp, "            %s: (addr %0x) request enqueued\n",
		 __FUNCTION__, addr);
    }

    // Blocking deq of response
    uint32_t rdata = 0;

    pthread_mutex_lock (& rsp_lock);
    while (dmi_rsp_queue_n == 0)
	pthread_cond_wait (& rsp_cond_notEmpty, & rsp_lock);
    rdata = dmi_rsp_queue [dmi_rsp_queue_hd];
    dmi_rsp_queue_hd = ((dmi_rsp_queue_hd + 1) % DMI_RSP_QUEUE_SIZE);
    dmi_rsp_queue_n--;
    pthread_cond_signal (& rsp_cond_notFull);
    pthread_mutex_unlock (& rsp_lock);

    if (logfile_fp != NULL) {
	fprintf (logfile_fp, "        ");
	if (dmi_verbosity > 1) fprintf (logfile_fp, "<-- ");
	fprintf (logfile_fp, "%s: (addr %0x) => %0x\n",
		 __FUNCTION__, addr, rdata);
	fflush (logfile_fp);
    }

    return rdata;
}

// ================================================================
