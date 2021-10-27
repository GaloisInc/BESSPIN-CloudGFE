###  -*-Makefile-*-

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

ifndef BLUESPEC_HOME
  $(error ERROR: please define BLUESPEC_HOME, i.e., path to B-Lang installation bsc/inst)
else
  $(info  INFO: BLUESPEC_HOME is $(BLUESPEC_HOME))
endif

PLATFORM_SIM = $(AWSTERIA_INFRA_REPO)/Platform_Sim

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

# Unprivileged ISA
BSC_COMPILATION_FLAGS += -D $(RV)
BSC_COMPILATION_FLAGS += -D ISA_I  -D ISA_M  -D ISA_A  -D ISA_C
BSC_COMPILATION_FLAGS += -D ISA_F  -D ISA_D  -D INCLUDE_FDIV  -D INCLUDE_FSQRT

# Unprivileged ISA implementation choices
BSC_COMPILATION_FLAGS += -D SHIFT_BARREL
BSC_COMPILATION_FLAGS += -D MULT_SYNTH

# Privileged ISA
BSC_COMPILATION_FLAGS += -D ISA_PRIV_M  -D ISA_PRIV_U  -D ISA_PRIV_S
BSC_COMPILATION_FLAGS += -D SV39

# System implementation choices
BSC_COMPILATION_FLAGS += -D Near_Mem_Caches
BSC_COMPILATION_FLAGS += -D FABRIC64
BSC_COMPILATION_FLAGS += -D WATCH_TOHOST
BSC_COMPILATION_FLAGS += -D MEM_512b

# Debugging and tracing
BSC_COMPILATION_FLAGS += -D INCLUDE_PC_TRACE
BSC_COMPILATION_FLAGS += -D INCLUDE_GDB_CONTROL

# BSC_COMPILATION_FLAGS += -D INCLUDE_TANDEM_VERIF

# ================================================================
# Config AWSteria_Infra simulation for different targets

# Default target
TARGET ?= VCU118
$(info INFO: Please define TARGET=VCU118 or TARGET=AWSF1 for proper DDR setup)

ifeq ($(TARGET),VCU118)

  BSC_COMPILATION_FLAGS += -D SIM_FOR_VCU118
  BSC_COMPILATION_FLAGS += -D INCLUDE_DDR_A
  BSC_COMPILATION_FLAGS += -D INCLUDE_DDR_B
  $(info  INFO: TARGET is VCU118 (has DDR A and B))

else ifeq ($(TARGET),AWSF1)

  BSC_COMPILATION_FLAGS += -D SIM_FOR_AWSF1
  BSC_COMPILATION_FLAGS += -D INCLUDE_DDR_A
  BSC_COMPILATION_FLAGS += -D INCLUDE_DDR_B
  BSC_COMPILATION_FLAGS += -D INCLUDE_DDR_C
  BSC_COMPILATION_FLAGS += -D INCLUDE_DDR_D
  $(info  INFO: TARGET is AWSF1 (has DDR A, B, C and D))

else
  $(error ERROR: please define TARGET=VCU118 or TARGET=AWSF1 for proper DDR setup)
endif

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

# From AWSteria
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
BSC_PATH := $(BSC_PATH):$(AWSTERIA_INFRA_REPO)/Platform_Sim/HW

#================================================================
# Verilator search path

VERILATOR_FLAGS := -I$(FLUTE_REPO)/src_bsc_lib_RTL

#================================================================
# Common boilerplate rules, and simulator-specific rules

include $(PLATFORM_SIM)/HW/Include_Common.mk
include $(PLATFORM_SIM)/HW/Include_Verilator.mk

# ================================================================
