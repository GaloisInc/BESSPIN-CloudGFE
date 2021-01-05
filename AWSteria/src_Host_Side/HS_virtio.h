// See HS_virtio.c for documentation

#pragma once

#define max(a,b) (((a) >= (b)) ? (a) : (b))

typedef struct {
    BlockDevice      *block_device;
    CharacterDevice  *console;
    EthernetDevice   *ethernet_device;
    PhysMemoryMap    *mem_map;
    VIRTIOBusDef     *virtio_bus;
    VIRTIODevice     *virtio_console;
    VIRTIODevice     *virtio_block;
    VIRTIODevice     *virtio_net;
    VIRTIODevice     *virtio_entropy;
    IRQSignal        *irq;
    int               irq_num;
    const char       *tun_ifname;
    int               stop_pipe [2];
    pthread_t         io_thread;
} VirtioDevices;

#define FIRST_VIRTIO_IRQ 1

typedef struct {
    // requests from and responses to guest for read/write virtio MMIO
    // device regs/configs
    SimpleQueue *queue_virtio_req_from_hw;
    SimpleQueue *queue_virtio_rsp_to_hw;

    // Interrupt requests to guest from virtio
    SimpleQueue *queue_virtio_irq_to_hw;

    // Virtio device emulation
    VirtioDevices *virtiodevices;
} HS_Virtio_State;

// ================================================================
// extern function declarations

#include "HS_virtio_protos.h"
