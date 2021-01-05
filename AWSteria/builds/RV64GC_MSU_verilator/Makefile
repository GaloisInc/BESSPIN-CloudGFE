###  -*-Makefile-*-

# ================================================================
# Edit this def to point at your clone of the GitHub Flute repo:
# (https://github.com/bluespec/Flute)

AWSTERIA   = $(HOME)/git_clones/AWS/BESSPIN-CloudGFE_rsn2/AWSteria
# AWSTERIA   = $(HOME)/git_clones/AWS/BESSPIN-CloudGFE/AWSteria
# AWSTERIA   = $(HOME)/git-repos/BESSPIN-CloudGFE/AWSteria

FLUTE_REPO = $(HOME)/git_clones/Flute
# FLUTE_REPO = $(HOME)/git-repos/Flute

REPO ?= $(FLUTE_REPO)

# ================================================================
# Edit this def to configure desired ISA features

RV = RV64
ARCH ?= RV64ACDFIMSU

# Alternative cache organizations:
# Default (no definition for CACHES)    L1 only, write-through policy
# Define  CACHES=WB_L1                  L1 only, with write-back policy
# Define  CACHES=WB_L1_L2               L1+L2, with write-back policy

CACHES=WB_L1_L2

TOPFILE   ?= $(AWSTERIA)/src_Testbench_AWS/Top/Top_HW_Side.bsv
SRC_CORE ?= $(REPO)/src_Core/Core_v2

# ================================================================
# RISC-V config macros passed into Bluespec 'bsc' compiler

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


#	-D INCLUDE_TANDEM_VERIF \


# Default ISA test

TEST ?= rv64ui-p-add

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

LLCACHE_DIR   = $(REPO)/src_Core/Near_Mem_VM_WB_L1_L2/src_LLCache
PROCS_LIB_DIR = $(LLCACHE_DIR)/procs/lib
PROCS_OOO_DIR = $(LLCACHE_DIR)/procs/RV64G_OOO
COHERENCE_DIR = $(LLCACHE_DIR)/coherence/src

CUSTOM_DIRS = $(LLCACHE_DIR):$(PROCS_LIB_DIR):$(PROCS_OOO_DIR):$(COHERENCE_DIR)

#================================================================
# Common boilerplate rules

include $(AWSTERIA)/builds/Resources/Include_Common.mk

#================================================================
# Makefile rules for building for specific simulator: verilator

include $(AWSTERIA)/builds/Resources/Include_verilator.mk

# ================================================================
