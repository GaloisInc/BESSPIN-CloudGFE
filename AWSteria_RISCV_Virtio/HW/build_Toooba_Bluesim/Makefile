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

ifndef TOOOBA_REPO
  $(error ERROR: please define TOOOBA_REPO, i.e., path to Toooba repo)
else
  $(info  INFO: TOOOBA_REPO is $(TOOOBA_REPO))
endif

ifndef BLUESPEC_HOME
  $(error ERROR: please define BLUESPEC_HOME, i.e., path to B-Lang installation bsc/inst)
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

BSC_COMPILATION_FLAGS += -D BSIM \

include Include_RISCY_OOO_Config.mk

#================================================================
# BSC_PATH for AWSteria/Flute/Virtio system

# From AWSteria_Infra
BSC_PATH := $(BSC_PATH):$(AWSTERIA_INFRA_REPO)/Include_API
BSC_PATH := $(BSC_PATH):$(AWSTERIA_INFRA_REPO)/Platform_Sim/HW

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
# Verilator search path

VERILATOR_FLAGS := -I$(TOOOBA_REPO)/src_bsc_lib_RTL

#================================================================
# Common boilerplate rules, and simulator-specific rules
# from AWSteria_Infra (the top-level)

include $(AWSTERIA_INFRA_REPO)/Platform_Sim/HW/Include_Common.mk
include $(AWSTERIA_INFRA_REPO)/Platform_Sim/HW/Include_Bluesim.mk

# ================================================================
