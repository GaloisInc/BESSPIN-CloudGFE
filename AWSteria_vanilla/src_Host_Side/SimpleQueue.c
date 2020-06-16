// Copyright (c) ???? [ Original copyright? ]
// Copyright (c) 2020 for modifications by Bluespec, Inc.

// Author: [ Is there a different original author? ]
// Author: Joe Stoy
// Author: Rishiyur S. Nikhil

/* Very simple queue
 * These are FIFO queues which discard the new data when full.
 *
 * Queue is empty when in == out.
 * If in != out, then
 *  - items are placed into in before incrementing in
 *  - items are removed from out before incrementing out
 * Queue is full when in == (out-1 + SIMPLEQUEUE_SIZE) % SIMPLEQUEUE_SIZE;
 *
 * The queue will hold SIMPLEQUEUE_ELEMENTS number of items before the
 * calls to SimpleQueuePut() fail.
 */

// ================================================================
// C lib includes

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

// ----------------
// Project includes

#include "SimpleQueue.h"

// ================================================================

SimpleQueue *SimpleQueueInit (void)
{
    SimpleQueue *queue = (SimpleQueue *) malloc (sizeof (SimpleQueue));
    if (queue == NULL) {
	fprintf (stderr, "ERROR: %s: malloc failed\n", __FUNCTION__);
	exit (1);
    }
    queue->in  = 0;
    queue->out = 0;
}

// ================================================================

int SimpleQueuePut (SimpleQueue *queue, uint64_t data)
{
    if (queue->in == (( queue->out - 1 + SIMPLEQUEUE_SIZE) % SIMPLEQUEUE_SIZE)) {
	// queue is full; cannot put
        return -1;
    }
    queue->buf [queue->in] = data;
    queue->in = (queue->in + 1) % SIMPLEQUEUE_SIZE;
    return 0;
}

// ================================================================
// Return head item and pop it from queue

int SimpleQueueGet (SimpleQueue *queue, uint64_t *p_data)
{
    if(queue->in == queue->out) {
	// queue is empty; cannot get
	*p_data = 0xDEADBEEF;
        return -1;
    }
    *p_data = queue->buf [queue->out];
    queue->out = (queue->out + 1) % SIMPLEQUEUE_SIZE;
    return 0;
}

// ================================================================
// Return head item without popping it from queue

int SimpleQueueFirst (SimpleQueue *queue, uint64_t *p_data)
{
    if(queue->in == queue->out) {
	// queue is empty; no first element
	*p_data = 0xDEADBEEF;
        return -1;
    }
    *p_data = queue->buf [queue->out];
    return 0;
}

// ================================================================
// Full?

bool SimpleQueueFull (SimpleQueue *queue)
{
  return (queue->in == (( queue->out - 1 + SIMPLEQUEUE_SIZE) % SIMPLEQUEUE_SIZE));
}

// ================================================================
// Empty?

bool SimpleQueueEmpty (SimpleQueue *queue)
{
  return (queue->in == queue->out);
}

// ================================================================
// Return number of elements currently in the queue

int SimpleQueueOccupancy (SimpleQueue *queue)
{
    if (queue->in >= queue->out)
	return (queue->in - queue->out);
    else
	return (queue->in + SIMPLEQUEUE_SIZE - queue->out);
}

// ================================================================
