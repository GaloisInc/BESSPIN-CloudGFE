# This Makefile shows the steps in building and running using Bluesim
# (Bluepec bsc's native simulator).

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
# Build the Bluesim executable
# (Requires bsc compiler, with env vars BLUESPECDIR, etc.)

.PHONY: Step_1_Bluesim_exe
Step_1_Bluesim_exe:
	$ cd  $(AWSTERIA)/builds/RV64ACDFIMSU_Flute_bluesim_AWS/
	$ make all

# This will invoke `bsc` to compile and build the 'hardware-side' as a
# Bluesim executable, embodied in two files:
#    exe_HW_sim*
#    exe_HW_sim.so*

# ================================================================
# Build the host-side software executable

.PHONY: Step_2_hostside_exe
Step_2_hostside_exe:
	$ cd  $(AWSTERIA)/src_Host_Side/
	$ make

# This will build the host-side executable, embodied as a the file `test`

# ================================================================
# Run the host-side software and the simulation

# In one terminal window, do the following to start the Bluesim
# executable. It will immediately pause, waiting for a TCP connection
# on socket 30000 from the host-side software.

.PHONY: Step_3a_start_bluesim
Step_3a_start_bluesim:
	$ cd  $(AWSTERIA)/builds/RV64ACDFIMSU_Flute_bluesim_AWS/
	$ ./exe_HW_sim


# In another terminal window, do the following to start the host-side
# executable. It will connect to the Bluesim executable, and then both
# will run concurrently.  The OCP and DMA PCIS interface interactions
# will be emulated over the TCP connection.

.PHONY: Step_3b_start_hostside
Step_3b_start_hostside:
	$ cd  $(AWSTERIA)/src_Host_Side
	$ ./test

# ================================================================
