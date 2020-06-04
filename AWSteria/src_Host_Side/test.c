#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <malloc.h>
#include <poll.h>

#include <inttypes.h>
#include <stdbool.h>

#include "test_dram_dma_common.h"
#include "AWS_Sim_Lib.h"

#include "SimpleQueue.c"

#define MEM_16G              (1ULL << 34)

void usage(const char* program_name);
int dma_example_hwsw_cosim(int slot_id, size_t buffer_size);

static inline int do_dma_read(int fd, uint8_t *buffer, size_t size,
    uint64_t address, int channel, int slot_id);
static inline int do_dma_write(int fd, uint8_t *buffer, size_t size,
    uint64_t address, int channel, int slot_id);

// ****************************************************************

static const char this_file_name [] = "test.c";

#include "Memhex32_read.h"

int start_hw ();

int load_mem_hex32_using_DMA (int slot_id, char *filename);

// ****************************************************************

int main(int argc, char **argv)
{
    size_t buffer_size;
    buffer_size = 128;
    fprintf (stdout, "buffer_size = 0x%0lx (%0ld) bytes\n", buffer_size, buffer_size);

    QueueInit(); // for console input

    int rc;
    int slot_id = 0;

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

    AWS_Sim_Lib_init ();

    // ================================================================
    // Exercise the DMA to see if it's working

    rc = dma_example_hwsw_cosim (slot_id, buffer_size);
    if (rc != 0) {
	fprintf (stdout, "DMA example failed");
	goto out;
    }

    // ================================================================
    // AWSteria code

    // TODO: get the filename from command-line args/config file/...
    // char memhex32_filename [] = "Mem.hex";
    char memhex32_filename[] = "Mem.hex";

    rc = load_mem_hex32_using_DMA (slot_id, memhex32_filename);
    if (rc != 0) {
	fprintf (stdout, "Loading the mem hex32 file failed\n");
	goto out;
    }

    // ================================================================
    // AWSteria code

    // Start the hardware
    rc = start_hw ();
    if (rc != 0) {
	fprintf (stdout, "starting the HW failed");
	goto out;
    }

    // ================================================================

out:

    if (rc != 0) {
        fprintf (stdout, "TEST FAILED\n");
    }
    else {
        fprintf (stdout, "TEST PASSED\n");
    }

    AWS_Sim_Lib_shutdown ();
}

void usage(const char* program_name) {
    printf("usage: %s [--slot <slot>]\n", program_name);
}

// ================================================================

/**
 * Write 4 identical buffers to the 4 different DRAM channels of the AFI
 */
int dma_example_hwsw_cosim(int slot_id, size_t buffer_size)
{
    int write_fd, read_fd, dimm, rc;

    write_fd = -1;
    read_fd = -1;

    fprintf (stdout, "buffer_size = 0x%0lx (%0ld) bytes\n", buffer_size, buffer_size);

    uint8_t *write_buffer = malloc(buffer_size);
    uint8_t *read_buffer = malloc(buffer_size);
    if (write_buffer == NULL || read_buffer == NULL) {
        rc = -ENOMEM;
        goto out;
    }
    fprintf (stdout, "Write- and read-buffer size: %0ld\n", buffer_size);

    printf("Memory has been allocated, initializing DMA and filling the buffer...\n");
    printf("filling buffer with  random data...\n") ;

    // TODO: restore random fill after debugging
    // rc = fill_buffer_urandom(write_buffer, buffer_size);
    for (int j = 0; j < buffer_size; j++)
	write_buffer [j] = j;
    rc = 0;
    if (rc != 0) {
	fprintf (stdout, "unable to initialize buffer");
	goto out;
    }

    fprintf (stdout, "First 64 bytes of write-buffer contents:\n");
    for (int j = 0; j < 64; j = j + 4) {
	uint32_t *p = (uint32_t *) (write_buffer + j);
	fprintf (stdout, "    %08x: %08x\n", j, *p);
    }

    printf("Now performing the DMA transactions...\n");
    // Temporarily reduced limit from DIMM 3 to DIMM 2 because DIMM 3 DMA shows errors
    for (dimm = 0; dimm < 4; dimm++) {
	fprintf (stdout, "----------------------------------------------------------------\n");
        fprintf (stdout, "DMA'ing buffer of %0ld bytes to DIMM %0d\n", buffer_size, dimm);
        rc = do_dma_write(write_fd, write_buffer, buffer_size,
            dimm * MEM_16G, dimm, slot_id);
	if (rc != 0) {
	    fprintf (stdout, "DMA write failed on DIMM: %d\n", dimm);
	    goto out;
	}
    }

    bool passed = true;
    // Temporarily reduced limit from DIMM 3 to DIMM 2 because DIMM 3 DMA shows errors
    for (dimm = 0; dimm < 4; dimm++) {
	fprintf (stdout, "----------------------------------------------------------------\n");
        fprintf (stdout, "DMA'ing buffer of %0ld bytes from DIMM %0d\n", buffer_size, dimm);
        rc = do_dma_read(read_fd, read_buffer, buffer_size,
            dimm * MEM_16G, dimm, slot_id);
	if (rc != 0) {
	    fprintf (stdout, "DMA read failed on DIMM: %d\n", dimm);
	    goto out;
	}

        fprintf (stdout, "Comparing %0ld bytes buffers for DIMM %0d\n", buffer_size, dimm);
        uint64_t differ = buffer_compare (read_buffer, write_buffer, buffer_size);
        if (differ != 0) {
	    fprintf (stdout, "DIMM %d failed with %lu bytes which differ\n", dimm, differ);
            passed = false;
        } else {
	    fprintf (stdout, "DIMM %d passed!\n", dimm);
        }
    }
    rc = (passed) ? 0 : 1;

out:
    if (write_buffer != NULL) {
        fprintf (stdout, "Freeing write_buffer\n");
        free(write_buffer);
    }
    if (read_buffer != NULL) {
        fprintf (stdout, "Freeing read_buffer\n");
        free(read_buffer);
    }
#if !defined(SV_TEST)
    if (write_fd >= 0) {
        fprintf (stdout, "Closing write_fd\n");
        close(write_fd);
    }
    if (read_fd >= 0) {
        fprintf (stdout, "Closing read_fd\n");
        close(read_fd);
    }
#endif
    /* if there is an error code, exit with status 1 */
    return (rc != 0 ? 1 : 0);
}

static inline int do_dma_read (int fd, uint8_t *buffer, size_t size,
    uint64_t address, int channel, int slot_id)
{
    return fpga_dma_burst_read (fd, buffer, size, address);
}

static inline int do_dma_write (int fd, uint8_t *buffer, size_t size,
    uint64_t address, int channel, int slot_id)
{
    return fpga_dma_burst_write (fd, buffer, size, address);
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
	fprintf (stdout, "%s: ERROR allocating memhex buffer of size: %0lld (0x%0llx)\n",
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
	if (chunk_size > 0x80) chunk_size = 0x80;    // Trimmed to 4KB if nec'y

	// Copy data to DMA buffer
	memcpy (dma_buf, & (buf [addr1]), chunk_size);

	// DMA it
	fprintf (stdout, "%s: DMA %0d bytes to addr 0x%0lx\n", this_file_name, chunk_size, addr1);
	rc = do_dma_write (write_fd, dma_buf, chunk_size, addr1, channel, slot_id);
	if (rc != 0) {
	    fprintf (stdout, "DMA write failed on channel 0\n");
	    goto out;
	}
	addr1 += chunk_size;
    }

    // ================
    // Readback up to 128 bytes and cross-check
    size_t read_size = ((download_size <= 128) ? download_size : 128);
    fprintf (stdout, "Reading back %0ld bytes to spot-check the download\n", read_size);
    addr1 = ((addr_base >> 6) << 6);    // 64B aligned (required by AWS)
    rc = do_dma_read (read_fd, dma_buf, read_size, addr1, channel, slot_id);
    if (rc != 0) {
	fprintf (stdout, "DMA read failed on channel 0");
	goto out;
    }

    fprintf (stdout, "Checking readback-data of %0ld bytes ...\n", read_size);
    for (uint64_t j = 0; j < read_size; j += 4) {
	uint32_t *p1 = (uint32_t *) (buf + addr1 + j);
	uint32_t *p2 = (uint32_t *) (dma_buf + j);
	if (*p1 != *p2) {
	    fprintf (stdout, "%s: read-back of mem data differs at addr %0lx\n", this_file_name, j);
	    fprintf (stdout, "    Original  word: 0x%08x\n", *p1);
	    fprintf (stdout, "    Read-back word: 0x%08x\n", *p2);
	    rc = 1;
	    goto out;
	}
	fprintf (stdout, "    %08lx: %08x\n", j, *p1);
    }
    fprintf (stdout, "Checking readback-data of %0ld bytes: OK\n", read_size);

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

// Address configurations for host-to-hw and hw-to-host channels.

// Each channel is at an 8-byte-aligned address.
// So, channel id = offset [31:3]
// where offset   = addr - addr_base.

// For channel addr A, we interpret addr A+1 as a 'status' address.
// For hw-to-host channel addr A,
//    reading A   => dequeued data (if available, else undefined value)
//    reading A+4 => 'notEmpty' status    (dequeue will return data)
// For host-to-hw channel addr A,
//    reading A+4 => 'notFull'  status    (enq will succeed)
//    writing A   => enq data

// Channels in each direction are independent (an application may
// choose to interpret a pair as request/response).  The number of
// channels in each direction need not be the same.

uint32_t ocl_hw_to_host_chan_addr_base = 0x00000000;
uint32_t ocl_host_to_hw_chan_addr_base = 0x00001000;

uint32_t host_to_hw_chan_control      = 0;
uint32_t host_to_hw_chan_UART         = 1;
uint32_t host_to_hw_chan_mem_rsp      = 2;
uint32_t host_to_hw_chan_debug_module = 3;
uint32_t host_to_hw_chan_interrupt    = 4;

uint32_t hw_to_host_chan_status       = 0;
uint32_t hw_to_host_chan_UART         = 1;
uint32_t hw_to_host_chan_mem_req      = 2;
uint32_t hw_to_host_chan_debug_module = 3;

uint32_t mk_chan_status_addr (uint32_t addr_base, uint32_t chan)
{
    return (((addr_base & 0xFFFFFFFC) + (chan << 3)) | 0x4);
}

uint32_t mk_chan_data_addr (uint32_t addr_base, uint32_t chan)
{
    return (((addr_base & 0xFFFFFFFC) + (chan << 3)) | 0x0);
}

// ================
// This function tests a channel's status.
//     Function result is 0 if ok, 1 if error
//     If ok, 'p_status' result is 1 if 'notEmpty' (hw-to-host
//     channel) or 'notFull' (host-to-hw channel), and 0 otherwise.

int test_for_chan_avail (uint32_t ocl_addr_base, uint32_t chan,  uint32_t *p_status)
{
    int       verbosity = 0;
    int       rc;
    uint32_t  ocl_addr  = mk_chan_status_addr (ocl_addr_base, chan);

    rc = fpga_pci_peek (ocl_addr, p_status);
    if (verbosity != 0)
	fprintf (stdout, "    test_for_chan_avail: chan %0d, peek rc = %0d data = %08x\n",
		 chan, rc, *p_status);
    if (rc != 0) {
	fprintf (stdout, "ERROR: %s: test_for_chan_avail: OCL peek chan %0d.\n",
		 this_file_name, chan);
	goto out;
    }

 out:
    if (rc != 0) {
	fprintf (stdout, "    addr_base %0x chan %0d\n", ocl_addr_base, chan);
    }
    return rc;
}

// ================
// This function reads a channel's status in a loop, waiting for a 1 (notEmpty/notFull).
// (times out after 1000 usecs).

int wait_for_chan_avail (uint32_t ocl_addr_base, uint32_t chan)
{
    int verbosity = 0;

    uint32_t ocl_addr = mk_chan_status_addr (ocl_addr_base, chan);
    uint32_t ocl_data_from_hw;
    uint32_t usecs = 0;
    int rc;

    while (true) {
	rc = test_for_chan_avail (ocl_addr_base, chan, & ocl_data_from_hw);
	if (rc != 0) {
	    fprintf (stdout, "ERROR: %s: wait_for_chan_avail %0d.\n",
		     this_file_name, chan);
	    goto out;
	}

	if (ocl_data_from_hw == 1) break;

	usleep (1);
	usecs++;
	if (usecs > 100000) {
	    fprintf (stdout, "ERROR: %s: wait_for_chan_avail: timeout: chan %0d, waited %0d usecs\n",
		     this_file_name, chan, usecs);
	    rc = 1;
	    goto out;
	}
        else if (usecs % 10000 == 0) {
	  fprintf (stdout, "%s: wait_for_chan_avail: polled chan %0d for %0d usecs\n",
		   this_file_name, chan, usecs);
	}
    }
    rc = 0;
    if (verbosity != 0)
	fprintf (stdout, "%s: wait_for_chan_avail: ok: chan %0d, waited %0d usecs\n",
		 this_file_name, chan, usecs);

 out:
    if (rc != 0) {
	fprintf (stdout, "    addr_base %0x chan %0d\n", ocl_addr_base, chan);
    }
    return rc;
}

int start_hw (void)
{
    int rc, verbosity = 1;
    uint32_t ocl_addr, ocl_data_to_hw, ocl_data_from_hw;

    // ----------------
    // Set up CPU verbosity and logdelay
    uint32_t cpu_verbosity = 1;
    uint32_t logdelay      = 0;    // # of instructions after which to set verbosity
    fprintf (stdout, "Host_side: set verbosity = %0d, logdelay = %0d\n", cpu_verbosity, logdelay);

    rc = wait_for_chan_avail (ocl_host_to_hw_chan_addr_base, host_to_hw_chan_control);
    if (rc != 0) goto out;

    ocl_addr = mk_chan_data_addr (ocl_host_to_hw_chan_addr_base, host_to_hw_chan_control);
    // { 24'h_log_delay, 6'h_verbosity, 2'b01 }
    ocl_data_to_hw = ((logdelay << 24) | (cpu_verbosity << 2) | 0x1);
    if (verbosity != 0)
	fprintf (stdout, "    OCL write addr %08x data %08x\n", ocl_addr, ocl_data_to_hw);
    rc = fpga_pci_poke (ocl_addr, ocl_data_to_hw);
    if (rc != 0) {
	fprintf (stdout, "ERROR: %s: Unable to write to OCL port.\n", this_file_name);
	goto out;
    }

    // ----------------
    // Set up 'watch tohost' and 'tohost addr'
    bool     watch_tohost = true;
    uint32_t tohost_addr  = 0xbffff000;    // Convention: misaligned if not watching tohost
    // uint32_t tohost_addr  = 0x80001000;    // Convention: misaligned if not watching tohost
    fprintf (stdout, "Host_side: set watch_tohost = %0d, tohost_addr = 0x%0x\n",
	     watch_tohost, tohost_addr);

    rc = wait_for_chan_avail (ocl_host_to_hw_chan_addr_base, host_to_hw_chan_control);
    if (rc != 0) goto out;

    ocl_addr = mk_chan_data_addr (ocl_host_to_hw_chan_addr_base, host_to_hw_chan_control);
    // { 30'h_to_host_addr_W, 2'b11 }
    ocl_data_to_hw = (tohost_addr | 0x3);
    if (verbosity != 0)
	fprintf (stdout, "    OCL write addr %08x data %08x\n", ocl_addr, ocl_data_to_hw);
    rc = fpga_pci_poke (ocl_addr, ocl_data_to_hw);
    if (rc != 0) {
	fprintf (stdout, "ERROR: %s: Unable to write to OCL port.\n", this_file_name);
	goto out;
    }

    // ----------------
    // Go! Inform hw that DDR4 is loaded, allow the CPU to access it

    fprintf (stdout, "Host_side: send 'DDR4 Loaded' message, allowing CPU to access DDR4\n");

    rc = wait_for_chan_avail (ocl_host_to_hw_chan_addr_base, host_to_hw_chan_control);
    if (rc != 0) goto out;

    ocl_addr       = mk_chan_data_addr (ocl_host_to_hw_chan_addr_base, host_to_hw_chan_control);
    ocl_data_to_hw = 0x0;
    if (verbosity != 0)
	fprintf (stdout, "    OCL write addr %08x data %08x\n", ocl_addr, ocl_data_to_hw);
    rc = fpga_pci_poke (ocl_addr, ocl_data_to_hw);
    if (rc != 0) {
	fprintf (stdout, "ERROR: %s: Unable to write to OCL port.\n", this_file_name);
	goto out;
    }

    // ----------------
    // Poll the HW:
    //  - for status non-zero (hw task completion)
    //  - for UART output (and relay it to the console screen)
    // There's no timeout here because HW may never stop (e.g., an executing CPU).

    fprintf (stdout, "Host_side: Starting polling loop\n");


    while (true) {
      uint32_t chan_status, uart_data_from_hw;

      // hw_to_host_chan_status
      ocl_addr = mk_chan_data_addr (ocl_hw_to_host_chan_addr_base, hw_to_host_chan_status);
      rc = test_for_chan_avail (ocl_hw_to_host_chan_addr_base, hw_to_host_chan_status, &chan_status);
      if (rc != 0) goto out;

      if (chan_status != 0) {
	rc = fpga_pci_peek (ocl_addr, & ocl_data_from_hw);
	if (rc != 0) {
	  fprintf (stdout, "Unable to read read from the fpga !");
	  goto out;
	}

	if ((ocl_data_from_hw) & 0xFF != 0) break;
      }

      // ----------------
      // hw_to_host_chan_UART
      ocl_addr = mk_chan_data_addr (ocl_hw_to_host_chan_addr_base, hw_to_host_chan_UART);
      rc = test_for_chan_avail (ocl_hw_to_host_chan_addr_base, hw_to_host_chan_UART, & chan_status);
      if (rc != 0) goto out;
      if (chan_status == 1) {
	// Byte is available from UART
	rc = fpga_pci_peek (ocl_addr, & uart_data_from_hw);
	if (rc != 0) {
	  fprintf (stdout, "ERROR: fpga_pci_peek (ocl_addr %0x) failed\n", ocl_addr);
	  goto out;
	}
	// OK: received a char from hw; echo to console screen
	uart_data_from_hw = (uart_data_from_hw & 0xFF);
	if (verbosity > 1 )
	  fprintf (stdout, "    OCL UART read addr %08x, data %02x\n", ocl_addr, ocl_data_from_hw);
	else
	  putchar (uart_data_from_hw);
	fflush (stdout);
      }

      // ----------------
      // host_to_hw_chan_UART
      ocl_addr = mk_chan_data_addr (ocl_host_to_hw_chan_addr_base, host_to_hw_chan_UART);
      rc = test_for_chan_avail (ocl_host_to_hw_chan_addr_base, host_to_hw_chan_UART, & chan_status);
      if (rc != 0) goto out;

      if (chan_status != 0 && !QueueEmpty()) {
	// Byte is available for UART, and space available in channel
	int ch;
	QueueGet(&ch);
	rc = fpga_pci_poke (ocl_addr, ch);
	if (rc != 0) {
	  fprintf (stdout, "ERROR: fpga_pci_poke (ocl_addr %0x) failed\n", ocl_addr);
	  goto out;
	}
      }

      // ----------------
      // Input from console
      int stdin_fd = 0;
      int fd_max = -1;
      fd_set rfds,  wfds, efds;
      int delay = 10; // ms
      struct timeval tv;

      FD_ZERO(&rfds);
      FD_ZERO(&wfds);
      FD_ZERO(&efds);
      FD_SET(stdin_fd, &rfds);
      fd_max = stdin_fd;

      tv.tv_sec = delay / 1000;
      tv.tv_usec = (delay % 1000) * 1000;
      int ret = select(fd_max + 1, &rfds, &wfds, &efds, &tv);
      if (FD_ISSET(stdin_fd, &rfds)) {
	// Read from stdin and enqueue for HTIF/UART get char
	char buf[128];
	memset(buf, 0, sizeof(buf));
	int ret = read(0, buf, sizeof(buf));
	for (int i=0; i < ret; i++) {
	  QueuePut(buf[i]);
	}
      }

    }
    fprintf (stdout, "%s: Final HW status 0x%0x\n", this_file_name, ocl_data_from_hw);
    if (ocl_data_from_hw == 1) {
	fprintf (stdout, "    (Non-zero write tohost)\n");
    }
    else if (ocl_data_from_hw == 2) {
	fprintf (stdout, "    (Memory system error)\n");
    }

out:

    // if there is an error code, exit with status 1
    return (rc != 0 ? 1 : 0);
}

// ================================================================
