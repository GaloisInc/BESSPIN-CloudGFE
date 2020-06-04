###  -*-Makefile-*-

# ================================================================
# Edit this def to point at your clone of the GitHub Flute repo:
# (https://github.com/bluespec/Flute)

REPO ?= $(HOME)/git_clones/CHERI_Flute
# REPO ?= /local/scratch/aj443/Flute

# ================================================================
# Edit this def to configure desired ISA features

ARCH ?= RV64ACDFIMSU

# ================================================================
# RISC-V config macros passed into Bluespec 'bsc' compiler

CAPSIZE = 128
TAGS_STRUCT = 0 64
TAGS_ALIGN = 32

BSC_COMPILATION_FLAGS += \
	-D RV64 \
	-D ISA_PRIV_M  -D ISA_PRIV_U  -D ISA_PRIV_S  \
	-D SV39  \
	-D ISA_I  -D ISA_M  -D ISA_A  -D ISA_C \
	-D ISA_F  -D ISA_D  -D INCLUDE_FDIV  -D INCLUDE_FSQRT \
	-D SHIFT_BARREL    \
	-D MULT_SYNTH    \
	-D Near_Mem_Caches    \
	-D FABRIC64    \
	-D CAP128 \
	-D RISCV \
	-D MEM64 \
	-D ISA_CHERI \
	-D NO_TAGTABLE_ZEROING \

# Default ISA test

TEST ?= rv64ui-p-add

#================================================================
# Common boilerplate rules

include ./Include_Common.mk

#================================================================
# Makefile rules for building for specific simulator: verilator

include $(REPO)/builds/Resources/Include_verilator.mk

# ================================================================
