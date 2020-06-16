// See HS_virtio.c for documentation

#pragma once

typedef struct {
    // requests from and responses to guest for read/write virtio MMIO
    // device regs/configs
    SimpleQueue *queue_virtio_req_from_hw;
    SimpleQueue *queue_virtio_rsp_to_hw;

    // Interrupt requests to guest from virtio
    SimpleQueue *queue_virtio_irq_to_hw;
} HS_Virtio_State;

#include "HS_virtio_protos.h"
