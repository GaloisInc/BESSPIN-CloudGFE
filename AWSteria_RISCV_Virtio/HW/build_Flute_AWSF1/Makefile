###  -*-Makefile-*-

# Copyright (c) 2020-2021 Bluespec, Inc.  All Rights Reserved

# ================================================================

.PHONY: help
help:
	@echo "Usage:"
	@echo "  make compile                 Create dir RTL_from_bsc/ and compile sources to RTL there."
	@echo "  make for_AWSF1_HDK           Using RTL_from_bsc, create AWS-FPGA HDK-ready build directory"
	@echo "  make clean                   Remove build_dir (for intermediate files)."
	@echo "  make full_clean              Restore to pristine state."
	@echo ""
	@echo "  Current DDR compiler flag: $(INCLUDE_DDRS)"

# ================================================================
# Dependencies on other repos

ifndef AWSTERIA_REPO
  $(error ERROR: please define AWSTERIA_REPO, i.e., path to AWSteria repo)
else
  $(info  INFO: AWSTERIA_REPO is $(AWSTERIA_REPO))
endif

ifndef FLUTE_REPO
  $(error ERROR: please define FLUTE_REPO, i.e., path to Flute repo)
else
  $(info  INFO: FLUTE_REPO is $(FLUTE_REPO))
endif

ifndef BLUESPEC_HOME
  $(error ERROR: please define BLUESPEC_HOME, i.e., path to bsc installation)
else
  $(info  INFO: BLUESPEC_HOME is $(BLUESPEC_HOME))
endif

#================================================================
# Architectural configs

RV = RV64
ARCH ?= RV64ACDFIMSU

# Alternative cache organizations:
# Default (no definition for CACHES)    L1 only, write-through policy
# Define  CACHES=WB_L1                  L1 only, with write-back policy
# Define  CACHES=WB_L1_L2               L1+L2, with write-back policy

CACHES=WB_L1_L2
NEAR_MEM_VM_DIR=Near_Mem_VM_WB_L1_L2

BSC_COMPILATION_FLAGS += \
	-D $(RV) \
	-D ISA_PRIV_M  -D ISA_PRIV_U  -D ISA_PRIV_S  \
	-D SV39  \
	-D ISA_I  -D ISA_M  -D ISA_A  -D ISA_C \
	-D ISA_F  -D ISA_D  -D INCLUDE_FDIV  -D INCLUDE_FSQRT \
	-D SHIFT_BARREL    \
	-D MULT_SYNTH    \
	-D Near_Mem_Caches    \
	-D FABRIC64    \
	-D WATCH_TOHOST    \
	-D MEM_512b    \
	-D INCLUDE_PC_TRACE \
	-D INCLUDE_GDB_CONTROL \
#	-D INCLUDE_TANDEM_VERIF \

#================================================================
# For LLCache

# core size
CORE_SIZE ?= SMALL
# default 1 core
CORE_NUM ?= 1
# cache size
CACHE_SIZE ?= LARGE

BSC_COMPILATION_FLAGS += \
	-D CORE_$(CORE_SIZE) \
	-D NUM_CORES=$(CORE_NUM) \
	-D CACHE_$(CACHE_SIZE) \

LLCACHE_DIR   = $(FLUTE_REPO)/src_Core/Near_Mem_VM_WB_L1_L2/src_LLCache
PROCS_LIB_DIR = $(LLCACHE_DIR)/procs/lib
PROCS_OOO_DIR = $(LLCACHE_DIR)/procs/RV64G_OOO
COHERENCE_DIR = $(LLCACHE_DIR)/coherence/src

BSC_PATH := $(BSC_PATH):$(LLCACHE_DIR):$(PROCS_LIB_DIR):$(PROCS_OOO_DIR):$(COHERENCE_DIR)

#================================================================
# BSC_PATH for AWSteria/Flute/Virtio system

# The AWSteria/Flute/Virtio App
BSC_PATH := $(BSC_PATH):$(AWSTERIA_REPO)/HW

# From Flute
BSC_PATH := $(BSC_PATH):$(FLUTE_REPO)/src_Core/CPU
BSC_PATH := $(BSC_PATH):$(FLUTE_REPO)/src_Core/ISA
BSC_PATH := $(BSC_PATH):$(FLUTE_REPO)/src_Core/RegFiles
BSC_PATH := $(BSC_PATH):$(FLUTE_REPO)/src_Core/Core_v2
BSC_PATH := $(BSC_PATH):$(FLUTE_REPO)/src_Core/Cache_Config
BSC_PATH := $(BSC_PATH):$(FLUTE_REPO)/src_Core/$(NEAR_MEM_VM_DIR)
BSC_PATH := $(BSC_PATH):$(FLUTE_REPO)/src_Core/PLIC
BSC_PATH := $(BSC_PATH):$(FLUTE_REPO)/src_Core/Near_Mem_IO
BSC_PATH := $(BSC_PATH):$(FLUTE_REPO)/src_Core/Debug_Module
BSC_PATH := $(BSC_PATH):$(FLUTE_REPO)/src_Core/BSV_Additional_Libs
BSC_PATH := $(BSC_PATH):$(FLUTE_REPO)/src_Testbench/Fabrics/AXI4
BSC_PATH := $(BSC_PATH):$(FLUTE_REPO)/src_Testbench/Fabrics/AXI4_Lite
BSC_PATH := $(BSC_PATH):$(FLUTE_REPO)/src_Testbench/SoC

# From AWSteria_Infra
BSC_PATH := $(BSC_PATH):$(AWSTERIA_INFRA_REPO)/Include_API
BSC_PATH := $(BSC_PATH):$(AWSTERIA_INFRA_REPO)/Platform_AWSF1/HW

#================================================================
# Top-level file and module

TOPFILE   = $(AWSTERIA_REPO)/HW/AWSteria_HW.bsv
TOPMODULE = mkAWSteria_HW

# ================================================================
# bsc compilation flags

# Depending on platform, can also add DDR C and D
INCLUDE_DDRS += -D INCLUDE_DDR_B

BSC_COMPILATION_FLAGS += $(INCLUDE_DDRS) \
	-keep-fires -aggressive-conditions -no-warn-action-shadowing \
	-no-show-timestamps -check-assert \
	-suppress-warnings G0020    \
	+RTS -K128M -RTS  -show-range-conflict

BSC_PATH := $(BSC_PATH):+

# ================================================================
# Generate Verilog RTL from BSV sources (needs Bluespec 'bsc' compiler)

RTL_GEN_DIRS = -vdir RTL_from_bsc  -bdir build_dir  -info-dir build_dir

.PHONY: compile
compile:
	mkdir -p  build_dir
	mkdir -p  RTL_from_bsc
	@echo  "INFO: RTL generation ..."
	bsc -u -elab -verilog  $(RTL_GEN_DIRS)  $(BSC_COMPILATION_FLAGS)  -p $(BSC_PATH)  $(TOPFILE)
	@echo  "INFO: RTL generation finished: RTL_from_bsc/ is ready for FPGA build."

# ================================================================
# For AWSF1: collect all RTL needed for aws-fpga HDK flow

.PHONY: for_AWSF1_HDK
for_AWSF1_HDK:
	@echo "INFO: Creating and populating aws-fpga HDK custom-logic dir"
	@echo "    Copying RTL for Platform_AWSF1 support"
	rm -r -f cl_AWSteria_RISCV
	cp -p -R $(AWSTERIA_INFRA_REPO)/Platform_AWSF1/HW/cl_AWSteria  cl_AWSteria_RISCV
	@echo "    Copying RTL for app"
	cp -p  RTL_from_bsc/*.v  cl_AWSteria_RISCV/design/
	@echo "    Copying RTL from BLUESPEC_HOME = $(BLUESPEC_HOME)"
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/BRAM1BELoad.v  cl_AWSteria_RISCV/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/BRAM1BE.v      cl_AWSteria_RISCV/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/BRAM2BELoad.v  cl_AWSteria_RISCV/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/BRAM2BE.v      cl_AWSteria_RISCV/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/BRAM2.v        cl_AWSteria_RISCV/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/FIFO10.v       cl_AWSteria_RISCV/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/FIFO1.v        cl_AWSteria_RISCV/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/FIFO20.v       cl_AWSteria_RISCV/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/FIFO2.v        cl_AWSteria_RISCV/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/FIFOL1.v       cl_AWSteria_RISCV/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/RegFile.v      cl_AWSteria_RISCV/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/RevertReg.v    cl_AWSteria_RISCV/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/SizedFIFO0.v   cl_AWSteria_RISCV/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/SizedFIFO.v    cl_AWSteria_RISCV/design/
	@echo "INFO: aws-fpga HDK custom-logic dir is ready: cl_AWSteria_RISCV/"

# ================================================================

.PHONY: clean
clean:
	rm -r -f  *~  tmp_all_srcs  build_dir

.PHONY: full_clean
full_clean: clean
	rm -r -f  *~  tmp_all_srcs  build_dir  RTL_from_bsc  example_AWSteria_HW  example_AWSteria_HW_reclocked

# ================================================================
