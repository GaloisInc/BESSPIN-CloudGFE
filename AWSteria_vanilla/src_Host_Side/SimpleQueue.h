// Copyright (c) ???? [ Original copyright? ]
// Copyright (c) 2020 for modifications by Bluespec, Inc.

// Please see SimpleQueue.c for documentation

#pragma once

#define SIMPLEQUEUE_ELEMENTS 100
#define SIMPLEQUEUE_SIZE (SIMPLEQUEUE_ELEMENTS + 1)

typedef struct {
    uint64_t  buf [SIMPLEQUEUE_SIZE];
    int       in;
    int       out;
} SimpleQueue;

#include "SimpleQueue_protos.h"
