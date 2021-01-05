// See HS_gdbstub.c for documentation

#pragma once

typedef struct {
    SimpleQueue *queue_gdbstub_req_to_hw;      // DMI read/write requests to guest
    SimpleQueue *queue_gdbstub_rsp_from_hw;    // DMI write-response from guest
} HS_Gdbstub_State;

#include "HS_gdbstub_protos.h"
