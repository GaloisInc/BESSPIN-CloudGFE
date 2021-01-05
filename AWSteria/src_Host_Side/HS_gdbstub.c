// Copyright (c) 2020 Bluespec, Inc.  All Rights Reserved
// Author: Rishiyur S. Nikhil

// This module encapsulates gdbstub (which communicates with GDB)

// ================================================================
// C lib includes

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

// ================================================================
// Project includes

#include "SimpleQueue.h"
#include "HS_gdbstub.h"

// ================================================================

HS_Gdbstub_State *HS_gdbstub_init (void)
{
    HS_Gdbstub_State *state = (HS_Gdbstub_State *) malloc (sizeof (HS_Gdbstub_State));
    state->queue_gdbstub_req_to_hw   = SimpleQueueInit ();
    state->queue_gdbstub_rsp_from_hw = SimpleQueueInit ();
    return state;
}

// ================================================================
// gdbstub DMI request to hw (guest)
// Check if available

int HS_gdbstub_req_to_hw_notEmpty (HS_Gdbstub_State *state, bool *p_notEmpty)
{
    *p_notEmpty = (! SimpleQueueEmpty (state->queue_gdbstub_req_to_hw));
    return 0;
}

// ================
// Send it

int HS_gdbstub_req_to_hw_data (HS_Gdbstub_State *state, uint32_t *p_data)
{
    uint64_t data;
    SimpleQueueGet (state->queue_gdbstub_req_to_hw, & data);
    *p_data = data;
    return 0;
}

// ================================================================
// gdbstub DMI response from hw (guest)
// Check if available

int HS_gdbstub_rsp_from_hw_notFull (HS_Gdbstub_State *state, bool *p_notFull)
{
    *p_notFull = true;
    return 0;
}

// ================================
// Get gdbstub DMI request to hw (guest)

int HS_gdbstub_rsp_from_hw_data (HS_Gdbstub_State *state, uint32_t data)
{
    SimpleQueuePut (state->queue_gdbstub_rsp_from_hw, data);
}

// ================================================================
// This function performs gdbstub actions

bool HS_gdbstub_do_some_work (HS_Gdbstub_State *state)
{
    bool did_some_work = false;

    // TODO:
    //   check if command arrived from GDB; execute it by
    //   enqueueing DMI requests to hw
    //
    //   check if DMI responses arrived from hw, complete the GDB
    //   request.

    return did_some_work;
}

// ================================================================
