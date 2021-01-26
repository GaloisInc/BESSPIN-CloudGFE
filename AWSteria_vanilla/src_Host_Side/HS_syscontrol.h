// Copyright (c) 2020-2021 Bluespec, Inc.  All Rights Reserved
// Author: Rishiyur S. Nikhil

// See HS_syscontrol.c for documentation

#pragma once

typedef struct {
    SimpleQueue *queue_syscontrol_to_hw;      // From syscontrol to HW CPU    (control/request)
    SimpleQueue *queue_syscontrol_from_hw;    // From HW CPU to syscontrol    (status/response)
} HS_SysControl_State;

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

// ================================================================

#include "HS_syscontrol_protos.h"
