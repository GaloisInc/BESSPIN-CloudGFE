// Copyright (c) 2020 Bluespec, Inc.  All Rights Reserved
// Author: Rishiyur S. Nikhil

// ================================================================
// This module encapsulates the 'message' channels between host-side
// and HW side.  In AWSteria, these messages are carried over the OCL
// interface (AXI4 Lite, 32b addr, 32b data).

// The OCL interface, although an AXI4 Lite interface, is treated as a
// collection of unidirectional FIFO-like channels.  Each channel
// occupies two addresses:
//   a  'data'  address (8-byte aligned)      = addr_base + (chan_id << 3)
//   an 'avail' address (next 4-byte aligned) = addr_base + (chan_id << 3) + 4
// The 'avail' address is used to check if the channel is 'available'

// For hw-to-host channel addr A:
//    reading A+4 => 'notEmpty'       (dequeue will return data)
//    reading A   => dequeued data    (if available, else undefined)

// For host-to-hw channel addr A,
//    reading A+4 => 'notFull'        (enq will succeed)
//    writing A   => enq data         (enqueues data)

// Channels in each direction are independent (it is up to the
// application to interpret channel-pairs a request/response, if
// desired).

// The number of host-to-hw and hw-to-host channels can be different.

// ================================================================
// C lib includes

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

// ================================================================
// Project includes

// AWS_Sim_Lib simulates the fpga peek, poke, dma_read and dma_write calls provided by AWS.
#include "AWS_Sim_Lib.h"

#include "HS_msg.h"

// ================================================================
// Verbosity for this module

static int verbosity = 0;

// ================================================================
// Channel configurations

static
uint32_t mk_chan_avail_addr (uint32_t addr_base, uint32_t chan)
{
    return (((addr_base & 0xFFFFFFF8) + (chan << 3)) | 0x4);
}

static
uint32_t mk_chan_data_addr (uint32_t addr_base, uint32_t chan)
{
    return (((addr_base & 0xFFFFFFF8) + (chan << 3)) | 0x0);
}

// ================================================================
// Test a hw-to-host channel's availability
//     Function result is 0 if ok, 1 if error.
//     If ok, result is '*p_notEmpty'

static
int HS_msg_hw_to_host_chan_notEmpty (uint32_t chan_id, bool *p_notEmpty)
{
    uint32_t  ocl_addr = mk_chan_avail_addr (HS_MSG_HW_TO_HOST_CHAN_ADDR_BASE, chan_id);
    uint32_t  avail;

    int err = fpga_pci_peek (ocl_addr, & avail);
    if (err == 0) {
	*p_notEmpty = (avail != 0);
	if (verbosity != 0)
	    fprintf (stdout, "%s (chan_id %0x) => %0d", __FUNCTION__, chan_id, *p_notEmpty);
    }
    else {
	if (verbosity != 0)
	    fprintf (stdout, "%s (chan_id %0x) => ERROR", __FUNCTION__, chan_id);
    }
    return err;
}

// ================================================================
// Read (dequeue) a hw-to-host channel's data.
//     Function result is 0 if ok, 1 if error.
//     If ok, result is '*p_data'
//        Contains data if channel has data,
//        undefined otherwise (use above 'notEmpty' function first to check if chan has data)

static
int HS_msg_hw_to_host_chan_data (uint32_t chan_id, uint32_t *p_data)
{
    uint32_t  ocl_addr = mk_chan_data_addr (HS_MSG_HW_TO_HOST_CHAN_ADDR_BASE, chan_id);

    int err = fpga_pci_peek (ocl_addr, p_data);
    if (err == 0) {
	if (verbosity != 0)
	    fprintf (stdout, "%s (chan_id %0x) => %0d", __FUNCTION__, chan_id, *p_data);
    }
    else {
	if (verbosity != 0)
	    fprintf (stdout, "%s (chan_id %0x) => ERROR", __FUNCTION__, chan_id);
    }
    return err;
}

// ================================================================
// Test a host-to-hw channel's availability.
//     Function result is 0 if ok, 1 if error.
//     If ok, result is '*p_notFull'

static
int HS_msg_host_to_hw_chan_notFull (uint32_t chan_id, bool *p_notFull)
{
    uint32_t  ocl_addr = mk_chan_avail_addr (HS_MSG_HOST_TO_HW_CHAN_ADDR_BASE, chan_id);
    uint32_t  avail;

    int err = fpga_pci_peek (ocl_addr, & avail);
    if (err == 0) {
	*p_notFull = (avail != 0);
	if (verbosity != 0)
	    fprintf (stdout, "%s (chan_id 0x%0x) => %0d", __FUNCTION__, chan_id, *p_notFull);
    }
    else {
	if (verbosity != 0)
	    fprintf (stdout, "%s (chan_id 0x%0x) => ERROR", __FUNCTION__, chan_id);
    }
    return err;
}

// ================================================================
// Write (enqueue) a host-to-hw channel's data.
//     Function result is 0 if ok, 1 if error.
//     If channel is full, data is discarded
//        (use above 'notFull' function first to check if chan is notFull)

static
int HS_msg_host_to_hw_chan_data (uint32_t chan_id, uint32_t data)
{
    uint32_t  ocl_addr = mk_chan_data_addr (HS_MSG_HOST_TO_HW_CHAN_ADDR_BASE, chan_id);

    int err = fpga_pci_poke (ocl_addr, data);
    if (err == 0) {
	if (verbosity != 0)
	    fprintf (stdout, "%s (chan_id 0x%0x, data 0x%0x)",
		     __FUNCTION__, chan_id, data);
    }
    else {
	if (verbosity != 0)
	    fprintf (stdout, "%s (chan_id 0x%0x, data 0x%0x) => ERROR",
		     __FUNCTION__, chan_id, data);
    }
    return err;
}

// ================================================================
// Control/Status channel

int HS_msg_hw_to_host_STATUS_notEmpty (bool *p_notEmpty)
{
    return HS_msg_hw_to_host_chan_notEmpty (HS_MSG_HW_TO_HOST_CHAN_STATUS, p_notEmpty);
}

int HS_msg_hw_to_host_STATUS_data (uint32_t *p_data)
{
    return HS_msg_hw_to_host_chan_data (HS_MSG_HW_TO_HOST_CHAN_STATUS, p_data);
}

int HS_msg_host_to_hw_CONTROL_notFull (bool *p_notFull)
{
    return HS_msg_host_to_hw_chan_notFull (HS_MSG_HOST_TO_HW_CHAN_CONTROL, p_notFull);
}

int HS_msg_host_to_hw_CONTROL_data (uint32_t data)
{
    return HS_msg_host_to_hw_chan_data (HS_MSG_HOST_TO_HW_CHAN_CONTROL, data);
}

// ================================================================
// UART channel

int HS_msg_hw_to_host_UART_notEmpty (bool *p_notEmpty)
{
    return HS_msg_hw_to_host_chan_notEmpty (HS_MSG_HW_TO_HOST_CHAN_UART, p_notEmpty);
}

int HS_msg_hw_to_host_UART_data (uint32_t *p_data)
{
    return HS_msg_hw_to_host_chan_data (HS_MSG_HW_TO_HOST_CHAN_UART, p_data);
}

int HS_msg_host_to_hw_UART_notFull (bool *p_notFull)
{
    return HS_msg_host_to_hw_chan_notFull (HS_MSG_HOST_TO_HW_CHAN_UART, p_notFull);
}

int HS_msg_host_to_hw_UART_data (uint32_t data)
{
    return HS_msg_host_to_hw_chan_data (HS_MSG_HOST_TO_HW_CHAN_UART, data);
}

// ================================================================
// Debug Module channel

int HS_msg_hw_to_host_DEBUG_MODULE_notEmpty (bool *p_notEmpty)
{
    return HS_msg_hw_to_host_chan_notEmpty (HS_MSG_HW_TO_HOST_CHAN_DEBUG_MODULE, p_notEmpty);
}

int HS_msg_hw_to_host_DEBUG_MODULE_data (uint32_t *p_data)
{
    return HS_msg_hw_to_host_chan_data (HS_MSG_HW_TO_HOST_CHAN_DEBUG_MODULE, p_data);
}

int HS_msg_host_to_hw_DEBUG_MODULE_notFull (bool *p_notFull)
{
    return HS_msg_host_to_hw_chan_notFull (HS_MSG_HOST_TO_HW_CHAN_DEBUG_MODULE, p_notFull);
}

int HS_msg_host_to_hw_DEBUG_MODULE_data (uint32_t data)
{
    return HS_msg_host_to_hw_chan_data (HS_MSG_HOST_TO_HW_CHAN_DEBUG_MODULE, data);
}

// ================================================================
// Virtio MMIO read/write

int HS_msg_hw_to_host_VIRTIO_MMIO_REQ_notEmpty (bool *p_notEmpty)
{
    return HS_msg_hw_to_host_chan_notEmpty (HS_MSG_HW_TO_HOST_CHAN_VIRTIO_MMIO_REQ, p_notEmpty);
}

int HS_msg_hw_to_host_VIRTIO_MMIO_REQ_data (uint32_t *p_data)
{
    return HS_msg_hw_to_host_chan_data (HS_MSG_HW_TO_HOST_CHAN_VIRTIO_MMIO_REQ, p_data);
}

int HS_msg_host_to_hw_VIRTIO_MMIO_RSP_notFull (bool *p_notFull)
{
    return HS_msg_host_to_hw_chan_notFull (HS_MSG_HOST_TO_HW_CHAN_VIRTIO_MMIO_RSP, p_notFull);
}

int HS_msg_host_to_hw_VIRTIO_MMIO_RSP_data (uint32_t data)
{
    return HS_msg_host_to_hw_chan_data (HS_MSG_HOST_TO_HW_CHAN_VIRTIO_MMIO_RSP, data);
}

// ================================================================
// VIRTIO Interrupt

int HS_msg_host_to_hw_VIRTIO_IRQ_notFull (bool *p_notFull)
{
    return HS_msg_host_to_hw_chan_notFull (HS_MSG_HOST_TO_HW_CHAN_VIRTIO_IRQ, p_notFull);
}

int HS_msg_host_to_hw_VIRTIO_IRQ_data (uint32_t data)
{
    return HS_msg_host_to_hw_chan_data (HS_MSG_HOST_TO_HW_CHAN_VIRTIO_IRQ, data);
}

// ================================================================
