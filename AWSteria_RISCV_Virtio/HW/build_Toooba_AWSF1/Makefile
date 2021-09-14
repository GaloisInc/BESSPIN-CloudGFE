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

ifndef AWSTERIA_INFRA_REPO
  $(error ERROR: please define AWSTERIA_INFRA_REPO, i.e., path to AWSteria_Infra repo)
else
  $(info  INFO: AWSTERIA_INFRA_REPO is $(AWSTERIA_INFRA_REPO))
endif

ifndef FLUTE_REPO
  $(error ERROR: please define FLUTE_REPO, i.e., path to Flute repo)
else
  $(info  INFO: FLUTE_REPO is $(FLUTE_REPO))
endif

ifndef TOOOBA_REPO
  $(error ERROR: please define TOOOBA_REPO, i.e., path to Toooba repo)
else
  $(info  INFO: TOOOBA_REPO is $(TOOOBA_REPO))
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

BSC_COMPILATION_FLAGS += \
	-D $(RV) \
	-D ISA_PRIV_M  -D ISA_PRIV_U  -D ISA_PRIV_S  \
	-D SV39  \
	-D ISA_I  -D ISA_M  -D ISA_A  -D ISA_C \
	-D ISA_F  -D ISA_D  -D INCLUDE_FDIV  -D INCLUDE_FSQRT \
	-D SHIFT_BARREL    \
	-D MULT_SYNTH    \
	-D OPTION_DMA_CACHE \
	-D FABRIC64    \
	-D WATCH_TOHOST    \
	-D MEM_512b    \
	-D INCLUDE_PC_TRACE \
	$(DEVICE_COHERENT_ACCESS) \
	-D INCLUDE_GDB_CONTROL \
#	-D INCLUDE_TANDEM_VERIF \

#================================================================
# Parameter settings for MIT RISCY_OOO

# This selects non-Xilinx Verilog for FPU
BSC_COMPILATION_FLAGS += -D BSIM \

include Include_RISCY_OOO_Config.mk

#================================================================
# BSC_PATH for AWSteria/Flute/Virtio system

# From AWSteria_Infra
BSC_PATH := $(BSC_PATH):$(AWSTERIA_INFRA_REPO)/Include_API
BSC_PATH := $(BSC_PATH):$(AWSTERIA_INFRA_REPO)/Platform_AWSF1/HW

# From AWSteria
BSC_PATH := $(BSC_PATH):$(AWSTERIA_REPO)/HW

# Common stuff
BSC_PATH := $(BSC_PATH):$(FLUTE_REPO)/src_Core/ISA
BSC_PATH := $(BSC_PATH):$(FLUTE_REPO)/src_Core/BSV_Additional_Libs

# From Toooba
BSC_PATH := $(BSC_PATH):$(TOOOBA_REPO)/src_Core/Core
BSC_PATH := $(BSC_PATH):$(TOOOBA_REPO)/src_Core/CPU
BSC_PATH := $(BSC_PATH):$(TOOOBA_REPO)/src_Core/Debug_Module
BSC_PATH := $(BSC_PATH):$(TOOOBA_REPO)/src_Core/PLIC

# From RISCY_OOO
BSC_PATH := $(BSC_PATH):$(TOOOBA_REPO)/src_Core/RISCY_OOO/procs/RV64G_OOO
BSC_PATH := $(BSC_PATH):$(TOOOBA_REPO)/src_Core/RISCY_OOO/procs/lib
BSC_PATH := $(BSC_PATH):$(TOOOBA_REPO)/src_Core/RISCY_OOO/coherence/src
BSC_PATH := $(BSC_PATH):$(TOOOBA_REPO)/src_Core/RISCY_OOO/fpgautils/lib
BSC_PATH := $(BSC_PATH):$(TOOOBA_REPO)/src_Core/RISCY_OOO/connectal/bsv
BSC_PATH := $(BSC_PATH):$(TOOOBA_REPO)/src_Core/RISCY_OOO/connectal/tests/spi
BSC_PATH := $(BSC_PATH):$(TOOOBA_REPO)/src_Core/RISCY_OOO/connectal/lib/bsv

# AXI4 and AXI4_Lite fabrics
BSC_PATH := $(BSC_PATH):$(FLUTE_REPO)/src_Testbench/Fabrics/AXI4
BSC_PATH := $(BSC_PATH):$(FLUTE_REPO)/src_Testbench/Fabrics/AXI4_Lite

# SoC components not overridden by AWSteria
BSC_PATH := $(BSC_PATH):$(TOOOBA_REPO)/src_Testbench/SoC

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
	rm -r -f cl_AWSteria_Toooba
	cp -p -R $(AWSTERIA_INFRA_REPO)/Platform_AWSF1/HW/cl_AWSteria  cl_AWSteria_Toooba
	@echo "    Copying RTL for app"
	cp -p  RTL_from_bsc/*.v  cl_AWSteria_Toooba/design/
	@echo "    Copying RTL from BLUESPEC_HOME = $(BLUESPEC_HOME)"
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/BRAM1BELoad.v  cl_AWSteria_Toooba/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/BRAM1BE.v      cl_AWSteria_Toooba/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/BRAM2BELoad.v  cl_AWSteria_Toooba/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/BRAM2BE.v      cl_AWSteria_Toooba/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/BRAM2.v        cl_AWSteria_Toooba/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/FIFO10.v       cl_AWSteria_Toooba/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/FIFO1.v        cl_AWSteria_Toooba/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/FIFO20.v       cl_AWSteria_Toooba/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/FIFO2.v        cl_AWSteria_Toooba/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/FIFOL1.v       cl_AWSteria_Toooba/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/MakeResetA.v   cl_AWSteria_Toooba/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/RegFile.v      cl_AWSteria_Toooba/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/ResetEither.v  cl_AWSteria_Toooba/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/RevertReg.v    cl_AWSteria_Toooba/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/SizedFIFO0.v   cl_AWSteria_Toooba/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/SizedFIFO.v    cl_AWSteria_Toooba/design/
	cp -p  $(BLUESPEC_HOME)/lib/Verilog/SyncResetA.v   cl_AWSteria_Toooba/design/
	@echo "INFO: aws-fpga HDK custom-logic dir is ready: cl_AWSteria_Toooba/"

# ================================================================

.PHONY: clean
clean:
	rm -r -f  *~  tmp_all_srcs  build_dir

.PHONY: full_clean
full_clean: clean
	rm -r -f  *~  tmp_all_srcs  build_dir  RTL_from_bsc  example_AWSteria_HW  example_AWSteria_HW_reclocked

# ================================================================
