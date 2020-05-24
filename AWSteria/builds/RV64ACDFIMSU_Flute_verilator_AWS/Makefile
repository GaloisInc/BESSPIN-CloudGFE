###  -*-Makefile-*-

# ================================================================
# Edit this def to point at your clone of the GitHub Flute repo:
# (https://github.com/bluespec/Flute)

AWSTERIA ?= ../..
REPO     ?= /home/nikhil/git_clones/Flute

# ================================================================
# Edit this def to configure desired ISA features

ARCH ?= RV64ACDFIMSU

# ================================================================
# RISC-V config macros passed into Bluespec 'bsc' compiler

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


# Default ISA test

TEST ?= rv64ui-p-add

#================================================================
# Common boilerplate rules

include $(AWSTERIA)/builds/Resources/Include_Common.mk

#================================================================
# Makefile rules for building for specific simulator: verilator

include $(AWSTERIA)/builds/Resources/Include_verilator.mk

# ================================================================
