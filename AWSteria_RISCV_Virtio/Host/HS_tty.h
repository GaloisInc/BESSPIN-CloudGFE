// Copyright (c) 2020-2021 Bluespec, Inc.  All Rights Reserved
// Author: Rishiyur S. Nikhil

// See HS_tty.c for documentation

#pragma once

#define KEYBOARD_LINEBUF_SIZE  512

typedef struct {
    char linebuf [KEYBOARD_LINEBUF_SIZE];
    int  n;
    int  n_sent;
} HS_tty_State;

#include "HS_tty_protos.h"
