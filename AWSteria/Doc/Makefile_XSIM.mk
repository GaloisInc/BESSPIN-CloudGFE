# This Makefile shows the steps in building and running using XSIM
# (Xilinx's simulator), using the standard flow from the AWS examples.

# Rishiyur S. Nikhil, May 27, 2020

# ================================================================
# Edit the following variable definitions for your environment/
# use-case.

# Your clone of: https://github.com/aws/aws-fpga.git
AWS_FPGA_REPO_DIR ?= $(HOME)/git_clones/AWS/aws-fpga

# Your clone of: https://github.com/DARPA-SSITH-Demonstrators/BESSPIN-CloudGFE
AWSTERIA          ?= $(HOME)/git_clones/AWS/BESSPIN-CloudGFE/AWSteria

# Your clone of the Flute repository: https://github.com/bluespec/Flute
FLUTE_REPO        ?= $(HOME)/git_clones/Flute/builds

# ================================================================
# Compile the BSV code into RTL
# (Requires bsc compiler, with env vars BLUESPECDIR, etc.)

.PHONY: Step_1_BSV_compile
Step_1_BSV_compile:
	$ cd  builds/RV64ACDFIMSU_Flute_verilator_AWS/
	$ make compile

# This will create the sub-directory `Verilog_RTL/`, and invoke the
# Bluespec `bsc` compiler to compile Flute, its SoC, `BSV_AWS_TOP`
# etc. into Verilog RTL in that directory.

# ================================================================
# ONE-TIME STEPS to prepare for building the XSIM simulation

# Perform your standard mantra to setup Xilinx tools. This should at
# least set the `XILINX_VIVADO` environment variable to point to your
# Vivado install directory and add `$XILINX_VIVADO/bin/` to your
# `PATH`.  It may look something like this:

.PHONY: Step_2a_Setup_Vivado
Step_2a_Setup_Vivado:
	$ source  /tools/Xilinx/Vivado/2019.1/settings64.sh

# Perform the standard AWS HDK setup mantra.  Note, the very first
# time that you do this, it will take some time, since it uses Vivado
# to compile some memory models.  On subsequent attempts, it will
# complete in seconds.

.PHONY: Step_2b_Setup_AWS_HDK
Step_2b_Setup_AWS_HDK:
	$ cd  $(AWS_FPGA_REPO_DIR)
	$ source  hdk_setup.sh

# set up environment var `CL_DIR` to point at the top-level dir of the design:

.PHONY: Step_2c_Setup_AWS_HDK
Step_2c_Setup_AWS_HDK:
	$ cd  $(AWSTERIA)/developer_designs/cl_BSV_WindSoC
	$ export CL_DIR=$(pwd)

# ================================================================
# Copy RTL into the design directories, and prep a script file:

.PHONY: Step_3_Copy_RTL_etc
Step_3_Copy_RTL_etc:
	$ cd  $(AWSTERIA)/developer_designs/cl_BSV_WindSoC/verif/scripts/
	$ make -f AWSteria_Makefile.mk  prep

# This will temporarily change dirs to the `design` directory (which
# is where the standard AWS flow expects RTL files to live) and use
# the `Makefile` there to (a) copy RTL files from Step_1_BSV_Compile,
# (b) copy RTL files from the Bluespec library; and (c) then create a
# file:
#     $(AWSTERIA)/developer_designs/cl_BSV_WindSoC/verif/scripts/top.vivado.f_design_files
# which is a manifest of the all the RTL design files just copied, and
# then append it to `top.vivado.f_template` to create 'top.vivado.f`.
# This is a script file for XSIM.



2. Build and run the design on XSIM (Xilinx Verilog Simulator) using the AWS flow:

# ================================================================
# Build an XSIM executable object and run it

.PHONY: Step_3_XSIM
Step_3_XSIM:
	$ cd  $(AWSTERIA)/developer_designs/cl_BSV_WindSoC/verif/scripts/
	$ make -f AWSteria_Makefile.mk  test

# This should run build an XSIM simulation executable and run it,
# corresponding to the Figure `Doc/Fig_3_AWS_BSV_XSim_WindSoC.png`.
# The C program that represents the "host-side" software is in:
#
#     developer_designs/cl_BSV_WindSoC/software/runtime/test_dram_dma_hwsw_cosim.c
#     developer_designs/cl_BSV_WindSoC/software/runtime/Memhex32_read.{h,c}
#
# The C program reads `Mem.hex`, a mem-hex32 file holding the code for
# the RISC-V ISA test `rv64ui-p-add`, DMAs it into AWS's DDR A using
# the AWS `DMA_PCIS` port, then communicates over the AWS OCL port
# with the SoC to allow the CPU (Flute) to access memory, so that it
# executes the test.  The file:
#
#    log_make.txt
#
# is a transcript of this last step, so you can see what to expect.
# Note: the AWS scripts change to the following directory to perform
# the XSIM simulation, so that is where the Mem.hex files should be
# located:
#
#    sim/vivado/test_dram_dma_hwsw_cosim_c/Mem.hex
#
# ================================================================
