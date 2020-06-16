// Copyright (c) 2020 Bluespec, Inc.  All Rights Reserved
// Author: Rishiyur S. Nikhil

// This module encapsulates virtio

// ================================================================
// C lib includes

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

// ================================================================
// Project includes

#include "SimpleQueue.h"
#include "HS_virtio.h"

// ================================================================

HS_Virtio_State *HS_virtio_init (void)
{
    HS_Virtio_State *state = (HS_Virtio_State *) malloc (sizeof (HS_Virtio_State));
    state->queue_virtio_req_from_hw = SimpleQueueInit ();
    state->queue_virtio_rsp_to_hw   = SimpleQueueInit ();
    state->queue_virtio_irq_to_hw   = SimpleQueueInit ();
    return state;
}

// ================================================================
// Check if virtio MMIO request is available from hw (guest)

int HS_virtio_req_from_hw_notFull (HS_Virtio_State *state, bool *p_notFull)
{
    *p_notFull = true;
    return 0;
}

// ================================================================
// Get virtio MMIO request from hw (guest)

int HS_virtio_req_from_hw_data (HS_Virtio_State *state, uint32_t data)
{
    SimpleQueuePut (state->queue_virtio_req_from_hw, data);
}

// ================================================================
// Check if a virtio MMIO response is available to send to hw (guest)

int HS_virtio_rsp_to_hw_notEmpty (HS_Virtio_State *state, bool *p_notEmpty)
{
    *p_notEmpty = (! SimpleQueueEmpty (state->queue_virtio_rsp_to_hw));
    return 0;
}

// ================================================================
// Send virtio MMIO response to hw (guest)

int HS_virtio_rsp_to_hw_data (HS_Virtio_State *state, uint32_t *p_data)
{
    uint64_t data;
    SimpleQueueGet (state->queue_virtio_rsp_to_hw, & data);
    *p_data = data;
    return 0;
}

// ================================================================
// Check if a virtio interrupt request is available to send to hw (guest)

int HS_virtio_irq_to_hw_notEmpty (HS_Virtio_State *state, bool *p_notEmpty)
{
    *p_notEmpty = (! SimpleQueueEmpty (state->queue_virtio_irq_to_hw));
    return 0;
}

// ================================================================
// Send virtio interrupt request to hw (guest)

int HS_virtio_irq_to_hw_data (HS_Virtio_State *state, uint32_t *p_data)
{
    uint64_t data;
    SimpleQueueGet (state->queue_virtio_irq_to_hw, & data);
    *p_data = data;
    return 0;
}

// ================================================================
// This function performs virtio MMIO read/write actions

bool HS_virtio_do_some_work (HS_Virtio_State *state)
{
    bool did_some_work = false;

    // ----------------
    // Process virtio MMIO request from HW
    // Requests are 1 32-bit word (read: addr) or 2 32-bit words (write: addr, data)

    int       req_occupancy = SimpleQueueOccupancy (state->queue_virtio_req_from_hw);
    uint64_t  x64;
    SimpleQueueFirst (state->queue_virtio_req_from_hw, & x64);
    uint32_t  addr          = (x64 & 0xFFFFFFFC);    // zero the lsbs
    bool      rsp_notFull   = (! SimpleQueueFull (state->queue_virtio_rsp_to_hw));
    if ((req_occupancy > 0) && rsp_notFull && ((x64 & 0x1) == 0)) {
	// Read request

	// Pop addr|request from queue
	SimpleQueueGet (state->queue_virtio_req_from_hw, & x64);

	// TODO
	fprintf (stdout, "%s: TODO: read virtio device table addr %0x\n", __FUNCTION__, addr);

	// Respond
	uint32_t read_data = 0xDEADBEEF;
	SimpleQueuePut (state->queue_virtio_rsp_to_hw, read_data);

	did_some_work = true;
    }
    else if ((req_occupancy > 1) && rsp_notFull && ((x64 & 0x1) == 1)) {
	// write request

	// Pop addr|request and write-data from queue
	SimpleQueueGet (state->queue_virtio_req_from_hw, & x64);
	SimpleQueueGet (state->queue_virtio_req_from_hw, & x64);
	uint32_t write_data = (x64 & 0xFFFFFFFF);

	// TODO
	fprintf (stdout, "%s: TODO: write virtio device table addr %0x data %0x\n",
		 __FUNCTION__, addr, write_data);

	// Respond 0
	SimpleQueuePut (state->queue_virtio_rsp_to_hw, 0);

	did_some_work = true;
    }

    return did_some_work;
}

// ================================================================
