###  -*-Makefile-*-

# Copyright (c) 2018-2020 Bluespec, Inc. All Rights Reserved

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

# The following flags are recommended in the verilator manual for best performance
VERILATOR_FLAGS  = -O3 --x-assign fast --x-initial fast --noassert
VERILATOR_FLAGS += --stats -CFLAGS -D$(RV) -CFLAGS -O3 -LDFLAGS -static 

# Use the following to verilate into models that use multithreading in simulatino
# VERILATOR_FLAGS += --threads 6  --threads-dpi pure

# Verilator flags: use the following to include code to generate VCDs
# Select trace-depth according to your module hierarchy
# VERILATOR_FLAGS += --trace  --trace-depth 2  -CFLAGS -DVM_TRACE

VTOP                = V$(TOPMODULE)
VERILATOR_RESOURCES = $(AWSTERIA)/builds/Resources/Verilator_resources
VERILATOR_MAKE_DIR  = Verilator_Make

.PHONY: simulator
simulator:
	@echo "----------------"
	@echo "INFO: Preparing RTL files for verilator"
	@echo "Copying all Verilog files from Verilog_RTL/ to Verilator_RTL"
	mkdir -p Verilator_RTL
	cp -p  Verilog_RTL/*.v  Verilator_RTL/
	@echo "----------------"
	@echo "INFO: Editing Verilog_RTL/$(TOPMODULE).v -> Verilator_RTL/$(TOPMODULE).v for DPI-C"
	sed  -f $(VERILATOR_RESOURCES)/sed_script.txt  Verilog_RTL/$(TOPMODULE).v  > tmp1.v
	cat  $(VERILATOR_RESOURCES)/verilator_config.vlt \
	     $(VERILATOR_RESOURCES)/import_DPI_C_decls.v \
	     tmp1.v                                          > Verilator_RTL/$(TOPMODULE).v
	rm   -f  tmp1.v
	@echo "----------------"
	@echo "INFO: Editing Verilog_RTL/$(EDIT_MODULE2).v -> Verilator_RTL/$(EDIT_MODULE2).v for DPI-C"
	sed  -f $(VERILATOR_RESOURCES)/sed_script.txt  Verilog_RTL/$(EDIT_MODULE2).v  > Verilator_RTL/$(EDIT_MODULE2).v
	@echo "----------------"
	@echo "INFO: Verilating Verilog files (in newly created obj_dir)"
	verilator \
		-IVerilator_RTL \
		-I$(REPO)/src_bsc_lib_RTL \
		-Mdir $(VERILATOR_MAKE_DIR) \
		$(VERILATOR_FLAGS) \
		--cc  --exe --build -j 4 -o exe_HW_sim  $(TOPMODULE).v \
		--top-module $(TOPMODULE) \
		$(VERILATOR_RESOURCES)/sim_main.cpp \
		$(AWSTERIA)/src_Testbench_AWS/Top/C_Imported_Functions.c
	mv  $(VERILATOR_MAKE_DIR)/$(SIM_EXE_FILE)  .
	@echo "----------------"
	@echo "INFO: Created verilator executable:    $(SIM_EXE_FILE)"

# ================================================================
