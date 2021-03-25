// Copyright (c) 2020-2021 Bluespec, Inc.  All Rights Reserved
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

#ifdef IN_F1
#include "fpga_pci.h"
#include "fpga_mgmt.h"
#include "fpga_dma.h"
#include "utils/lcd.h"
#endif

#ifdef IN_SIMULATION
// Simulation library replacing AWS' actual FPGA interaction library
// AWS_Sim_Lib simulates the fpga peek, poke, dma_read and dma_write calls provided by AWS.
#include "AWS_Sim_Lib.h"
#endif

#include "HS_msg.h"

// ================================================================
// Verbosity for this module

static int verbosity = 0;

// ================================================================
// PCI variables

extern int pci_read_fd;
extern int pci_write_fd;

// ================================================================
// Perform initializations for PCI lib or AWS_Sim_Lib

int HS_msg_initialize (void)
{
#ifdef IN_F1
    int rc;

    // ----------------
    // Initialize FPGA management library
    rc = fpga_mgmt_init ();    // Note: calls fpga_pci_init ();
    if (rc != 0) {
	fprintf (stdout, "%s: fpga_mgmt_init() failed: rc = %0d\n", __FUNCTION__, rc);
	return 1;
    }
    fprintf (stdout, "%s: fpga_mgmt_init() done\n", __FUNCTION__);

    // ----------------
    // Open file descriptor for DMA read over AXI4
    pci_read_fd = fpga_dma_open_queue (FPGA_DMA_XDMA,
				       pci_slot_id,
				       0,        // channel
				       true);    // is_read
    if (pci_read_fd < 0) {
	fprintf (stdout, "ERROR: %s: unable to open read-dma queue\n", __FUNCTION__);
	return 1;
    }
    fprintf (stdout, "ERROR: %s: opened PCI read-dma queue\n", __FUNCTION__);

    // ----------------
    // Open file descriptor for DMA write over AXI4
    pci_write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA,
				       pci_slot_id,
				       0,         // channel
				       false);    // is_read
    if (pci_write_fd < 0) {
	fprintf (stdout, "ERROR: %s: unable to open write-dma queue\n", __FUNCTION__);
	return 1;
    }


    int fpga_pci_attach_flags = 0;

    rc = fpga_pci_attach (pci_slot_id, pci_pf_id, pci_bar_id, fpga_pci_attach_flags, & pci_bar_handle);
    if (rc != 0) {
	fprintf (stdout, "%s: fpga_pci_init() failed: rc = %0d\n", __FUNCTION__, rc);
	return 1;
    }
#endif

#ifdef IN_SIMULATION
    AWS_Sim_Lib_init ();
#endif

    return 0;
}

// ================================================================
// Perform finalizations for PCI lib or AWS_Sim_Lib

int HS_msg_finalize (void)
{
#ifdef IN_F1
    int rc;

    rc = fpga_pci_detach (pci_bar_handle);
    if (rc != 0) {
	fprintf (stdout, "main: fpga_pci_detach() failed: rc = %0d\n", rc);
	return 1;
    }
#endif

#ifdef IN_SIMULATION
    AWS_Sim_Lib_shutdown ();
#endif

    return 0;
}

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

    int err = fpga_pci_peek (pci_bar_handle, ocl_addr, & avail);
    if (err == 0) {
	*p_notEmpty = (avail != 0);
	if (verbosity != 0)
	    fprintf (stdout, "%s (chan_id %0x) => %0d\n", __FUNCTION__, chan_id, *p_notEmpty);
    }
    else {
	if (verbosity != 0)
	    fprintf (stdout, "%s (chan_id %0x) => ERROR\n", __FUNCTION__, chan_id);
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

    int err = fpga_pci_peek (pci_bar_handle, ocl_addr, p_data);
    if (err == 0) {
	if (verbosity != 0)
	    fprintf (stdout, "%s (chan_id %0x) => %0d\n", __FUNCTION__, chan_id, *p_data);
    }
    else {
	if (verbosity != 0)
	    fprintf (stdout, "%s (chan_id %0x) => ERROR\n", __FUNCTION__, chan_id);
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

    int err = fpga_pci_peek (pci_bar_handle, ocl_addr, & avail);
    if (err == 0) {
	*p_notFull = (avail != 0);
	if (verbosity != 0)
	    fprintf (stdout, "%s (chan_id 0x%0x) => %0d\n", __FUNCTION__, chan_id, *p_notFull);
    }
    else {
	if (verbosity != 0)
	    fprintf (stdout, "%s (chan_id 0x%0x) => ERROR\n", __FUNCTION__, chan_id);
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

    int err = fpga_pci_poke (pci_bar_handle, ocl_addr, data);
    if (err == 0) {
	if (verbosity != 0)
	    fprintf (stdout, "%s (chan_id 0x%0x, data 0x%0x)\n",
		     __FUNCTION__, chan_id, data);
    }
    else {
	if (verbosity != 0)
	    fprintf (stdout, "%s (chan_id 0x%0x, data 0x%0x) => ERROR\n",
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
// PC Trace channel

int HS_msg_hw_to_host_PC_TRACE_notEmpty (bool *p_notEmpty)
{
    return HS_msg_hw_to_host_chan_notEmpty (HS_MSG_HW_TO_HOST_CHAN_PC_TRACE, p_notEmpty);
}

int HS_msg_hw_to_host_PC_TRACE_data (uint32_t *p_data)
{
    return HS_msg_hw_to_host_chan_data (HS_MSG_HW_TO_HOST_CHAN_PC_TRACE, p_data);
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
