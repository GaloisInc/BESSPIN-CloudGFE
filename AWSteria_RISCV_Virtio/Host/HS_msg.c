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
#include <assert.h>

// ----------------
// Project includes

#include "AWSteria_Host_lib.h"
#include "accelize/drmc.h"


#include "HS_msg.h"

// ================================================================

static bool initialized = false;

// ================================================================
// Verbosity for this module

static int verbosity     = 0;
static int verbosity_get = 0;
static int verbosity_put = 0;

// ================================================================
// PCI variables for Amazon AWS F1 platform
// TODO: this should move to AWteria_Infra/Platform_VCU118/Host/AWSteria_Host_lib.c

#ifdef IN_F1
extern int pci_read_fd;
extern int pci_write_fd;
#endif


// Define functions to read and write FPGA registers to use them as
// callbacks in DrmManager.
#define drm_controller_base_addr 0x100000
void *comms_state = NULL;


int read_register( uint32_t offset, uint32_t* value, void* user_p ) {
  return  AWSteria_AXI4L_read (comms_state, drm_controller_base_addr + offset, value);
}

int write_register( uint32_t offset, uint32_t value, void* user_p ) {

  return  AWSteria_AXI4L_write (comms_state, drm_controller_base_addr + offset, value);

}
// Define asynchronous error callback
void asynch_error( const char* err_msg, void* user_p ) {
    fprintf( stderr, "%s", err_msg );
}

 DrmManager* drm_manager = NULL;

// ================================================================
// Perform initializations for PCI lib or AWS_Sim_Lib

void *HS_msg_initialize (void)
{

#ifdef IN_F1
    int rc;

    // TODO: this should move to AWteria_Infra/Platform_VCU118/Host/AWSteria_Host_lib.c
    // ----------------
    // Initialize FPGA management library
    rc = fpga_mgmt_init ();    // Note: calls fpga_pci_init ();
    if (rc != 0) {
	fprintf (stdout, "ERROR: %s: fpga_mgmt_init()=> rc = %0d\n",
		 __FUNCTION__, rc);
	return NULL;
    }
    fprintf (stdout, "%s: fpga_mgmt_init() done\n", __FUNCTION__);
    fprintf (stdout, "    pci_slot_id = %0d\n", pci_slot_id);

    // ----------------
    // Open file descriptor for DMA read over AXI4
    pci_read_fd = fpga_dma_open_queue (FPGA_DMA_XDMA,
				       pci_slot_id,
				       0,        // channel
				       true);    // is_read
    if (pci_read_fd < 0) {
	fprintf (stdout, "ERROR: %s: fpga_dma_open_queue (read)=> err\n",
		 __FUNCTION__);
	return NULL;
    }
    fprintf (stdout, "%s: opened PCI read-dma queue; pci_read_fd = %0d\n",
	     __FUNCTION__, pci_read_fd);

    // ----------------
    // Open file descriptor for DMA write over AXI4
    pci_write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA,
				       pci_slot_id,
				       0,         // channel
				       false);    // is_read
    if (pci_write_fd < 0) {
	fprintf (stdout, "ERROR: %s: fpga_dma_open_queue (write)=> err\n",
		 __FUNCTION__);
	return NULL;
    }
    fprintf (stdout, "%s: opened PCI write-dma queue; pci_write_fd = %0d\n",
	     __FUNCTION__, pci_write_fd);

    // ----------------
    // pci_attach for AXI4L

    int fpga_pci_attach_flags = 0;

    rc = fpga_pci_attach (pci_slot_id, pci_pf_id, pci_bar_id, fpga_pci_attach_flags,
			  & pci_bar_handle);
    if (rc != 0) {
	fprintf (stdout, "    FAILED: rc = %0d\n", rc);
	return NULL;
    }
    fprintf (stdout, "%s: fpga_pci_attach (pci_slot_id %0d, pci_pf_id %0d, pci_bar_id %0d\n",
	     __FUNCTION__, pci_slot_id, pci_pf_id, pci_bar_id);
    fprintf (stdout, "     => pci_bar_handle %0d\n", pci_bar_handle);
#endif

    // ----------------------------------------------------------------
    // Initialize AWSteria host-side API libs

    if (verbosity > 0)
	fprintf (stdout, "Initializing AWSteria host-side API libs.\n");
    comms_state = AWSteria_Host_init ();
    if (comms_state == NULL)
	return NULL;

    // Instantiate DrmManager with previously defined functions and
    // configuration files

     DrmManager* drm_manager = NULL;
    int ctx = 0;

    if (DrmManager_alloc(


        &drm_manager,
        // Configuration files paths
        "./conf.json",
        "./cred.json",
        // Read/write register functions callbacks
        read_register,
        write_register,
        // Asynchronous error callback
        asynch_error,
        &ctx))
        {
        // In the C case, the last error message is stored inside the
        // "DrmManager"
        fprintf( stderr, "%s", drm_manager->error_message );
        } 

    if ( DrmManager_activate( drm_manager, false ) )
    fprintf( stderr, "%s", drm_manager->error_message );
    else
    fprintf (stdout, "DRM_activation_done\n");

    initialized = true;
    return comms_state;
}

// ================================================================
// Perform finalizations for PCI lib or AWS_Sim_Lib

int HS_msg_finalize (void *opaque)
{
    if (! initialized) {
	fprintf (stdout, "ERROR: %s: no HS_msg_initialize () before this.\n",
		 __FUNCTION__);
	return -1;
    }

    int err;

// DRM deactivate and free    
    if ( DrmManager_deactivate( drm_manager, false ) )
    fprintf( stderr, "%s", drm_manager->error_message );
    if ( DrmManager_free( &drm_manager ) )
    fprintf( stderr, "%s", drm_manager->error_message );


#ifdef IN_F1
    // TODO: this should move to AWteria_Infra/Platform_VCU118/Host/AWSteria_Host_lib.c
    err = fpga_pci_detach (pci_bar_handle);
    if (err != 0) {
	fprintf (stdout, "ERROR: %s: fpga_pci_detach ()=> err %0d\n",
		 __FUNCTION__, err);
	goto done;
    }
#endif

    err = AWSteria_Host_shutdown (opaque);
    if (err != 0) {
	fprintf (stdout, "ERROR: %s: AWSteria_Host_shutdown ()=> err %0d\n",
		 __FUNCTION__, err);
	goto done;
    }

 done:
    initialized = false;
    return err;
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
// HW-to-host channel functions

// ----------------
// Test a hw-to-host channel's availability
//     Function result is 0 if ok, 1 if error.
//     If ok, result is '*p_notEmpty'

static
int HS_msg_hw_to_host_chan_notEmpty (void *comms_state, uint32_t chan_id, bool *p_notEmpty)
{
    uint32_t  ocl_addr = mk_chan_avail_addr (HS_MSG_HW_TO_HOST_CHAN_ADDR_BASE, chan_id);
    uint32_t  avail;

    int err = AWSteria_AXI4L_read (comms_state, ocl_addr, & avail);
    if (err == 0) {
	*p_notEmpty = (avail != 0);
    }
    else {
	*p_notEmpty = 0;
	if (verbosity != 0)
	    fprintf (stdout, "ERROR: %s AXI4L_read (chan 0x%0x addr 0x%0x)=> err %0d\n",
		     __FUNCTION__, chan_id, ocl_addr, err);
    }
    return err;
}

// ----------------
// Read (dequeue) a hw-to-host channel's data.
//     Function result is 0 if ok, 1 if error.
//     If ok, result is '*p_data'
//        Contains data if channel has data,
//        undefined otherwise (use above 'notEmpty' function first to check if chan has data)

static
int HS_msg_hw_to_host_chan_data (void *comms_state, uint32_t chan_id, uint32_t *p_data)
{
    uint32_t  ocl_addr = mk_chan_data_addr (HS_MSG_HW_TO_HOST_CHAN_ADDR_BASE, chan_id);

    int err = AWSteria_AXI4L_read (comms_state, ocl_addr, p_data);
    if (err != 0) {
	if (verbosity != 0)
	    fprintf (stdout, "ERROR: %s: AXI4L_read (chan 0x%0x addr 0x%0x)=> err %0d\n",
		     __FUNCTION__, chan_id, ocl_addr, err);
    }
    return err;
}

// ----------------
// Get, blocking (wait for avail, then get data, i.e., blocking)

#define MAX_NOTEMPTY_POLLS 1000

int HS_msg_hw_to_host_chan_get (void *comms_state, uint32_t chan_id, uint32_t *p_data)
{
    if (! initialized) return -1;

    if (verbosity_get > 0) {
	fprintf (stdout, "--> %s (chan %0d) ...\n",
		 __FUNCTION__, chan_id);
    }

    int      err;
    bool     notEmpty;
    uint32_t num_polls = 0;

    while (true) {
	num_polls++;
	err = HS_msg_hw_to_host_chan_notEmpty (comms_state, chan_id, & notEmpty);
	if (err != 0) goto done;
	if (notEmpty) break;
	if (num_polls >= MAX_NOTEMPTY_POLLS) {
	    fprintf (stdout, "ERROR: %s (chan %0d): reached poll limit %0d\n",
		     __FUNCTION__, chan_id, MAX_NOTEMPTY_POLLS);
	    err = -1;
	    goto done;
	}
	if ((num_polls % 100) == 0)
	    fprintf (stdout, "%s (chan %0d): num_polls = %0d\n",
		     __FUNCTION__, chan_id, num_polls);
    }
    err = HS_msg_hw_to_host_chan_data (comms_state, chan_id, p_data);
    if (err == 0) {
	if (verbosity_get != 0)
	    fprintf (stdout, "%s (chan 0x%0x) => 0x%0x\n",
		     __FUNCTION__, chan_id, *p_data);
    }

 done:
    if (verbosity_get > 0) {
	fprintf (stdout, "<-- %s (chan %0d)=> err %0d data 0x%0x\n",
		 __FUNCTION__, chan_id, err, *p_data);
    }
    return err;
}

// ----------------
// Get, non-blocking (get data if avail)
// Return 0 if no error, non-zero if error
// Return *p_valid = true if got data

int HS_msg_hw_to_host_chan_get_nb (void *comms_state, uint32_t chan_id,
				   uint32_t *p_data, bool *p_valid)
{
    if (! initialized) return -1;

    if (verbosity_get > 0)
	fprintf (stdout, "--> %s (chan %0d) ...\n",
		 __FUNCTION__, chan_id);

    int  err;
    bool notEmpty;

    *p_valid = false;

    err = HS_msg_hw_to_host_chan_notEmpty (comms_state, chan_id, & notEmpty);
    if (err != 0) goto done;
    if (! notEmpty) goto done;

    err = HS_msg_hw_to_host_chan_data (comms_state, chan_id, p_data);
    if (err == 0)
	*p_valid = true;

 done:
    if (verbosity_get > 0) {
	fprintf (stdout, "<-- %s (chan %0d)=> err %0d data 0x%0x valid %0d\n",
		 __FUNCTION__, chan_id, err, *p_data, *p_valid);
    }
    return err;
}

// ================================================================
// HW-to-host channel functions

// ----------------
// Test a host-to-hw channel's availability.
//     Function result is 0 if ok, 1 if error.
//     If ok, result is '*p_notFull'

static
int HS_msg_host_to_hw_chan_notFull (void *comms_state, uint32_t chan_id, bool *p_notFull)
{
    uint32_t  ocl_addr = mk_chan_avail_addr (HS_MSG_HOST_TO_HW_CHAN_ADDR_BASE, chan_id);
    uint32_t  avail;

    int err = AWSteria_AXI4L_read (comms_state, ocl_addr, & avail);
    if (err == 0) {
	*p_notFull = (avail != 0);
    }
    else {
	*p_notFull = 0;
	if (verbosity != 0)
	    fprintf (stdout, "ERROR: %s: AXI4L_read (chan 0x%0x addr 0x%0x)=> err %0d\n",
		     __FUNCTION__, chan_id, ocl_addr, err);
    }
    return err;
}

// ----------------
// Write (enqueue) a host-to-hw channel's data.
//     Function result is 0 if ok, 1 if error.
//     If channel is full, data is discarded
//        (use above 'notFull' function first to check if chan is notFull)

static
int HS_msg_host_to_hw_chan_data (void *comms_state, uint32_t chan_id, uint32_t data)
{
    uint32_t  ocl_addr = mk_chan_data_addr (HS_MSG_HOST_TO_HW_CHAN_ADDR_BASE, chan_id);

    int err = AWSteria_AXI4L_write (comms_state, ocl_addr, data);
    if (err != 0) {
	if (verbosity != 0)
	    fprintf (stdout, "ERROR: %s: AXI4L_write (chan 0x%0x addr 0x%0x data 0x%0x)=>err %0d\n",
		     __FUNCTION__, chan_id, ocl_addr, data, err);
    }
    return err;
}

// ----------------
// Put, blocking (wait for chan avail, then put data)
// Return 0 if no err, non-zero of err

#define MAX_NOTFULL_POLLS 1000

int HS_msg_host_to_hw_chan_put (void *comms_state, uint32_t chan_id, uint32_t data)
{
    if (! initialized) return -1;

    if (verbosity_put > 0) {
	fprintf (stdout, "--> %s (chan %0d data 0x%0x)\n",
		 __FUNCTION__, chan_id, data);
    }

    int      err;
    bool     notFull;
    uint32_t num_polls = 0;

    while (true) {
	num_polls++;
	err = HS_msg_host_to_hw_chan_notFull (comms_state, chan_id, & notFull);
	if (err != 0) goto done;
	if (notFull) break;
	if (num_polls >= MAX_NOTFULL_POLLS) {
	    fprintf (stdout, "ERROR: %s (chan %0d data 0x%0x): reached poll limit %0d\n",
		     __FUNCTION__, chan_id, data, MAX_NOTFULL_POLLS);
	    err = -1;
	    goto done;
	}
	if ((num_polls % 100) == 0)
	    fprintf (stdout, "%s (chan %0d data 0x%0x): num_polls = %0d\n",
		     __FUNCTION__, chan_id, data, num_polls);
    }
    err = HS_msg_host_to_hw_chan_data (comms_state, chan_id, data);

 done:
    if (verbosity_put > 0) {
	fprintf (stdout, "<-- %s (chan %0d data 0x%0x)=> err %0d\n",
		 __FUNCTION__, chan_id, data, err);
    }
    return err;
}

// ----------------
// Put, non-blocking (write data if chan avail)
// Return 0 if no err, non-zero of err
// If no error, *p_valid = true if write succeeded

int HS_msg_host_to_hw_chan_put_nb (void *comms_state, uint32_t chan_id,
				   uint32_t data, bool *p_valid)
{
    if (! initialized) return -1;

    if (verbosity_put > 0) {
	fprintf (stdout, "--> %s (chan %0d data 0x%0x)\n",
		 __FUNCTION__, chan_id, data);
    }

    *p_valid = false;
    int  err;
    bool notFull;

    err = HS_msg_host_to_hw_chan_notFull (comms_state, chan_id, & notFull);
    if (err != 0) goto done;
    if (! notFull) goto done;

    err = HS_msg_host_to_hw_chan_data (comms_state, chan_id, data);
    if (err == 0) {
	*p_valid = true;
    }

 done:
    if (verbosity_put > 0) {
	fprintf (stdout, "<-- %s (chan %0d data 0x%0x)=> err %0d valid %0d\n",
		 __FUNCTION__, chan_id, data, err, *p_valid);
    }
    return err;
}

// ================================================================
