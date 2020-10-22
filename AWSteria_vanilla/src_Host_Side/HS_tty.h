// See HS_tty.c for documentation

#pragma once

typedef struct {
    SimpleQueue *queue_tty_to_hw;      // From terminal keyboard to HW CPU
    SimpleQueue *queue_tty_from_hw;    // From HW CPU to terminal screen
} HS_tty_State;

#include "HS_tty_protos.h"
