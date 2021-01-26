// Copyright (c) 2020-2021 Bluespec, Inc.  All Rights Reserved

// This library emulates AWS' routines fpga_dma_burst_read/write and
// fpga_pci_peek/poke for Bluesim and Verilator sim.

// ================================================================
// C lib includes

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>

// ----------------
// Project includes

#include "Bytevec.h"
#include "TCP_Client_Lib.h"
#include "AWS_Sim_Lib.h"

// ================================================================
// The Bytevec state

static
Bytevec_state *p_bytevec_state = NULL;

void AWS_Sim_Lib_init (void)
{
    fprintf (stdout, "AWS_Sim_Lib_init()\n");

    if (p_bytevec_state != NULL) {
	fprintf (stdout, "ERROR: %s: already initialized\n", __FUNCTION__);
	exit (1);
    }
    p_bytevec_state = mk_Bytevec_state ();
    if (p_bytevec_state == NULL) {
	fprintf (stdout, "ERROR: %s: mk_Bytevec_state failed\n", __FUNCTION__);
	exit (1);
    }

    uint32_t status = tcp_client_open (DEFAULT_HOSTNAME, DEFAULT_PORT);
    if (status == status_err) {
	fprintf (stdout, "ERROR: %s: failed\n", __FUNCTION__);
	exit (1);
    }

    fprintf (stdout, "%s: initialized, connected to simulation server\n", __FUNCTION__);
}

static
void check_state_initialized (void)
{
    if (p_bytevec_state != NULL) return;
    AWS_Sim_Lib_init ();
}

void AWS_Sim_Lib_shutdown (void)
{
    fprintf (stdout, "%s: closing TCP connection\n", __FUNCTION__);
    tcp_client_close (0);
}

// ================================================================

static
bool do_comms (void)
{
    int verbosity2 = 0;

    check_state_initialized ();

    uint32_t  status;
    bool activity = false;

    // Send
    if (verbosity2 > 1)
	fprintf (stdout, "%s: packet to_bytevec\n", __FUNCTION__);
    int ready = Bytevec_struct_to_bytevec (p_bytevec_state);
    if (ready) {
	if (verbosity2 != 0) {
	    fprintf (stdout, "%s: sending %0d bytes\n  ",  __FUNCTION__, p_bytevec_state->bytevec_C_to_BSV [0]);
	    for (int j = 0; j < p_bytevec_state->bytevec_C_to_BSV [0]; j++)
		fprintf (stdout, " %02x", p_bytevec_state->bytevec_C_to_BSV [j]);
	    fprintf (stdout, "\n");
	}
	status = tcp_client_send (p_bytevec_state->bytevec_C_to_BSV [0],
				  p_bytevec_state->bytevec_C_to_BSV);
	if (status == 0) {
	    fprintf (stdout, "%s: tcp_client_send error\n",  __FUNCTION__);
	    exit (1);
	}

	activity = true;
    }
        
    // Receive
    if (verbosity2 > 1)
	fprintf (stdout, "%s: attempt receive bytevec\n",  __FUNCTION__);
    const bool poll    = true;
    status = tcp_client_recv (poll, 1, p_bytevec_state->bytevec_BSV_to_C);
    if (status == status_ok) {
	const bool no_poll = false;
	uint32_t size = p_bytevec_state->bytevec_BSV_to_C [0] - 1;
	status = tcp_client_recv (no_poll, size, & (p_bytevec_state->bytevec_BSV_to_C [1]));

	if (verbosity2 != 0) {
	    fprintf (stdout, "%s: received %0d bytes\n  ",  __FUNCTION__, p_bytevec_state->bytevec_BSV_to_C [0]);
	    for (int j = 0; j < p_bytevec_state->bytevec_BSV_to_C [0]; j++)
		fprintf (stdout, " %02x", p_bytevec_state->bytevec_BSV_to_C [j]);
	    fprintf (stdout, "\n");
	}

	if (verbosity2 != 0)
	    fprintf (stdout, "%s: packet from_bytevec\n",  __FUNCTION__);
	Bytevec_struct_from_bytevec (p_bytevec_state);

	activity = true;
    }
    return activity;
}

// ================================================================
// This is our simulation model of the corresponding AWS library routine.

int fpga_dma_burst_read (int fd, uint8_t *buffer, size_t size, uint64_t address)
{
    int  verbosity2 = 0;
    bool did_some_comms;

    check_state_initialized ();

    // Check that the buffer does not cross a 4K boundary (= 12 bits of LSBs)
    uint64_t  address_lim = address + size;
    if ((address >> 12) != ((address_lim - 1) >> 12)) {
	fprintf (stdout, "ERROR: %s: buffer crosses a 4K boundary\n",  __FUNCTION__);
	fprintf (stdout, "    Start address: %16lx\n", address);
	fprintf (stdout, "    Last  address: %16lx\n", (address_lim - 1));
	return 1;
    }

    // Check that address is 64-Byte aligned (TODO: temporary; relax this)
    if ((address & 0x3F) != 0) {
	fprintf (stdout, "ERROR: %s: address is not 64-byte aligned\n",  __FUNCTION__);
	fprintf (stdout, "    Start address: %16lx\n", address);
	return 1;
    }

    // ----------------
    // Send RD_ADDR bus request

    AXI4_Rd_Addr_i16_a64_u0   rda;

    // TODO: Check if these defaults are ok
    rda.arid     = 0;
    rda.arlock   = 0;    // "normal"
    rda.arcache  = 0;    // "dev_nonbuf"
    rda.arprot   = 0;    // { data, secure, unpriv }
    rda.arqos    = 0;
    rda.arregion = 0;
    rda.aruser   = 0;

    // Compute burst length (each beat on DMA PCIS is 64 bytes = 6 bits of LSBs)
    uint64_t  num_beats = ((address_lim - 1) >> 6) - (address >> 6) + 1;

    rda.araddr  = address;
    rda.arlen   = num_beats - 1;    // AXI4 code: awlen+1 beats
    rda.arsize  = 0x6;              // AXI4 code: 64 bytes
    rda.arburst = 0x1;              // AXI4 code: 'incrementing' burst

    if (verbosity2 != 0)
	fprintf (stdout, "%s: araddr %0lx arlen %0d arsize %0x arburst %0x",
		 __FUNCTION__, rda.araddr, rda.arlen, rda.arsize, rda.arburst);
    while (true) {
	int status = Bytevec_enqueue_AXI4_Rd_Addr_i16_a64_u0 (p_bytevec_state, & rda);
	if (status == 1) break;
	usleep (1);
	did_some_comms = do_comms ();
    }
    did_some_comms = do_comms ();

    // ----------------
    // Read RD_DATA bus burst response

    AXI4_Rd_Data_i16_d512_u0  rdd;

    uint8_t *pb = buffer;

    bool ok = true;
    for (int beat = 0; beat < num_beats; beat++) {
	while (true) {
	    did_some_comms = do_comms ();
	    if (! did_some_comms)
		usleep (1);

	    int status = Bytevec_dequeue_AXI4_Rd_Data_i16_d512_u0 (p_bytevec_state, & rdd);
	    if (status == 1) break;

	    if (verbosity2 > 1)
		fprintf (stdout, "%s: response polling loop; beat %0d\n", __FUNCTION__, beat);
	}

	// Debugging: show response
	if (verbosity2 != 0) {
	    fprintf (stdout, "%s: beat %0d  rresp %0d  rlast %0d  rdata:\n  [",
		     __FUNCTION__, beat, rdd.rresp, rdd.rlast);
	    for (int k = 0; k < 64; k++)
		fprintf (stdout, " %02x", rdd.rdata [k]);
	    fprintf (stdout, "]\n");
	}

	// Check rlast was properly set
	if (beat == (num_beats - 1)) {
	    if (rdd.rlast == 0) {
		fprintf (stdout, "ERROR: %s: rlast is 0 on last beat\n",  __FUNCTION__);
		return 1;
	    }
	}
	else {
	    if (rdd.rlast == 1) {
		fprintf (stdout, "ERROR: %s: rlast is 1 on non-last beat\n",  __FUNCTION__);
		return 1;
	    }
	}
	ok = (ok && (rdd.rresp == 0));    // AXI4: rresp is OKAY

	memcpy (pb, & (rdd.rdata), 64);
	pb += 64;
    }    
    fprintf (stdout, "%s: complete\n",  __FUNCTION__);

    return (! ok);
}

// ================================================================
// This is our simulation model of the corresponding AWS library routine.

int fpga_dma_burst_write (int fd, uint8_t *buffer, size_t size, uint64_t address)
{
    int  verbosity2 = 0;
    bool did_some_comms;

    check_state_initialized ();

    // Check that the buffer does not cross a 4K boundary (= 12 bits of LSBs)
    uint64_t  address_lim = address + size;
    if ((address >> 12) != ((address_lim - 1) >> 12)) {
	fprintf (stdout, "ERROR: %s: buffer crosses a 4K boundary\n",  __FUNCTION__);
	fprintf (stdout, "    Start address: %16lx\n", address);
	fprintf (stdout, "    Last  address: %16lx\n", (address_lim - 1));
	return 1;
    }

    // Check that address is 64-Byte aligned (TODO: temporary; relax this)
    if ((address & 0x3F) != 0) {
	fprintf (stdout, "ERROR: %s: address is not 64-byte aligned\n",  __FUNCTION__);
	fprintf (stdout, "    Start address: %16lx\n", address);
	return 1;
    }

    // ----------------
    // Send WR_ADDR bus request

    AXI4_Wr_Addr_i16_a64_u0  wra;

    // TODO: Check if these defaults are ok
    wra.awid     = 0;
    wra.awlock   = 0;    // "normal"
    wra.awcache  = 0;    // "dev_nonbuf"
    wra.awprot   = 0;    // { data, secure, unpriv }
    wra.awqos    = 0;
    wra.awregion = 0;
    wra.awuser   = 0;

    // Compute burst length (each beat on DMA PCIS is 64 bytes = 6 bits of LSBs)
    uint64_t  num_beats = ((address_lim - 1) >> 6) - (address >> 6) + 1;

    wra.awaddr  = address;
    wra.awlen   = num_beats - 1;    // AXI4 code: awlen+1 beats
    wra.awsize  = 0x6;              // AXI4 code: 64 bytes
    wra.awburst = 0x1;              // AXI4 code: 'incrementing' burst

    if (verbosity2 != 0)
	fprintf (stdout, "%s: awaddr %0lx awlen %0d awsize %0x awburst %0x\n",
		 __FUNCTION__, wra.awaddr, wra.awlen, wra.awsize, wra.awburst);
    while (true) {
	int status = Bytevec_enqueue_AXI4_Wr_Addr_i16_a64_u0 (p_bytevec_state, & wra);
	if (status == 1) break;
	usleep (1);
	did_some_comms = do_comms ();
    }
    did_some_comms = do_comms ();

    // ----------------
    // Send WR_DATA bus request

    AXI4_Wr_Data_d512_u0  wrd;
    wrd.wuser = 0;
    wrd.wstrb = 0xFFFFffffFFFFffff;    // TODO: adjust for first and last beat

    uint8_t *pb = buffer;

    for (int beat = 0; beat < num_beats; beat++) {
	memcpy (& wrd.wdata, pb, 64);
	wrd.wlast = (beat == (num_beats - 1));

	if (verbosity2 != 0) {
	    fprintf (stdout, "%s: beat %0d  wlast %0d  wdata:\n  ",
		     __FUNCTION__, beat, wrd.wlast);
	    for (int k = 0; k < 64; k++)
		fprintf (stdout, " %02x", wrd.wdata [k]);
	    fprintf (stdout, "\n");
	}

	while (true) {
	    int status = Bytevec_enqueue_AXI4_Wr_Data_d512_u0  (p_bytevec_state, & wrd);
	    if (status == 1) break;
	    usleep (1);
	    did_some_comms = do_comms ();
	}
	did_some_comms = do_comms ();
	pb += 64;
    }    

    // ----------------
    // Get  WR_RESP bus response

    AXI4_Wr_Resp_i16_u0  wrr;

    while (true) {
	did_some_comms = do_comms ();
	if (! did_some_comms)
	    usleep (1);

	int status = Bytevec_dequeue_AXI4_Wr_Resp_i16_u0 (p_bytevec_state, & wrr);
	if (status == 1) break;

	if (verbosity2 > 1)
	    fprintf (stdout, "%s: response polling loop\n", __FUNCTION__);

    }
    if (verbosity2 != 0)
	fprintf (stdout, "%s: complete; bresp = %0d\n", __FUNCTION__, wrr.bresp);

    return (wrr.bresp != 0);
}

// ================================================================
// This is our simulation model of the corresponding AWS library routine.

int fpga_pci_peek (pci_bar_handle_t handle, uint64_t ocl_addr, uint32_t *p_ocl_data)
{
    int  verbosity2 = 0;
    bool did_some_comms;

    check_state_initialized ();

    AXI4L_Rd_Addr_a32_u0  rda;
    AXI4L_Rd_Data_d32_u0  rdd;

    rda.araddr = ocl_addr;
    rda.arprot = 0;
    rda.aruser = 0;

    if (verbosity2 != 0)
	fprintf (stdout, "%s: enqueue AXI4L Rd_Addr %08x\n", __FUNCTION__, rda.araddr);
    while (true) {
	int status = Bytevec_enqueue_AXI4L_Rd_Addr_a32_u0 (p_bytevec_state, & rda);
	if (status == 1) break;
	usleep (1);
	did_some_comms = do_comms ();
    }

    while (true) {
	did_some_comms = do_comms ();
	if (! did_some_comms)
	    usleep (1000);

	int status = Bytevec_dequeue_AXI4L_Rd_Data_d32_u0 (p_bytevec_state, & rdd);
	if (status == 1) {
	    *p_ocl_data = rdd.rdata;
	    break;
	}
    }
    if (verbosity2 != 0)
	fprintf (stdout, "%s: rresp %0d, rdata %08x\n", __FUNCTION__, rdd.rresp, rdd.rdata);
    return 0;
}

// ================================================================
// This is our simulation model of the corresponding AWS library routine.

int fpga_pci_poke (pci_bar_handle_t handle, uint64_t ocl_addr, uint32_t ocl_data)
{
    int  verbosity2 = 0;
    bool did_some_comms;

    check_state_initialized ();

    AXI4L_Wr_Addr_a32_u0  wra;
    AXI4L_Wr_Data_d32     wrd;
    AXI4L_Wr_Resp_u0      wrr;

    wra.awaddr = ocl_addr;
    wra.awprot = 0;
    wra.awuser = 0;

    wrd.wdata  = ocl_data;
    wrd.wstrb  = 0xFF;

    while (true) {
	int status = Bytevec_enqueue_AXI4L_Wr_Addr_a32_u0 (p_bytevec_state, & wra);
	if (status == 1) break;
	usleep (1);
	did_some_comms = do_comms ();
    }
    while (true) {
	int status = Bytevec_enqueue_AXI4L_Wr_Data_d32    (p_bytevec_state, & wrd);
	if (status == 1) break;
	usleep (1);
	did_some_comms = do_comms ();
    }

    while (true) {
	did_some_comms = do_comms ();
	if (! did_some_comms)
	    usleep (1);

	int status = Bytevec_dequeue_AXI4L_Wr_Resp_u0 (p_bytevec_state, & wrr);
	if (status == 1) break;
    }
    if (verbosity2 != 0)
	fprintf (stdout, "%s: bresp = %0d\n", __FUNCTION__, wrr.bresp);
    return 0;
}

// ================================================================
