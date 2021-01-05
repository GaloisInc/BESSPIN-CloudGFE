This directory contains a generator to produce support code for being
able to run an AWS setup in simulation, i.e., with host-side software
interacting with a simulation of the FPGA-side BSV/RTL code.

This is an alternative simulation flow to the standard AWS simulation
flow which:
  (a) appears rather complicated;
  (b) appears to have long build times, hampering development iteration;
  (c) uses Amazon/Xilinx bus-functional models for the SH and
      Amazon/Xilinx models for DDRs;
  (d) uses encrypted IP for (c);
  (e) seems to run in a single Unix process, making it difficult to
        debug the host-side and FPGA-side separately;
  (f) Cannot use Verilator because of non-synthesizable RTL in (c) and
        encrypted IP in (d).
  (g) etc.

We only mention Bluesim below, but essentially the same thing will
work for Verilator simulation or any other RTL simulator.

Communication between host-side software and FPGA-side hardware on AWS
involves:

    - AXI4 transactions on the SH-CL DMA PCIS interface
    - AXI4-Lite transactions on the SH-CL OCL interface
    - (there are more SH-CL interfaces; we may add them in future)

The programming model is:

- Host-side C code behaves as a virtual 'master' on these interfaces.
    C code does library API calls to send/receive on the five AXI
    channels (wraddr, wrdata, rdaddr, wresp, rdata), using convenient
    C structs to represent the AXI4 and AXI4-Lite payloads.

- These payloads are delivered/retrieved from the corresponding
    hardware interfaces in the AWS CL. There is no intermediate
    'interpretation' of these payloads; they are delivered/retrieved
    'as is', i.e., it is up to the C app code to produce and consume
    these AXI payloads according to standard AXI protocols.

In simulation, we run the host-side software and Bluesim as two
separate Unix processes; currently they communicate over TCP, but we
could also use PTYs, Unix socket, etc.

The generator here, given a spec of the AXI payloads, produces code to:

- Offer separate queue interfaces for each AXI channel, where C and
    BSV code can enqueue and dequeue payloads using convenient C or
    BSV structs.
- Internally, convert these AXI payloads from C and BSV structs into
    byte vectors ('bytevecs') and back
- Manage credits for a credit-based flow-control scheme for
    communicating these byte vectors, allowing streaming (pipelined)
    delivery of payloads.
- Offer simple queue interfaces for bytevecs, so that a simple
    mechanism (such as read()/write() on a TCP socket) can provide the
    necessary transport between the processes.

Note 1: Since the AWS SH-CL interfaces are fixed, We do not expect to
have to re-run this tool unless we add more SH-CL interfaces.

Note 2: This is snapshot of a general-purpose and still-evolving
'Gen_Bytevec_Mux' facility that has wider uses than the usage here for
AWS host-side to FPGA-side communication (it can be used for many
kinds of C/RTL inter-language working).  Since that tool is
continuously evolving, we take a snapshot here, for stability.  Please
see the README in that tool's repo for more technical detail.
