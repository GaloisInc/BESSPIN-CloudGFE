// Copyright (c) 2020-2021 Bluespec, Inc.  All Rights Reserved
// Author: Rishiyur S. Nikhil
// (with some functionality taken from AWS Connectal-style)

// This module encapsulates virtio

// Context: A system containing two primary parts:
// - HW-side: e.g., a CPU/SoC model (e.g., Flute + WindSoC or GFESoC)
//       running in actual hardware or in simulation.
// - Host-side: C/C++ program(s) providing services for the HW side, such as
//       - run control and status
//       - terminal console
//       - optional GDB connection to Debug Module in the HW
//       - optional recording of Tandem-Verification traces
//       - Emulation of devices using Virtio
//
// The code in this file is the entry point for "Host-side Emulation of Devices using Virtio".
//
// Actual device emulation is done by code in TinyEMU:
//     https://bellard.org/tinyemu/tinyemu-2019-12-21.tar.gz
//     (Fabrice Bellard is the creator of TinyEmu)
// The code in this file primarily an interface to TinyEmu code.

// ================================================================
// This define-macro is needed to avoid this compiler warning:
//   warning: implicit declaration of function ‘pthread_setname_np’

#define _GNU_SOURCE

// ================================================================
// C lib includes

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <inttypes.h>
#include <string.h>
#include <stdbool.h>
#include <ctype.h>
#include <pthread.h>
#include <unistd.h>
#include <assert.h>

// ----------------
// For XSIM only

#ifdef AWS_XSIM
# include <fpga_pci_sv.h>
#endif

// ----------------
// Virtio/TinyEmu code includes

#include "virtio.h"
#include "temu.h"

// ----------------
// Project includes

#include "HS_msg.h"
#include "HS_virtio.h"

// ================================================================
// Choose which virtio devices we're supporting

#define INCLUDE_VIRTIO_BLOCK_DEVICE
#define INCLUDE_VIRTIO_NETWORK_DEVICE
#define INCLUDE_VIRTIO_ENTROPY_DEVICE
// #define INCLUDE_VIRTIO_CONSOLE_DEVICE

// ================================================================

extern int pci_read_fd;
extern int pci_write_fd;

pthread_t  io_thread;

FILE *f_debug_virtio = NULL;

static int verbosity = 0;

static int debug_stray_io = 1;

// ================================================================
// These two functions are called by the Virtio console device driver
// to actually perform the console character read/write.
// Note: this is NOT the direct UART device on the HW side;
//     this is the virtio emulation of a console.
//     Both can co-exist.
// TODO: can be improved substantially.

#ifdef INCLUDE_VIRTIO_CONSOLE_DEVICE
static
void console_write_data (void *opaque, const uint8_t *buf, int buf_len)
{
    fwrite(buf, 1, buf_len, stdout);
    fflush(stdout);
}

static
int console_read_data (void *opaque, uint8_t *buf, int len)
{
    int ret = read((int)(intptr_t)opaque, buf, len);
    if (ret < 0)
        return 0;

    return ret;
}
#endif

// ================================================================
// This function performs the IO work for incoming data (network, console)

static
void io_thread_do_some_work (HS_Virtio_State *state)
{

#if defined(INCLUDE_VIRTIO_NETWORK_DEVICE) || defined(INCLUDE_VIRTIO_BLOCK_DEVICE) || defined(INCLUDE_VIRTIO_ENTROPY_DEVICE) || defined(INCLUDE_VIRTIO_CONSOLE_DEVICE)
    VirtioDevices *vds = state->virtiodevices;
    int fd_max = -1;
#endif

    fd_set rfds, wfds, efds;

    FD_ZERO(&rfds);
    FD_ZERO(&wfds);
    FD_ZERO(&efds);

    // int stop_fd = vds->stop_pipe[0];  // TODO: stop 'device'
    // FD_SET(stop_fd, &rfds);
    // fd_max = stop_fd;

#ifdef INCLUDE_VIRTIO_CONSOLE_DEVICE
    // Polling for console keyboard input
    int stdin_fd;
    if (vds->virtio_console && virtio_console_can_write_data(vds->virtio_console)) {
	stdin_fd = (int)(intptr_t)vds->console->opaque;
	FD_SET(stdin_fd, &rfds);
	fd_max = max2(stdin_fd, fd_max);
    }
#endif

#ifdef INCLUDE_VIRTIO_NETWORK_DEVICE
    // Polling for incoming ethernet packet

    struct timeval  tv;
    int             delay = 10; // ms                // TODO: change this?

    if (vds->ethernet_device) {
	vds->ethernet_device->select_fill (vds->ethernet_device,
					   & fd_max, & rfds, & wfds, & efds, & delay);
    }


    tv.tv_sec = delay / 1000;
    tv.tv_usec = (delay % 1000) * 1000;
    int ret = select(fd_max + 1, &rfds, &wfds, &efds, &tv);

    if (vds->ethernet_device) {
	vds->ethernet_device->select_poll (vds->ethernet_device,
					   & rfds, & wfds, & efds, ret);
    }
#endif

    /*
    // Poll for stop-device
    if (FD_ISSET(stop_fd, &rfds)) {
	close(stop_fd);
	return;
    }
    */

#ifdef INCLUDE_VIRTIO_CONSOLE_DEVICE
    if (vds->virtio_console && FD_ISSET(stdin_fd, &rfds)) {
	uint8_t buf[128];
	int ret, len;
	len = virtio_console_get_write_len (vds->virtio_console);
	len = min_int(len, sizeof(buf));
	ret = vds->console->read_data(vds->console->opaque, buf, len);
	if (ret > 0) {
	    virtio_console_write_data(vds->virtio_console, buf, ret);
	}
    }
#endif
}

static
void *io_thread_worker (void *opaque)
{
    HS_Virtio_State *state = (HS_Virtio_State *) opaque;
    while (true)
	io_thread_do_some_work (state);
    return NULL;
}

// ================================================================

static
void HS_virtio_fn_set_irq (void *opaque, int irq_num, int level)
{
    assert (opaque != NULL);
    HS_Virtio_State *p_state = opaque;

    if ((f_debug_virtio != NULL) && (verbosity > 0))
	fprintf (f_debug_virtio, "%s: irq_num=%d  level=%d\n",
		 __FUNCTION__, irq_num, level);

    if ((irq_num < 0) || (31 < irq_num)) {
	fprintf (f_debug_virtio, "ERROR: %s: irq_num (%0d) is not in range 0..31\n",
		 __FUNCTION__, irq_num);
    }

    // data [31] = 1 for set, 0 for clear; data [4:0] = irq_num
    uint32_t data = irq_num;
    if (level)
	data = (1 << 31) | data;

    int err = HS_msg_host_to_hw_chan_put (p_state->comms_state,
					  HS_MSG_HOST_TO_HW_CHAN_VIRTIO_IRQ,
					  data);
    if (err != 0) {
	fprintf (stdout, "ERROR: %s: err = %0d\n", __FUNCTION__, err);
    }
}

HS_Virtio_State *HS_virtio_init (void *comms_state,
				 const char *tun_iface,
				 const int   enable_virtio_console,
				 const int   xdma_enabled,
				 const char *block_files [],
				 const int   num_block_files)
{
    // ================================================================
    // Set up XDMA
    // Corresponds to this in Connectal:
    //     if (xdma_enabled) fpga->open_xdma();

    virtio_xdma_init (comms_state);

    // ================================================================
    // Allocate and initialize HS_Virtio_State object

    HS_Virtio_State *state = (HS_Virtio_State *) malloc (sizeof (HS_Virtio_State));
    if (state == NULL) {
	fprintf (stdout, "ERROR: %s: malloc failed\n", __FUNCTION__);
	exit (1);
    }

    // ================================================================

    VirtioDevices *vds = NULL;
    VIRTIODevice *device_arr[4];
    int           n_devices = 0;

    if (verbosity > 0)
	fprintf (stdout, "%s: Initializing virtio devices\n", __FUNCTION__);

    // Allocate and initialize VirtioDevices object
    vds = (VirtioDevices *) malloc (sizeof (VirtioDevices));
    if (vds == NULL) {
	fprintf (stdout, "ERROR: %s: malloc failed\n", __FUNCTION__);
	exit (1);
    }
    vds->virtio_console = NULL;
    vds->virtio_block   = NULL;
    vds->virtio_net     = NULL;
    vds->virtio_entropy = NULL;
    vds->tun_ifname     = tun_iface;

    vds->mem_map = phys_mem_map_init();

    vds->irq     = (IRQSignal *)mallocz(32 * sizeof(IRQSignal));
    vds->irq_num = FIRST_VIRTIO_IRQ;

    vds->virtio_bus = (VIRTIOBusDef *)mallocz(sizeof(VIRTIOBusDef));
    vds->virtio_bus->mem_map = vds->mem_map;
    vds->virtio_bus->addr    = 0x40000000;

    for (int i = 0; i < 32; i++) {
        irq_init (& (vds->irq[i]), HS_virtio_fn_set_irq, (void *) state, i);
    }

    // ----------------------------------------------------------------
    // Set up a block device for each given block device filename

#ifdef INCLUDE_VIRTIO_BLOCK_DEVICE
    if (num_block_files == 0) {
	if (verbosity > 0)
	    fprintf (stdout, "    No virtio block device\n");
    }
    else {
	for (int j = 0; j < num_block_files; j++) {
	    if (verbosity > 0)
		fprintf (stdout, "    Initializing virtio block device [%0d] on file '%s'\n",
			 j, block_files [j]);
	    vds->virtio_bus->irq   = & (vds->irq [vds->irq_num++]);
	    vds->block_device = block_device_init (block_files [j], BF_MODE_RW);
	    vds->virtio_block = virtio_block_init (vds->virtio_bus, vds->block_device);
	    if (verbosity > 0)
		fprintf (stdout, "        virtio block device at bus addr %0lx, irq %0d\n",
			 vds->virtio_bus->addr, vds->irq_num - 1);
	    if (f_debug_virtio != NULL) {
	        virtio_set_debug (vds->virtio_block, 1);
	    }

	    vds->virtio_bus->addr += 0x1000;
	}
	device_arr [n_devices++] = vds->virtio_block;
    }
#else
    if (verbosity > 0)
	fprintf (stdout, "    No virtio block device\n");
#endif

    // ----------------------------------------------------------------
    // set up a network device

#ifdef INCLUDE_VIRTIO_NETWORK_DEVICE
    if (verbosity > 0) {
	fprintf (stdout, "    Initializing virtio net device: ");
	if (tun_iface != NULL)
	    fprintf (stdout, "tun '%s'\n", tun_iface);
	else
	    fprintf (stdout, "slirp\n");
    }
    vds->virtio_bus->irq = & (vds->irq [vds->irq_num++]);
    vds->ethernet_device = vds->tun_ifname ? tun_open(vds->tun_ifname) : slirp_open();
    vds->virtio_net = virtio_net_init (vds->virtio_bus, vds->ethernet_device);
    if (verbosity > 0)
	fprintf (stdout, "        virtio net device at bus addr %0lx irq %0d\n",
		 vds->virtio_bus->addr, vds->irq_num - 1);
    if (f_debug_virtio != NULL) {
        virtio_set_debug (vds->virtio_net, 1);
    }

    vds->virtio_bus->addr += 0x1000;

    device_arr [n_devices++] = vds->virtio_net;
#else
    if (verbosity > 0)
	fprintf (stdout, "    No virtio network device\n");
#endif

    // ----------------------------------------------------------------
    // set up an entropy device

#ifdef INCLUDE_VIRTIO_ENTROPY_DEVICE
    if (verbosity > 0)
	fprintf (stdout, "    Initializing virtio entropy device\n");
    vds->virtio_bus->irq = & (vds->irq [vds->irq_num++]);
    vds->virtio_entropy = virtio_entropy_init(vds->virtio_bus);
    if (verbosity > 0)
	fprintf (stdout, "        virtio entropy device bus addr %0lx, irq %0d\n",
		 vds->virtio_bus->addr, vds->irq_num - 1);
    if (f_debug_virtio != NULL) {
        virtio_set_debug (vds->virtio_entropy, 1);
    }

    vds->virtio_bus->addr += 0x1000;

    device_arr [n_devices++] = vds->virtio_entropy;
#else
    if (verbosity > 0)
	fprintf (stdout, "    No virtio entropy device\n");
#endif

    // ----------------------------------------------------------------
    // Set up a virtio console device

#ifdef INCLUDE_VIRTIO_CONSOLE_DEVICE
    if (enable_virtio_console == 0) {
	if (verbosity > 0)
	    fprintf (stdout, "    No virtio console device\n");
    }
    else {
	if (verbosity > 0)
	    fprintf (stdout, "    Initializing virtio console device\n");
	vds->console = (CharacterDevice *) malloc (sizeof (CharacterDevice));
	vds->console->opaque = (void *)(intptr_t)-1;
	vds->console->read_data = console_read_data;
	vds->console->write_data = console_write_data;

	vds->virtio_bus->irq   = & (vds->irq [vds->irq_num++]);
	vds->virtio_console = virtio_console_init (vds->virtio_bus, vds->console);

	if (verbosity > 0)
	    fprintf (stdout, "        virtio console device at bus addr %0lx irq %0d\n",
		     vds->virtio_bus->addr, vds->irq_num - 1);

	vds->virtio_bus->addr += 0x1000;

	device_arr [n_devices++] = vds->virtio_console;
    }
#else
    if (verbosity > 0)
	fprintf (stdout, "    No virtio console device\n");
#endif

    // ================================================================

    state->virtiodevices = vds;
    state->comms_state   = comms_state;

    // ================================================================
    // Start service threads

    if (verbosity > 0)
	fprintf (stdout, "%s: starting thread for queue_notify() service.\n",
		 __FUNCTION__);
    virtio_start_pending_notify_thread(n_devices, device_arr);

    if (verbosity > 0)
	fprintf (stdout, "%s: starting thread for IO (servicing incoming network, console etc).\n",
		 __FUNCTION__);
    pthread_create(&io_thread, NULL, &io_thread_worker, state);
    pthread_setname_np(io_thread, "VirtIO I/O");

    return state;
}

// ================================================================
// MMIO reads and writes from guest

// ----------------
// MMIO reads from guest
// Returns value read from MMIO control register array.

static
uint32_t HS_virtio_MMIO_read (VirtioDevices *vds, uint32_t addr)
{
    uint32_t result = 0;

    PhysMemoryRange *pr = get_phys_mem_range (vds->mem_map, addr);
    if (pr) {
        uint32_t offset    = addr - pr->addr;
        int      size_log2 = 2;
	result = pr->read_func (pr->opaque, offset, size_log2);
	if ((f_debug_virtio != NULL) && (verbosity > 0))
	  fprintf (f_debug_virtio, "%s: addr %0x => 0x%08x\n", __FUNCTION__, addr, result);
    }
    else {
        if (debug_stray_io && (f_debug_virtio != NULL))
	    fprintf (f_debug_virtio, "%s: ERROR: UNKNOWN ADDR %0x\n", __FUNCTION__, addr);
    }
    return result;
}

// ----------------
// MMIO writes from quest

static
uint32_t HS_virtio_MMIO_write (VirtioDevices *vds, uint32_t addr, uint32_t data)
{
    if ((f_debug_virtio != NULL) && (verbosity > 0))
	fprintf (f_debug_virtio, "%s: addr %0x <= %0x\n", __FUNCTION__, addr, data);

    uint32_t result = 0;

    PhysMemoryRange *pr = get_phys_mem_range (vds->mem_map, addr);

    if (pr) {
        uint32_t offset    = addr - pr->addr;
        int      size_log2 = 2;
        pr->write_func (pr->opaque, offset, data, size_log2);
    }
    else {
        if (debug_stray_io && (f_debug_virtio != NULL))
	    fprintf (f_debug_virtio, "%s: ERROR: UNKNOWN ADDR %0x data %0x\n", __FUNCTION__, addr, data);
	result = 1;
    }
    return result;
}

// ================================================================
// Move Virtio MMIO transactions

bool HS_virtio_do_some_work_A (void *comms_state, HS_Virtio_State *state)
{
    bool did_some_work = false;

    int      err;
    bool     valid, is_read;
    uint32_t x32 = 0, addr;

    // Get the MMIO address ([0] bit is read/write indicator)
    err = HS_msg_hw_to_host_chan_get_nb (comms_state, HS_MSG_HW_TO_HOST_CHAN_VIRTIO_MMIO_REQ,
					 & x32, & valid);
    if (err || (! valid) || (x32 == 0xFFFFFFFF)) goto done;

    addr    = x32 & 0xFFFFFFFC;
    is_read = ((x32 & 0x1) == 0);

    if (is_read) {
	// MMIO Read
	if ((f_debug_virtio != NULL) && (verbosity > 1))
	    fprintf (f_debug_virtio, "%s: Read reg 0x%08x\n", __FUNCTION__, addr);

	// Perform the read request from the guest and respond
	uint32_t read_data = HS_virtio_MMIO_read (state->virtiodevices, addr);

	err = HS_msg_host_to_hw_chan_put (comms_state, HS_MSG_HOST_TO_HW_CHAN_VIRTIO_MMIO_RSP,
					  read_data);
	if (err) goto done;

	did_some_work = true;
    }
    else {
	// MMIO Write
	uint32_t write_data;

	while (true) {
	    err = HS_msg_hw_to_host_chan_get (comms_state, HS_MSG_HW_TO_HOST_CHAN_VIRTIO_MMIO_REQ,
					      & write_data);
	    if (err) goto done;
	    if (write_data != 0xFFFFFFFF) break;
	}

	if ((f_debug_virtio != NULL) && (verbosity > 1))
	    fprintf (f_debug_virtio, "%s: Write addr 0x%08x data 0x%08x\n",
		     __FUNCTION__, addr, write_data);

	// Perform MMIO write request from guest
	HS_virtio_MMIO_write (state->virtiodevices, addr, write_data);
	did_some_work = true;

	// (Response is bogus data, only indicates 'write-completion'
	// uint32_t write_rsp = HS_virtio_MMIO_write (state->virtiodevices, addr, write_data);
	// ... send MMIO write_rsp to HW ...
    }

 done:
    return did_some_work;
}

// ================================================================
// Shutdown virtio

int HS_virtio_shutdown (HS_Virtio_State *state)
{
    // char dummy = 'X';
    // write (state->virtiodevices->stop_pipe [1], & dummy, sizeof (dummy));
    // close (state->virtiodevices->stop_pipe [1]);

    // pthread_join (state->virtiodevices->io_thread, NULL);
    return 0;
}

// ================================================================
