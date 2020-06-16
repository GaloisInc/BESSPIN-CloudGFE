// See HS_syscontrol.c for documentation

#pragma once

typedef struct {
    SimpleQueue *queue_syscontrol_to_hw;      // From syscontrol to HW CPU    (control/request)
    SimpleQueue *queue_syscontrol_from_hw;    // From HW CPU to syscontrol    (status/response)
} HS_SysControl_State;

#include "HS_syscontrol_protos.h"
