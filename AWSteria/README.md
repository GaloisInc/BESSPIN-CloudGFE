AWSteria
========

----------------------------------------------------------------

Introduction
------------

AWSteria is a framework to support a version of the RISC-V SoCs on the
Amazon AWS-FPGA platform.  The RISC-V CPUs and SoCs already exist,
running on host Linux machines with attached FPGA boards.  This is an
adaption of those systems for Amazon AWS.

This is a minimalist approach, starting with the standard worked
examples provided by Amazon in the aws-fpga repo, in particular the
`cl_hello_world` and the `cl_dram_dma` examples which, between them,
exercise AWS' `DMA_PCIS` and `OCL` interfaces.  `DMA_PCIS` is a
high-bandwidth interface (AXI4, 512-bit wide data bus, burst support,
with AWS-provided DMA support).  `OCL` is an AXI4-Lite interface (no
bursts) with 32-bit data buses.

Starting with these example, we make incremental and minimal changes
to "substitute" our design in place of theirs.  We do not touch their
Makefiles and scripts, other than editing the manifests of the C and
Verilog files to be included in the build.  We do not rely on any new
tooling.  The incremental changes are described in a series of figures
in the `Doc/` directory,
[Fig 1](Doc/Fig_1_Build_Run_AWS_Example.png),
[Fig 2](Doc/Fig_2_AWS_BSV_XSim_Test.png),
[Fig 3](Doc/Fig_3_AWS_BSV_XSim_WindSoC.png),
[Fig 3 detail](Doc/Fig_3_Detail.png), and
[Fig 4](Doc/Fig_4_Debugger.png)

About the name "AWSsteria": pronounced like the Italian word "Osteria"
which is a tavern or pub. "AWS" of course is from "Amazon AWS".
"AWSteria" can also be seen as a new word meaning a workplace or
studio where one develops AWS apps.  It also suggests "austere", being
a minimalist approach using no other tools.

----------------------------------------------------------------
Example to build-and-run out of the box
---------------------------------------

We provide an example to build and run the structure shown in [Fig
3](Doc/Fig_3_AWS_BSV_XSim_WindSoC.png) in the `Doc/` directory.  The
"C Tests" code reads a Mem-hex32 file containing the code for the
RISC-V ISA test `rv64ui-p-add`, and DMAs it into DDR A via the
`DMA_PCIS` high-bandwidth bus.  Then it talks over the `OCL` bus to
the SoC, allowing it to access memory (until then the Flute CPU is
stalled trying to fetch an instruction).  The CPU then executes the
ISA test to completion.  The C code continually polls the SoC over the
`OCL` bus until it hears that the test is completed, and finally
exits.

There are four "flows" you can use to build-and-run the example. Each
is described in a Makefile-as-document in the `Doc/` directory (the
Makefiles describes each step separately; you are welcome to script
them as you wish):

1. Bluesim simulation
    - See `Doc/Makefile_Bluesim.mk`

2. Verilator simulation
    - (NOT AVAILABLE YET. Expected soon)

3. Standard AWS flow for XSIM (Xilinx simultor) simulation
    - See `Doc/Makefile_XSIM.mk`

4. Standard AWS flow for FPGA
    - See `Doc/Makefile_AFI_build.mk`
        - To compile and build the AFI (Amazon FPGA Instance)
    - See `Doc/Makefile_AFI_run.mk`
        - To deploy and run on an Amazon AWS FPGA-attached machine.

It is expected that (1) and (2) will be most heavily used for rapid
development iteration.  Then, use (3) to sanity-check that it runs in
the standard XSIM flow.  Then use (4) to build and run for FPGA.

----------------------------------------------------------------

A Tour of the Code
------------------

The directory tree looks like this:

            .
            ├── builds
            │   ├── Resources
            │   │   └── Verilator_resources
            │   ├── RV64ACDFIMSU_Flute_bluesim_AWS
            │   └── RV64ACDFIMSU_Flute_verilator_AWS
            │       └── Verilog_RTL
            ├── developer_designs
            ├── Doc
            ├── README.md
            ├── src_Host_Side
            └── src_Testbench_AWS
                ├── SoC
                └── Top
                    └── Gen_Bytevec

This repo contains no Piccolo/Flute/Toooba code at all.  Those are
used unmodified from their original repositories (including
caches/MMUs, Debug Module, PLIC, Tandem Verifation trace generator,
Near\_Mem\_IO (a.k.a. CLINT), system AXI4 fabric, Boot ROM, and UART).
Here we are just surrounding that with a different connection to
memory (AWS DDR4), and different connections for the Debug Module and
UART (AWS OCL port), and providing a fast back-door for loading the
DDR4s (AWS DMA\_PCIS port).

Directory `Doc` has a number of Makefiles describing the four major
flows: Bluesim, Verilator, XSIM and FPGA.

Directory `Doc` also has a number of diagrams showing how this code
evolved with incremental changes from the standard AWS examples.  The
SVG files are the original sources, created using Inkscape, and the
PNG files are automatically generated from them using Inkscape in
batch mode (see the Makefile therein).

Directory `src_Testbench_AWS/` is a substitute for the `src_Testbench`
directory in the Piccolo/Flute/Toooba repositories.  As in the
original, it has two subdirectories, `SoC` which contains
synthesizable code that goes into the FPGA, and `Top` which is just a
harness for Bluesim or verilator simulation (and contains
non-synthesizable imports of C code).

                src_Testbench_AWS/
                ├── SoC
                └── Top

Directory `src_Host_Side` is used for Bluesim or verilator sim; it
provides libraries linked with the host-side software; these libraries
provide an emulation of the AWS OCL and DMA PCIS interfaces through
which host-side software interacts with the hardware.

Directory `builds/` is similar to the corresponding directory in the
Piccolo/Flute/Toooba repositories, and `builds/Resources` is used
during creation of Bluesim and verilator simulation executables.

Directory `builds/RV64ACDFIMSU_Flute_bluesim_AWS` is used to create
Bluesim executables.

Directories `builds/RV64ACDFIMSU_Flute_verilator_AWS` is used to create
verilator executables, but also to generate RTL for the XSIM flow.

Directory `developer_designs` is similar to the corresponding
directories in the standard Amazon `aws-fpga` repository:

            asw-fpga/hdk/cl/examples/
            asw-fpga/hdk/cl/developer_designs/

----------------------------------------------------------------
