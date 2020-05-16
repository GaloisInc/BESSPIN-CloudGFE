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

This example allows you to build and run the structure shown in [Fig
3](Doc/Fig_3_AWS_BSV_XSim_WindSoC.png) in the `Doc/` directory, using
the standard AWS XSIM flow.  The "C Tests" code reads a Mem-hex32 file
containing the code for the RISC-V ISA test `rv64ui-p-add`, and DMAs
it into DDR A via the `DMA_PCIS` high-bandwidth bus.  Then it talks
over the `OCL` bus to the SoC, allowing it to access memory (until
then the Flute CPU is stalled trying to fetch an instruction).  The
CPU then executes the ISA test to completion.  The C code continually
polls the SoC over the `OCL` bus until it hears that the test is
completed, and finally exits.

There are several manual steps for now; we'll automate these once we
have a full understanding of all the steps.

1. Bluespec BSV compilation:

            $ cd  builds/RV64ACDFIMSU_Flute_verilator_AWS/

    One-time step: Edit the def of REPO in `Makefile` to point at your clone of the
    GitHub Flute repo.

    Then:

            $ make compile

    will create the sub-directory `Verilog_RTL`, and invoke the
    Bluespec `bsc` compiler to compile Flute, its SoC, `BSV_AWS_TOP`
    etc. into Verilog RTL in that directory.

2. Build and run the design on XSIM (Xilinx Verilog Simulator) using the AWS flow:

    **One-time step:** Perform your standard mantra to setup Xilinx tools. This
    should at least set the `XILINX_VIVADO` environment variable to point to
    your Vivado install directory and add `$XILINX_VIVADO/bin/` to your `PATH`.
    It may look something like this:

            $ source  /tools/Xilinx/Vivado/2019.1/settings64.sh

    **One-time step:** Perform the standard AWS HDK setup mantra:

            $ cd  $(AWS_FPGA)
            $ source  hdk_setup.sh

    **One-time step:** set up `CL_DIR` to point at the top-level dir
    of the design:

            $ cd  ... back to your main AWSteria directory ...
            $ cd  developer_designs/cl_BSV_WindSoC
            $ export CL_DIR=$(pwd)

    **Copy RTL into the design directories, and prep a script file:**

            $ cd  verif/scripts
            $ make -f AWSteria_Makefile.mk  prep

    This will temporarily change dirs to the `design` directory (where
    the AWS flow expects RTL files to live) and use the `Makefile`
    there to copy RTL files from Step 1 and from the Bluespec library;
    then creates a file

            ../verif/scripts/top.vivado.f_design_files

    containing a manifest of all the design RTL files just copied, and
    then append it to `top.vivado.f_template` to create
    `top.vivado.f`.  This is a script file for XSIM.

    **Run**:

            $ cd  verif/scripts
            $ make -f AWSteria_Makefile.mk  test

    This should run build an XSIM simulation executable and run it,
    corresponding to the Figure `Doc/Fig_3_AWS_BSV_XSim_WindSoC.png`.
    The C program that represents the "host-side" software is in:

            developer_designs/cl_BSV_WindSoC/software/runtime/test_dram_dma_hwsw_cosim.c
            developer_designs/cl_BSV_WindSoC/software/runtime/Memhex32_read.{h,c}

    The C program reads `Mem.hex`, a mem-hex32 file holding the code
    for the RISC-V ISA test `rv64ui-p-add`, DMAs it into AWS' DDR A
    using the AWS `DMA_PCIS` port, then communicates over the AWS OCL
    port with the SoC to allow the CPU (Flute) to access memory, so
    that it executes the test.  The file:

            log_make.txt

    is a transcript of this last step, so you can see what to expect.

----------------------------------------------------------------

A Tour of the Code
------------------

The directory tree looks like this:

            .
            ├── builds
            ├── developer_designs
            ├── Doc
            ├── README.md
            └── src_Testbench_AWS

This repo contains no Piccolo/Flute/Toooba code at all.  Those are
used unmodified from their original repositories (including
caches/MMUs, Debug Module, PLIC, Tandem Verifation trace generator,
Near\_Mem\_IO (a.k.a. CLINT), system AXI4 fabric, Boot ROM, and UART).
Here we are just surrounding that with a different connection to
memory (AWS DDR4), and different connections for the Debug Module and
UART (AWS OCL port), and providing a fast back-door for loading the
DDR4s (AWS DMA\_PCIS port).

Directory `Doc` has a number of diagrams showing how this code evolved
with incremental changes from the standard AWS examples.  The SVG
files are the original sources, created using Inkscape, and the PNG
files are automatically generated from them using Inkscape in batch
mode (see the Makefile therein).

Directory `src_Testbench_AWS/` is a substitute for the `src_Testbench`
directory in the Piccolo/Flute/Toooba repositories.  As in the
original, it has two subdirectories, `SoC` which contains
synthesizable code that goes into the FPGA, and `Top` which is just a
harness for Bluesim or verilator simulation (and contains
non-synthesizable imports of C code).

                src_Testbench_AWS/
                ├── SoC
                └── Top

Directory `builds/` is similar to the corresponding directory in the
Piccolo/Flute/Toooba repositories, and is used:

 * To generate RTL from BSV (see Step 1 in Example section)

 * To build and run standalone Bluesim/verilator simulation
      executables, without going through the AWS XSim flow, for more
      convenience and likely higher simulation speed. (2020-05-01:
      this flow is not yet documented; will do so soon; just needs a
      top-level testbench facility to load a MemHex file through the
      `DMI_PCIS` port.)

Directory `developer_designs` is similar to the corresponding
directories in the standard Amazon `aws-fpga` repository:

            asw-fpga/hdk/cl/examples/
            asw-fpga/hdk/cl/developer_designs/

----------------------------------------------------------------
