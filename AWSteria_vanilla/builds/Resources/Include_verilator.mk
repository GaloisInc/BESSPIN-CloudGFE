###  -*-Makefile-*-

# Copyright (c) 2018-2019 Bluespec, Inc. All Rights Reserved

# This file is not a standalone Makefile, but 'include'd by other Makefiles

# ================================================================
# Generate Verilog RTL from BSV sources (needs Bluespec 'bsc' compiler)

RTL_GEN_DIRS = -vdir Verilog_RTL  -bdir build_dir  -info-dir build_dir

build_dir:
	mkdir -p $@

Verilog_RTL:
	mkdir -p $@

.PHONY: compile
compile:  build_dir  Verilog_RTL
	@echo  "INFO: Verilog RTL generation ..."
	bsc -u -elab -verilog  $(RTL_GEN_DIRS)  $(BSC_COMPILATION_FLAGS)  -p $(BSC_PATH)  $(TOPFILE)
	@echo  "INFO: Verilog RTL generation finished"

# ================================================================
# Compile and link Verilog RTL sources into an verilator executable

SIM_EXE_FILE = exe_HW_sim

# Additional module(s) with DPI-C calls that need edits to remove '$imported_' prefix
# Each of these should have a 'sed' step (see below)
EDIT_MODULE2 = mkAWS_BSV_Top

# Verilator flags: notes
#    stats              Dump stats on the design, in file {prefix}__stats.txt
#    -O3                Verilator optimization level
#    -CFLAGS -O3        C++ optimization level
#    --x-assign fast    Optimize X value
#    --x-initial fast   Optimize uninitialized value
#    --noassert         Disable all assertions

# VERILATOR_FLAGS = --stats -O3 -LDFLAGS -static --x-assign fast --x-initial fast --noassert
VERILATOR_FLAGS = --stats -O3 -CFLAGS -O1 -LDFLAGS -static --x-assign fast --x-initial fast --noassert
# Note: C++ compile times for AWSteria:
#    no CFLAGS:   2 min
#    -CFLAGS -O:  4 min
#    -CFLAGS -O1: 4 min
#    -CFLAGS -O2: 8 min
#    -CFLAGS -O3: 15 min

# Verilator flags: use the following to include code to generate VCDs
# Select trace-depth according to your module hierarchy
# VERILATOR_FLAGS += --trace  --trace-depth 2  -CFLAGS -DVM_TRACE

VTOP                = V$(TOPMODULE)
VERILATOR_RESOURCES = $(AWSTERIA)/builds/Resources/Verilator_resources

.PHONY: simulator
simulator:
	@echo "----------------"
	@echo "INFO: Preparing RTL files for verilator"
	mkdir -p Verilator_RTL
	cp -p  Verilog_RTL/*.v  Verilator_RTL/
	@echo "Copied all Verilog files from Verilog_RTL/ to Verilator_RTL"
	sed  -f $(VERILATOR_RESOURCES)/sed_script.txt  Verilog_RTL/$(TOPMODULE).v  > tmp1.v
	cat  $(VERILATOR_RESOURCES)/verilator_config.vlt \
	     $(VERILATOR_RESOURCES)/import_DPI_C_decls.v \
	     tmp1.v                                          > Verilator_RTL/$(TOPMODULE).v
	rm   -f  tmp1.v
	@echo "    Edited $(TOPMODULE).v for DPI-C"
	@echo "----------------"
	sed  -f $(VERILATOR_RESOURCES)/sed_script.txt  Verilog_RTL/$(EDIT_MODULE2).v  > Verilator_RTL/$(EDIT_MODULE2).v
	@echo "Edited $(EDIT_MODULE2).v for DPI-C"
	@echo "----------------"
	@echo "INFO: Verilating Verilog files (in newly created obj_dir)"
	verilator \
		-IVerilator_RTL \
		-I$(REPO)/src_bsc_lib_RTL \
		$(VERILATOR_FLAGS) \
		--cc  $(TOPMODULE).v \
		--exe  sim_main.cpp \
		$(AWSTERIA)/src_Testbench_AWS/Top/C_Imported_Functions.c
	@echo "----------------"
	@echo "INFO: Linking verilated files"
	cp  -p  $(VERILATOR_RESOURCES)/sim_main.cpp  obj_dir/sim_main.cpp
	cd obj_dir; \
	   make -j -f V$(TOPMODULE).mk  $(VTOP); \
	   cp -p  $(VTOP)  ../$(SIM_EXE_FILE)
	@echo "----------------"
	@echo "INFO: Created verilator executable:    $(SIM_EXE_FILE)"

# ================================================================
