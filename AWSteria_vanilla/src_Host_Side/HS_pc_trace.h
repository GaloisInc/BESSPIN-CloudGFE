// Copyright (c) 2020-2021 Bluespec, Inc.  All Rights Reserved
// Author: Rishiyur S. Nikhil

// See HS_pc_trace.c for documentation

#pragma once

typedef struct {
    SimpleQueue *queue_pc_trace_from_hw;    // From HW to host

    FILE *fp;
} HS_pc_trace_State;

#include "HS_pc_trace_protos.h"
