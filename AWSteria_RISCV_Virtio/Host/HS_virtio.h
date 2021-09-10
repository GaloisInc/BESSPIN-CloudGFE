// Copyright (c) 2020-2021 Bluespec, Inc.  All Rights Reserved
// Author: Rishiyur S. Nikhil

// See HS_virtio.c for documentation

#pragma once

// ================================================================
// PCI stuff

extern int               pci_slot_id;
extern int               pci_pf_id;
extern int               pci_bar_id;

// ================================================================

#define max2(a,b) (((a) >= (b)) ? (a) : (b))

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
    const char       *tun_ifname;    // network tunnel driver, cf. https://en.wikipedia.org/wiki/TUN/TAP
    // DELETE: int               stop_pipe [2];
    // DELETE: pthread_t         io_thread;
} VirtioDevices;

#define FIRST_VIRTIO_IRQ 1

typedef struct {
    VirtioDevices *virtiodevices;
    void          *comms_state;    // AWSteria_Host_State
} HS_Virtio_State;

// ================================================================
// extern function declarations

#include "HS_virtio_protos.h"
