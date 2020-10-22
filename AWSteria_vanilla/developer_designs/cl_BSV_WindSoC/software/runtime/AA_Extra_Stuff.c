#include "Memhex_read.h"

static const char this_file_name [] = "test_dram_dma_hwsw_cosim.c";

// ----------------
// Forward decls of functions

int peek_poke_example(uint32_t value, int slot_id, int pf_id, int bar_id);
int load_mem_hex32_using_DMA (int slot_id, char *filename);
int debug_server (int slot_id, int pf_id, int bar_id);


// In main

    // Load a MemHex file
    rc = load_mem_hex32_using_DMA (slot_id, "Mem.hex32");
    fail_on (rc, out, "Load mem hex failed");





// ================================================================
// Peek-poke example (from test_hello_world.c)

#define TEST_ADDR UINT64_C(0x500)

/*
 * An example to attach to an arbitrary slot, pf, and bar with register access.
 */
int peek_poke_example(uint32_t value, int slot_id, int pf_id, int bar_id) {
    int rc;
    /* pci_bar_handle_t is a handler for an address space exposed by one PCI BAR on one of the PCI PFs of the FPGA */

    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

    
    /* attach to the fpga, with a pci_bar_handle out param
     * To attach to multiple slots or BARs, call this function multiple times,
     * saving the pci_bar_handle to specify which address space to interact with in
     * other API calls.
     * This function accepts the slot_id, physical function, and bar number
     */
#ifndef SV_TEST
    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
#endif
    
    /* write a value into the mapped address space */
    printf("Writing 0x%08x to addr 0x%016lx\n", value, TEST_ADDR);
    rc = fpga_pci_poke(pci_bar_handle, TEST_ADDR, value);

    fail_on(rc, out, "Unable to write to the fpga !");

    /* read it back and print it out; should be the same as the value written */
    printf("Reading from addr 0x%016lx\n", TEST_ADDR);
    uint32_t expected = value;
    rc = fpga_pci_peek(pci_bar_handle, TEST_ADDR, &value);
    fail_on(rc, out, "Unable to read read from the fpga !");
    printf("    ==> 0x%x\n", value);
    if(value == expected) {
        printf("OCL PEEK-POKE TEST PASSED: ");
        printf("Resulting value matched expected value 0x%x. It worked!\n", expected);
    }
    else{
        printf("OCL PEEK-POKE TEST FAILED: ");
        printf("Resulting value did not match expected value 0x%x. Something didn't work.\n", expected);
    }
out:
    /* clean up */
    if (pci_bar_handle >= 0) {
        rc = fpga_pci_detach(pci_bar_handle);
        if (rc) {
            printf("Failure while detaching from the fpga.\n");
        }
    }

    /* if there is an error code, exit with status 1 */
    return (rc != 0 ? 1 : 0);
}

// ================================================================
// Debug server
// Connects over a TCP socket to a debug client, such a DSharp or GDB

static const uint16_t dmi_default_tcp_port = 30000;

static const uint8_t dmi_status_err     = 0;
static const uint8_t dmi_status_ok      = 1;
static const uint8_t dmi_status_unavail = 2;

static const uint8_t dmi_op_read          = 1;
static const uint8_t dmi_op_write         = 2;
static const uint8_t dmi_op_shutdown      = 3;
static const uint8_t dmi_op_start_command = 4;

int debug_server (int slot_id, int pf_id, int bar_id)
{
    int rc;
    uint8_t status;
    int verbosity = 0;

    /* pci_bar_handle_t is a handler for an address space exposed by one PCI BAR on one of the PCI PFs of the FPGA */
    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

    /* attach to the fpga, with a pci_bar_handle out param
     * To attach to multiple slots or BARs, call this function multiple times,
     * saving the pci_bar_handle to specify which address space to interact with in
     * other API calls.
     * This function accepts the slot_id, physical function, and bar number
     */
#ifndef SV_TEST
    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
#endif

    fprintf (stdout, "%s: Connecting to debugger\n", this_file_name);
    status = c_debug_client_connect (dmi_default_tcp_port);
    if (status != dmi_status_ok) {
	fprintf (stdout, "ERROR: %s: error opening debug client connection.\n", this_file_name);
	fprintf (stdout, "    Aborting.\n");
	return 1;
    }
    while (true) {
	uint64_t  req = c_debug_client_request_recv (0xAA);
	          status  = ((req >> 56) & 0xFF);
	uint32_t  data    = ((req >> 24) & 0xFFFFFFFF);
	uint16_t  dm_addr = ((req >> 8)  & 0xFFFF);    // DM register addr
	uint8_t   op      = ((req >> 0)  & 0xFF);

	// Convert DM register addr to an AXI4L byte address (4 bytes per DM register)
	uint32_t  axi4L_addr = (dm_addr << 2);

	if (status == dmi_status_err) {
	    fprintf (stdout, "ERROR: %s: receive error; aborting.\n", this_file_name);
	    return 1;
	}

	else if (status == dmi_status_ok) {
	    if (verbosity != 0)
		fprintf (stdout, "%s: received a request\n", this_file_name);
	    if (op == dmi_op_read) {
		if (verbosity != 0)
		    fprintf (stdout, "%s: OCL READ dm_addr 0x%0x (OCL addr 0x%0x)\n",
			     this_file_name, dm_addr, axi4L_addr);
		rc = fpga_pci_peek (pci_bar_handle, axi4L_addr, & data);
		fail_on (rc, out, "ERROR: %s: Unable to read from OCL addr.\n",
			 this_file_name, axi4L_addr);
		if (verbosity != 0)
		    fprintf (stdout, "%s: OCL READ dm_addr 0x%0x => 0x%0x; sending response\n",
			     this_file_name, dm_addr, data);
		status = c_debug_client_response_send (data);
		if (status == dmi_status_err) {
		    fprintf (stdout, "ERROR: %s: send error; aborting.\n", this_file_name);
		    return 1;
		}
	    }
	    else if (op == dmi_op_write) {
		if (verbosity != 0)
		    fprintf (stdout, "%s: OCL WRITE dm_addr 0x%0x (OCL addr 0x%0x) data 0x%0x\n",
			     this_file_name, dm_addr, axi4L_addr, data);
		rc = fpga_pci_poke (pci_bar_handle, axi4L_addr, data);
		fail_on (rc, out, "ERROR: %s: Unable to write to OCL port.\n", this_file_name);
	    }
	    else if (op == dmi_op_shutdown) {
		fprintf (stdout, "%s: SHUTDOWN\n", this_file_name);
		return 0;
	    }
	    else if (op == dmi_op_start_command) {    // For debugging only
		if (verbosity != 0)
		    fprintf (stdout, "%s: START COMMAND ================================\n",
			     this_file_name);
	    }
	    else {
		if (verbosity != 0) {
		    fprintf (stdout, "ERROR: %s:  Unrecognized op %0d; ignoring\n",
			     this_file_name, op);
		    fprintf (stdout, "    Received word is: 0x%0lx\n", req);
		}
	    }
	}
	else { // (status == dmi_status_unavail)
	    usleep (1000);
	}
    }
    return 0;

out:
    /* clean up */
    if (pci_bar_handle >= 0) {
        rc = fpga_pci_detach(pci_bar_handle);
        if (rc) {
            printf("Failure while detaching from the fpga.\n");
        }
    }

    /* if there is an error code, exit with status 1 */
    return (rc != 0 ? 1 : 0);
}

// ================================================================
