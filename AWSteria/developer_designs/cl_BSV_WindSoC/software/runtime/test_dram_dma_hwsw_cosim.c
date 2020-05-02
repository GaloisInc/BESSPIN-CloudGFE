// Amazon FPGA Hardware Development Kit
//
// Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Amazon Software License (the "License"). You may not use
// this file except in compliance with the License. A copy of the License is
// located at
//
//    http://aws.amazon.com/asl/
//
// or in the "license" file accompanying this file. This file is distributed on
// an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
// implied. See the License for the specific language governing permissions and
// limitations under the License.

#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <malloc.h>
#include <poll.h>

#include <utils/sh_dpi_tasks.h>

#ifdef SV_TEST
# include <fpga_pci_sv.h>
#else
# include <fpga_pci.h>
# include <fpga_mgmt.h>
# include "fpga_dma.h"
# include <utils/lcd.h>
#endif

#include "test_dram_dma_common.h"

#define MEM_16G              (1ULL << 34)

void usage(const char* program_name);
int dma_example_hwsw_cosim(int slot_id, size_t buffer_size);

static inline int do_dma_read(int fd, uint8_t *buffer, size_t size,
    uint64_t address, int channel, int slot_id);
static inline int do_dma_write(int fd, uint8_t *buffer, size_t size,
    uint64_t address, int channel, int slot_id);

// ****************************************************************
// AWSteria code

static const char this_file_name [] = "test_dram_dma_hwsw_cosim.c";

#include "Memhex32_read.h"

int start_hw (int slot_id, int pf_id, int bar_id);

int load_mem_hex32_using_DMA (int slot_id, char *filename);

// ****************************************************************

#if !defined(SV_TEST)
/* use the stdout logger */
const struct logger *logger = &logger_stdout;
#else
# define log_error(...) printf(__VA_ARGS__); printf("\n")
# define log_info(...) printf(__VA_ARGS__); printf("\n")
#endif

/* Main will be different for different simulators and also for C. The
 * definition is in sdk/userspace/utils/include/sh_dpi_tasks.h file */
#if defined(SV_TEST) && defined(INT_MAIN)
/* For cadence and questa simulators main has to return some value */
int test_main(uint32_t *exit_code)

#elif defined(SV_TEST)
void test_main(uint32_t *exit_code)

#else 
int main(int argc, char **argv)

#endif
{
    size_t buffer_size;
#if defined(SV_TEST)
    buffer_size = 128;
#else
    buffer_size = 1ULL << 24;
#endif

    /* The statements within SCOPE ifdef below are needed for HW/SW
     * co-simulation with VCS */
#if defined(SCOPE)
    svScope scope;
    scope = svGetScopeFromName("tb");
    svSetScope(scope);
#endif

    int rc;
    int slot_id = 0;

#if !defined(SV_TEST)
    switch (argc) {
    case 1:
        break;
    case 3:
        sscanf(argv[2], "%x", &slot_id);
        break;
    default:
        usage(argv[0]);
        return 1;
    }

    /* setup logging to print to stdout */
    rc = log_init("test_dram_dma_hwsw_cosim");
    fail_on(rc, out, "Unable to initialize the log.");
    rc = log_attach(logger, NULL, 0);
    fail_on(rc, out, "%s", "Unable to attach to the log.");

    /* initialize the fpga_plat library */
    rc = fpga_mgmt_init();
    fail_on(rc, out, "Unable to initialize the fpga_mgmt library");

#endif

    rc = dma_example_hwsw_cosim(slot_id, buffer_size);
    fail_on(rc, out, "DMA example failed");

    // ================================================================
    // AWSteria code

    // TODO: get the filename from command-line args/config file/...
    char memhex32_filename []
	= "/home/nikhil/git_clones/AWS/aws-fpga/hdk/cl/developer_designs/cl_BSV_WindSoC/verif/scripts/Mem.hex";

    rc = load_mem_hex32_using_DMA (slot_id, memhex32_filename);
    fail_on (rc, out, "Loading the mem hex32 file failed");

    // Start the hardware
    rc = start_hw (slot_id, FPGA_APP_PF, APP_PF_BAR0);
    fail_on (rc, out, "starting the HW failed");

    // ================================================================

out:

#if !defined(SV_TEST)
    return rc;
#else
    if (rc != 0) {
        printf("TEST FAILED \n");
    }
    else {
        printf("TEST PASSED \n");
    }
    /* For cadence and questa simulators main has to return some value */
    #ifdef INT_MAIN
    *exit_code = 0;
    return 0;
    #else
    *exit_code = 0;
    #endif
#endif
}

void usage(const char* program_name) {
    printf("usage: %s [--slot <slot>]\n", program_name);
}

/**
 * Write 4 identical buffers to the 4 different DRAM channels of the AFI
 */
int dma_example_hwsw_cosim(int slot_id, size_t buffer_size)
{
    int write_fd, read_fd, dimm, rc;

    write_fd = -1;
    read_fd = -1;

    uint8_t *write_buffer = malloc(buffer_size);
    uint8_t *read_buffer = malloc(buffer_size);
    if (write_buffer == NULL || read_buffer == NULL) {
        rc = -ENOMEM;
        goto out;
    }

    printf("Memory has been allocated, initializing DMA and filling the buffer...\n");
#if !defined(SV_TEST)
    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id,
        /*channel*/ 0, /*is_read*/ true);
    fail_on((rc = (read_fd < 0) ? -1 : 0), out, "unable to open read dma queue");

    write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id,
        /*channel*/ 0, /*is_read*/ false);
    fail_on((rc = (write_fd < 0) ? -1 : 0), out, "unable to open write dma queue");
#else
    setup_send_rdbuf_to_c(read_buffer, buffer_size);
    printf("Starting DDR init...\n");
    init_ddr();
    // AWSteria: Uncommented next line, since we've removed ATG circuits
    // deselect_atg_hw();
    printf("Done DDR init...\n");
#endif
    printf("filling buffer with  random data...\n") ;

    rc = fill_buffer_urandom(write_buffer, buffer_size);
    fail_on(rc, out, "unable to initialize buffer");

    fprintf (stdout, "Write buffer contents:\n");
    for (int j = 0; j < 128; j = j + 4) {
	uint32_t *p = (uint32_t *) (write_buffer + j);
	fprintf (stdout, "    %08x: %08x\n", j, *p);
    }

    printf("Now performing the DMA transactions...\n");
    for (dimm = 0; dimm < 4; dimm++) {
        rc = do_dma_write(write_fd, write_buffer, buffer_size,
            dimm * MEM_16G, dimm, slot_id);
        fail_on(rc, out, "DMA write failed on DIMM: %d", dimm);
    }

    bool passed = true;
    for (dimm = 0; dimm < 4; dimm++) {
        rc = do_dma_read(read_fd, read_buffer, buffer_size,
            dimm * MEM_16G, dimm, slot_id);
        fail_on(rc, out, "DMA read failed on DIMM: %d", dimm);
        uint64_t differ = buffer_compare(read_buffer, write_buffer, buffer_size);
        if (differ != 0) {
            log_error("DIMM %d failed with %lu bytes which differ", dimm, differ);
            passed = false;
        } else {
            log_info("DIMM %d passed!", dimm);
        }
    }
    rc = (passed) ? 0 : 1;

out:
    if (write_buffer != NULL) {
        free(write_buffer);
    }
    if (read_buffer != NULL) {
        free(read_buffer);
    }
#if !defined(SV_TEST)
    if (write_fd >= 0) {
        close(write_fd);
    }
    if (read_fd >= 0) {
        close(read_fd);
    }
#endif
    /* if there is an error code, exit with status 1 */
    return (rc != 0 ? 1 : 0);
}

static inline int do_dma_read(int fd, uint8_t *buffer, size_t size,
    uint64_t address, int channel, int slot_id)
{
#if defined(SV_TEST)
    sv_fpga_start_cl_to_buffer(slot_id, channel, size, (uint64_t) buffer, address);
    return 0;
#else
    return fpga_dma_burst_read(fd, buffer, size, address);
#endif
}

static inline int do_dma_write(int fd, uint8_t *buffer, size_t size,
    uint64_t address, int channel, int slot_id)
{
#if defined(SV_TEST)
    sv_fpga_start_buffer_to_cl(slot_id, channel, size, (uint64_t) buffer, address);
    return 0;
#else
    return fpga_dma_burst_write(fd, buffer, size, address);
#endif
}

// ================================================================
// Load memory using DMA

#define BUF_SIZE 0x200000000llu

int load_mem_hex32_using_DMA (int slot_id, char *filename)
{
    int write_fd, read_fd, rc;
    int channel = 0;

    fprintf (stdout, "%s: Reading Mem Hex32 file into local buffer: %s\n",
	     this_file_name, filename);

    // Allocate a buffer to read memhex contents
    uint8_t *buf = (uint8_t *) malloc  (BUF_SIZE);
    if (buf == NULL) {
	fprintf (stdout, "%s: ERROR allocating memhex buffer of size: %0ld (0x%0lx)\n",
		 this_file_name, BUF_SIZE, BUF_SIZE);
	rc = 1;
	goto out;
    }

    // Read the memhex file
    uint64_t  addr_base, addr_lim;
    rc = memhex32_read (filename, buf, BUF_SIZE, & addr_base, & addr_lim);
    if (rc != 0) {
	fprintf (stdout, "%s: ERROR reading Mem_hex32 file: %s\n", this_file_name, filename);
	rc = 1;
	goto out;
    }
    fprintf (stdout, "Mem_hex32 file read ok.\n");
    fprintf (stdout, "    addr_base 0x%0lx  addr_lim 0x%0lx (%0ld bytes)\n",
	     addr_base, addr_lim, addr_lim - addr_base);
    if (addr_base >= addr_lim) {
	fprintf (stdout, "    But this is empty! Abandoning download\n");
	rc = 1;
	goto out;
    }
    uint64_t download_size = addr_lim - addr_base;

    // ================
    // Prep for DMA write and read

    write_fd = -1;
    read_fd = -1;

    // Allocate a read buffer, just for read-back sanity check on first 128 bytes.
    size_t buffer_size = 128;
    uint8_t *read_buffer = malloc (buffer_size);
    if (read_buffer == NULL) {
        rc = -ENOMEM;
        goto out;
    }

#if !defined(SV_TEST)
    //                                                      channel  is_read
    read_fd  = fpga_dma_open_queue (FPGA_DMA_XDMA, slot_id, 0,       true);
    fail_on((rc = (read_fd < 0) ? -1 : 0), out, "unable to open read dma queue");

    //                                                      channel  is_read
    write_fd = fpga_dma_open_queue (FPGA_DMA_XDMA, slot_id, 0,       false);
    fail_on((rc = (write_fd < 0) ? -1 : 0), out, "unable to open write dma queue");
#else
    setup_send_rdbuf_to_c (read_buffer, buffer_size);
#endif

    // ================
    // Download to DDR4:
    // - in chunks that do not cross 4K boundaries
    // - destination addrs must be 64-byte aligned

    uint8_t *dma_buf;
    rc = posix_memalign ((void **) (& dma_buf), 0x1000, 0x1000);    // 4KB buffer, 4KB aligned
    if (rc != 0) {
	fprintf (stdout, "%s: ERROR could not allocate 4KB buf with posix_memalign\n", this_file_name);
	rc = 1;
	goto out;
    }
    fprintf (stdout, "%s: 4KB DMA buffer allocated at %p\n", this_file_name, dma_buf);

    fprintf (stdout, "Downloading to AWS DDR4\n");
    uint64_t  addr1 = ((addr_base >> 6) << 6);    // 64B aligned (required by AWS)
    while (addr1 < addr_lim) {
	int chunk_size = (addr_lim - addr1);
	if (chunk_size > 0x1000) chunk_size = 0x1000;    // Trimmed to 4KB if nec'y

	// Copy data to DMA buffer
	memcpy (dma_buf, & (buf [addr1]), chunk_size);

	// DMA it
	fprintf (stdout, "%s: DMA %0d bytes to addr 0x%0lx\n", this_file_name, chunk_size, addr1);
	rc = do_dma_write (write_fd, dma_buf, chunk_size, addr1, channel, slot_id);
	fail_on (rc, out, "DMA write failed on channel 0");

	addr1 += chunk_size;
    }

    // ================
    // Readback up to 128 bytes and cross-check
    size_t read_size = ((download_size <= 128) ? download_size : 128);
    fprintf (stdout, "Reading back %0d bytes to spot-check the download\n", read_size);
    addr1 = ((addr_base >> 6) << 6);    // 64B aligned (required by AWS)
    rc = do_dma_read (read_fd, dma_buf, read_size, addr1, channel, slot_id);
    fail_on (rc, out, "DMA read failed on channel 0");

    fprintf (stdout, "Checking readback-data of %0d bytes ...\n", read_size);
    for (uint64_t j = 0; j < read_size; j += 4) {
	uint32_t *p1 = (uint32_t *) (buf + addr1 + j);
	uint32_t *p2 = (uint32_t *) (dma_buf + j);
	if (*p1 != *p2) {
	    fprintf (stdout, "%s: read-back of mem data differs at addr %0x\n", this_file_name, j);
	    fprintf (stdout, "    Original  word: 0x%08x\n", *p1);
	    fprintf (stdout, "    Read-back word: 0x%08x\n", *p2);
	    rc = 1;
	    goto out;
	}
	fprintf (stdout, "    %08lx: %08lx\n", j, *p1);
    }
    fprintf (stdout, "Checking readback-data of %0d bytes: OK\n", read_size);

out:
    if (read_buffer != NULL) {
        free(read_buffer);
    }
#if !defined(SV_TEST)
    if (write_fd >= 0) {
        close(write_fd);
    }
    if (read_fd >= 0) {
        close(read_fd);
    }
#endif
    // if there is an error code, exit with status 1
    return (rc != 0 ? 1 : 0);
}

// ================================================================
// Startup sequence over OCL

uint32_t ocl_client_control  = 1;
uint32_t ocl_client_UART     = 2;
uint32_t ocl_client_debugger = 3;

uint32_t control_addr_verbosity   = 0x4;
uint32_t control_addr_tohost      = 0x8;
uint32_t control_addr_ddr4_loaded = 0xc;

int start_hw (int slot_id, int pf_id, int bar_id)
{
    int rc;
    uint32_t ocl_addr, ocl_data;

    // pci_bar_handle_t is a handler for an address space exposed by
    // one PCI BAR on one of the PCI PFs of the FPGA
    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

    // attach to the fpga, with a pci_bar_handle out param
    // To attach to multiple slots or BARs, call this function multiple times,
    // saving the pci_bar_handle to specify which address space to interact with in
    // other API calls.
    // This function accepts the slot_id, physical function, and bar number

#ifndef SV_TEST
    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, & pci_bar_handle);
    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
#endif

    // ----------------
    // Set up CPU verbosity and logdelay
    uint32_t verbosity = 1;
    uint32_t logdelay  = 0;    // # of instructions after which to set verbosity
    fprintf (stdout, "Host_side: verbosity = %0d, logdelay = %0d\n", verbosity, logdelay);

    ocl_addr = (ocl_client_control << 16 | control_addr_verbosity);
    ocl_data = ((logdelay & 0xFFFFFFF0) | (verbosity & 0xF));
    rc       = fpga_pci_poke (pci_bar_handle, ocl_addr, ocl_data);
    fail_on (rc, out, "ERROR: %s: Unable to write to OCL port.\n", this_file_name);

    // ----------------
    // Set up 'watch tohost' and 'tohost addr'
    bool     watch_tohost = true;
    uint32_t tohost_addr  = 0x80001000;    // Convention: misaligned if not watching tohost
    fprintf (stdout, "Host_side: watch_tohost = %0d, tohost_addr = 0x%0x\n",
	     watch_tohost, tohost_addr);

    ocl_addr = (ocl_client_control << 16 | control_addr_tohost);
    ocl_data = tohost_addr;
    rc = fpga_pci_poke (pci_bar_handle, ocl_addr, ocl_data);
    fail_on (rc, out, "ERROR: %s: Unable to write to OCL port.\n", this_file_name);

    // ----------------
    // Go! Inform hw that DDR4 is loaded, allow the CPU to access it

    fprintf (stdout, "Host_side: Sending DDR4 Loaded message\n");
    ocl_addr = (ocl_client_control << 16 | control_addr_ddr4_loaded);
    ocl_data = tohost_addr;
    rc = fpga_pci_poke (pci_bar_handle, ocl_addr, ocl_data);
    fail_on (rc, out, "ERROR: %s: Unable to write to OCL port.\n", this_file_name);

    // ----------------
    // Poll the HW status until non-zero
    ocl_addr = (ocl_client_control << 16 | 0);
    uint32_t hw_status;

    while (true) {
	rc = fpga_pci_peek (pci_bar_handle, ocl_addr, & hw_status);
	fail_on(rc, out, "Unable to read read from the fpga !");
	if (hw_status != 0) break;
	usleep (1);
    }
    fprintf (stdout, "%s: Final HW status 0x%0x\n", this_file_name, hw_status);
    if (hw_status == 1) {
	fprintf (stdout, "    (Non-zero write tohost)\n");
    }
    else if (hw_status == 2) {
	fprintf (stdout, "    (Memory system error)\n");
    }

out:
    // clean up
    if (pci_bar_handle >= 0) {
        rc = fpga_pci_detach(pci_bar_handle);
        if (rc) {
            printf("Failure while detaching from the fpga.\n");
        }
    }

    // if there is an error code, exit with status 1
    return (rc != 0 ? 1 : 0);
}

// ================================================================
