Communication between host-side software and FPGA-side hardware on AWS
involves:

    - AXI4 transactions on the DMA PCIS interface
    - AXI4-Lite transactions on the OCL interface
    - (possibly more channels in future)

Transactions on these interfaces are invoked from a high-level API in
host-side C code.

In this directory we invoke a tool to generate marshalling/
unmarshalling code for the various AXI4 and AXI4-Lite interfaces so
that the hardware-side BSV interfaces can be invoked remotely from
host-side C.

For example, host-side C code can 'enqueue' an AXI4 RD_ADDR request
struct, which is transported to the FPGA side and delivered to the
AXI4 RD_ADDR channel on the FPGA-side DMA PCIS interface.  The AXI4
RD_RESP channel response from the FPGA-side DMA PCI interface is
transported back to the host-side, and can be 'dequeued' by host-side
C code.
