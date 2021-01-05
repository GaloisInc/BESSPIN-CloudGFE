// Copyright (c) 2020 Bluespec, Inc.  All Rights Reserved
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
// C lib includes

// This define-macro is needed to avoid this compiler warning:
//   warning: implicit declaration of function ‘pthread_setname_np’
#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <inttypes.h>
#include <string.h>
#include <stdbool.h>
#include <ctype.h>
#include <unistd.h>

#include <pthread.h>

// ----------------
// AWS lib includes

#ifdef AWS_XSIM
# include <fpga_pci_sv.h>
#endif

#ifdef AWS_FPGA
# include <fpga_pci.h>
# include <fpga_mgmt.h>
# include "fpga_dma.h"
# include <utils/lcd.h>
#endif

// ----------------
// Virtio library includes

#include "virtio.h"
#include "temu.h"

// ----------------
// Project includes

#include "SimpleQueue.h"
#include "HS_virtio.h"

// ================================================================

static int debug_virtio   = 1;
static int debug_stray_io = 0;

// ================================================================
// These two functions are called by the Virtio console device driver
// to actually perform the console character read/write.
// Note: this is NOT the direct UART device on the HW side;
//     this is the virtio emulation of a console.
//     Both can co-exist.
// TODO: can be improved substantially.

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

// ================================================================
// This thread performs the Virtio 'work'

static
void *HS_virtio_process_io_thread(void *opaque)
{
    VirtioDevices *vds = (VirtioDevices *) opaque;

    int stdin_fd;
    int fd_max = -1;
    fd_set rfds, wfds, efds;
    int delay = 10; // ms
    struct timeval tv;
    int stop_fd = vds->stop_pipe[0];

    while (true) {
        FD_ZERO(&rfds);
        FD_ZERO(&wfds);
        FD_ZERO(&efds);

        FD_SET(stop_fd, &rfds);
        fd_max = stop_fd;

        if (vds->virtio_console && virtio_console_can_write_data(vds->virtio_console)) {
            stdin_fd = (int)(intptr_t)vds->console->opaque;
            FD_SET(stdin_fd, &rfds);
            fd_max = max(stdin_fd, fd_max);
        }

	if (vds->ethernet_device) {
            vds->ethernet_device->select_fill (vds->ethernet_device,
					       & fd_max, & rfds, & wfds, & efds, & delay);
	}

        tv.tv_sec = delay / 1000;
        tv.tv_usec = (delay % 1000) * 1000;
        int ret = select(fd_max + 1, &rfds, &wfds, &efds, &tv);
        if (FD_ISSET(stop_fd, &rfds)) {
            close(stop_fd);
            return NULL;
        }

        if (vds->ethernet_device) {
            vds->ethernet_device->select_poll (vds->ethernet_device,
					       & rfds, & wfds, & efds, ret);
        }

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
    }
    return NULL;
}

// ================================================================

static
void fn_set_irq (void *opaque, int irq_num, int level)
{
    HS_Virtio_State *state = (HS_Virtio_State *) opaque;

    if (debug_virtio)
	fprintf (stdout, "%s: irq_num=%d level=%d\r\n", __FUNCTION__, irq_num, level);

    if ((irq_num < 0) || (31 < irq_num)) {
	fprintf (stdout, "ERROR: %s: irq_num (%0d) is not in range 0..31\n",
		 __FUNCTION__, irq_num);
    }

    // data [31] = 1 for set, 0 for clear; data [4:0] = irq_num
    uint32_t data = irq_num;
    if (level)
	data = (1 << 31) | data;
    SimpleQueuePut (state->queue_virtio_irq_to_hw, data);
}

HS_Virtio_State *HS_virtio_init (const char *tun_iface,
				 const int   enable_virtio_console,
				 const int   dma_enabled,
				 const int   xdma_enabled,
				 const char *block_files [],
				 const int   num_block_files)
{
    VirtioDevices *vds = NULL;

    /*
    // Allocate and initialize VirtioDevices object
    vds = (VirtioDevices *) malloc (sizeof (VirtioDevices));
    if (vds == NULL) {
	fprintf (stderr, "ERROR: %s: malloc failed\n", __FUNCTION__);
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
        irq_init (& (vds->irq[i]), fn_set_irq, (void *)22, i);
    }

    // set up a network device
    vds->virtio_bus->irq = & (vds->irq [vds->irq_num++]);
    vds->ethernet_device = vds->tun_ifname ? tun_open(vds->tun_ifname) : slirp_open();
    vds->virtio_net = virtio_net_init (vds->virtio_bus, vds->ethernet_device);
    fprintf(stderr, "ethernet device %p virtio net device %p at addr %08lx\n",
	    vds->ethernet_device, vds->virtio_net, vds->virtio_bus->addr);

    // set up an entropy device
    vds->virtio_bus->addr += 0x1000;
    vds->virtio_bus->irq = & (vds->irq [vds->irq_num++]);
    vds->virtio_entropy = virtio_entropy_init(vds->virtio_bus);
    fprintf(stderr, "virtio entropy device %p at addr %08lx\n",
	    vds->virtio_entropy, vds->virtio_bus->addr);

    // TODO: Do we need this?
    // if (dma_enabled)
    //    fpga->map_pcis_dma();

    // ================================================================
    // Set up XDMA
    // Corresponds to this in Connectal:
    //     if (xdma_enabled) fpga->open_xdma();

    int read_fd  = -1;
    int write_fd = -1;

#if defined(AWS_FPGA) || defined (AWS_BLUESIM) || defined (AWS_VERILATOR)
    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id,
				  0,        // channel
				  true);    // is_read
    if (read_fd < 0) {
	fprintf (stdout, "ERROR: %s: unable to open read-dma queue\n");
	exit (1);
    }

    write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id,
				   0,         // channel
				   false);    // is_read
    if (write_fd < 0) {
	fprintf (stdout, "ERROR: %s: unable to open write-dma queue\n");
	exit (1);
    }
    virtio_xdma_init (read_fd, write_fd);
#endif

    // ================================================================
    // Set up a block device for each given block device filename

    for (int j = 0; j < num_block_files; j++) {
	vds->virtio_bus->addr += 0x1000;
	vds->virtio_bus->irq   = & (vds->irq [vds->irq_num++]);
	vds->block_device = block_device_init (block_files [j], BF_MODE_RW);
	if (debug_virtio)
	    fprintf (stdout, "block device %s (%p)\r\n", block_files [j], vds->block_device);
	vds->virtio_block = virtio_block_init(vds->virtio_bus, vds->block_device);
	if (debug_virtio)
	    fprintf (stdout, "virtio block device %p at addr %08lx\r\n",
		     vds->virtio_block, vds->virtio_bus->addr);
    }


    // ================================================================
    // Set up a virtio console

    if (enable_virtio_console) {
        fprintf(stderr, "Enabling virtio console\n");
	vds->console = (CharacterDevice *) malloc (sizeof (CharacterDevice));
	vds->console->opaque = (void *)(intptr_t)-1;
	vds->console->read_data = console_read_data;
	vds->console->write_data = console_write_data;

	vds->virtio_bus->addr += 0x1000;
	vds->virtio_bus->irq   = & (vds->irq [vds->irq_num++]);

	vds->virtio_console = virtio_console_init (vds->virtio_bus, vds->console);
    }

    // ================================================================
    // Start pending-notify thread and io thread

    VIRTIODevice *ps[4];
    int n = 0;

#define ADD_DEVICE(s) if (s) ps[n++] = s
    ADD_DEVICE(vds->virtio_net);
    ADD_DEVICE(vds->virtio_entropy);
    ADD_DEVICE(vds->virtio_block);
    ADD_DEVICE(vds->virtio_console);
#undef ADD_DEVICE

    // Start 'pending notify thread' and io thread
    virtio_start_pending_notify_thread (n, ps);
    pthread_create (& vds->io_thread, NULL, & HS_virtio_process_io_thread, vds);
    pthread_setname_np (vds->io_thread, "VirtIO I/O");
    */

    // ================================================================
    // Allocate and initialize HS_Virtio_State object

    HS_Virtio_State *state = (HS_Virtio_State *) malloc (sizeof (HS_Virtio_State));
    if (state == NULL) {
	fprintf (stdout, "ERROR: %s: malloc failed\n", __FUNCTION__);
	exit (1);
    }
    state->queue_virtio_req_from_hw = SimpleQueueInit ();
    state->queue_virtio_rsp_to_hw   = SimpleQueueInit ();
    state->queue_virtio_irq_to_hw   = SimpleQueueInit ();

    state->virtiodevices = vds;
    return state;
}

// ================================================================
// Check if virtio MMIO request is available from hw (guest)

int HS_virtio_req_from_hw_notFull (HS_Virtio_State *state, bool *p_notFull)
{
    *p_notFull = true;
    return 0;
}

// ================================================================
// Get virtio MMIO request from hw (guest)

int HS_virtio_req_from_hw_data (HS_Virtio_State *state, uint32_t data)
{
    SimpleQueuePut (state->queue_virtio_req_from_hw, data);
}

// ================================================================
// Check if a virtio MMIO response is available to send to hw (guest)

int HS_virtio_rsp_to_hw_notEmpty (HS_Virtio_State *state, bool *p_notEmpty)
{
    *p_notEmpty = (! SimpleQueueEmpty (state->queue_virtio_rsp_to_hw));
    return 0;
}

// ================================================================
// Send virtio MMIO response to hw (guest)

int HS_virtio_rsp_to_hw_data (HS_Virtio_State *state, uint32_t *p_data)
{
    uint64_t data;
    SimpleQueueGet (state->queue_virtio_rsp_to_hw, & data);
    *p_data = data;
    return 0;
}

// ================================================================
// Check if a virtio interrupt request is available to send to hw (guest)

int HS_virtio_irq_to_hw_notEmpty (HS_Virtio_State *state, bool *p_notEmpty)
{
    *p_notEmpty = (! SimpleQueueEmpty (state->queue_virtio_irq_to_hw));
    return 0;
}

// ================================================================
// Send virtio interrupt request to hw (guest)

int HS_virtio_irq_to_hw_data (HS_Virtio_State *state, uint32_t *p_data)
{
    uint64_t data;
    SimpleQueueGet (state->queue_virtio_irq_to_hw, & data);
    *p_data = data;

    if (debug_virtio)
	fprintf (stdout, "%s: data %0x\n", __FUNCTION__, *p_data);

    return 0;
}

// ================================================================
// MMIO reads and writes from guest

// ----------------
// MMIO reads from guest
// Returns value read from MMIO control register array.

static bool send_irq = false;    // TODO: DELETE AFTER DEBUG

static
uint32_t HS_virtio_MMIO_read (VirtioDevices *vds, uint32_t addr)
{
    if (debug_virtio)
	fprintf (stdout, "%s: addr %0x\n", __FUNCTION__, addr);

    uint32_t result = addr + 1;    // TODO: temporary
    /*
    PhysMemoryRange *pr = get_phys_mem_range (vds->mem_map, addr);
    if (pr) {
        uint32_t offset    = addr - pr->addr;
        int      size_log2 = 2;
	result = pr->read_func (pr->opaque, offset, size_log2);
    }
    else {
        if (debug_stray_io)
	    fprintf (stdout, "%s: ERROR: UNKNOWN ADDR %0x\n", __FUNCTION__, addr);
    }
    */

    if (addr == 0x62500024) send_irq = true;    // TODO: DELETE AFTER DEBUG

    return result;
}

// ----------------
// MMIO writes from quest

static
uint32_t HS_virtio_MMIO_write (VirtioDevices *vds, uint32_t addr, uint32_t data)
{
    if (debug_virtio)
	fprintf (stdout, "%s: addr %0x data %0x\n", __FUNCTION__, addr, data);

    uint32_t result = data + 0x100;    // TODO: temporary
    /*
    PhysMemoryRange *pr = get_phys_mem_range (vds->mem_map, addr);

    if (pr) {
        uint32_t offset    = addr - pr->addr;
        int      size_log2 = 2;
        pr->write_func (pr->opaque, offset, data, size_log2);
    }
    else {
        if (debug_stray_io)
	    fprintf (stdout, "%s: ERROR: UNKNOWN ADDR %0x data %0x\n", __FUNCTION__, addr, data);
    }
    */
    return result;
}

// ================================================================

bool HS_virtio_do_some_work (HS_Virtio_State *state)
{
    bool did_some_work = false;

    // ----------------
    // Process virtio MMIO request from HW
    // Requests are 1 32-bit word (read: addr) or 2 32-bit words (write: addr, data)

    int       req_occupancy = SimpleQueueOccupancy (state->queue_virtio_req_from_hw);
    uint64_t  x64;
    SimpleQueueFirst (state->queue_virtio_req_from_hw, & x64);
    uint32_t  addr          = (x64 & 0xFFFFFFFC);    // zero the lsbs
    bool      rsp_notFull   = (! SimpleQueueFull (state->queue_virtio_rsp_to_hw));

    if (send_irq && (! SimpleQueueFull (state->queue_virtio_irq_to_hw))) {
	if (debug_virtio)
	    fprintf (stdout, "%s: Generating interrrupt for hw\n", __FUNCTION__);
	send_irq = false;

	SimpleQueuePut (state->queue_virtio_irq_to_hw, 0xFEDCFEDC);
	did_some_work = true;
    }

    if ((req_occupancy > 0) && rsp_notFull && ((x64 & 0x1) == 0)) {
	// Read request

	// Pop addr|request from queue
	SimpleQueueGet (state->queue_virtio_req_from_hw, & x64);

	// Perform the read request from the guest and respond
	uint32_t read_data = HS_virtio_MMIO_read (state->virtiodevices, addr);
	SimpleQueuePut (state->queue_virtio_rsp_to_hw, read_data);

	did_some_work = true;
    }
    else if ((req_occupancy > 1) && rsp_notFull && ((x64 & 0x1) == 1)) {
	// write request

	// Pop addr|request and write-data from queue
	SimpleQueueGet (state->queue_virtio_req_from_hw, & x64);
	SimpleQueueGet (state->queue_virtio_req_from_hw, & x64);
	uint32_t write_data = (x64 & 0xFFFFFFFF);

	// Perform MMIO write request from guest and respond
	// (Response is bogus data, only indicates 'write-completion'
	uint32_t write_rsp = HS_virtio_MMIO_write (state->virtiodevices, addr, write_data);
	SimpleQueuePut (state->queue_virtio_rsp_to_hw, write_rsp);

	did_some_work = true;
    }

    return did_some_work;
}

// ================================================================
// Shutdown virtio

int HS_virtio_shutdown (HS_Virtio_State *state)
{
    virtio_stop_pending_notify_thread ();
    char dummy = 'X';
    write (state->virtiodevices->stop_pipe [1], & dummy, sizeof (dummy));
    close (state->virtiodevices->stop_pipe [1]);

    virtio_join_pending_notify_thread();
    pthread_join (state->virtiodevices->io_thread, NULL);
}

// ================================================================