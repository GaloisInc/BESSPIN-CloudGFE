###  -*-Makefile-*-

# Copyright (c) 2020-2021 Bluespec, Inc.  All Rights Reserved

#================================================================

ifndef AWSTERIA_REPO
  $(error ERROR: please define AWSTERIA_REPO (path to AWSteria repo))
else
  $(info  INFO: AWSTERIA_REPO = $(AWSTERIA_REPO))
endif

ifndef AWSTERIA_INFRA_REPO
  $(error ERROR: please define AWSTERIA_INFRA_REPO (path to AWSteria_Infra repo))
else
  $(info  INFO: AWSTERIA_INFRA_REPO = $(AWSTERIA_INFRA_REPO))
endif

# ================================================================

.PHONY: help
help:
	@echo "Usage:  make $(EXE)"
	@echo "          Makes executable for RISCV-Virtio host-side"
	@echo "          pairing with HW-side  Bluesim or Verilator over TCP/IP."

# ================================================================
# Source files

# ----------------
# App host side

SRC_DIR = $(AWSTERIA_REPO)/Host

SRCS_H = \
	$(SRC_DIR)/Memhex32_read.h  $(SRC_DIR)/Memhex32_read_protos.h \
	$(SRC_DIR)/HS_syscontrol.h  $(SRC_DIR)/HS_syscontrol_protos.h \
	$(SRC_DIR)/HS_tty.h         $(SRC_DIR)/HS_tty_protos.h \
	$(SRC_DIR)/HS_pc_trace.h    $(SRC_DIR)/HS_pc_trace_protos.h \
	$(SRC_DIR)/HS_virtio.h      $(SRC_DIR)/HS_virtio_protos.h \
	$(SRC_DIR)/HS_gdbstub.h     $(SRC_DIR)/HS_gdbstub_protos.h \
	$(SRC_DIR)/HS_msg.h         $(SRC_DIR)/HS_msg_protos.h \

SRCS_C = $(SRC_DIR)/HS_main.c \
	$(SRC_DIR)/Memhex32_read.c \
	$(SRC_DIR)/HS_syscontrol.c \
	$(SRC_DIR)/HS_tty.c \
	$(SRC_DIR)/HS_pc_trace.c  \
	$(SRC_DIR)/HS_virtio.c \
	$(SRC_DIR)/HS_gdbstub.c \
	$(SRC_DIR)/HS_msg.c

# ----------------
# App host side Virtio emulation (tinyemu)

TINYEMU       = $(SRC_DIR)/tinyemu
TINYEMU_SLIRP = $(SRC_DIR)/tinyemu/slirp

SRCS_H += \
	$(TINYEMU)/virtio.h

SRCS_C += \
	$(TINYEMU)/cutils.c \
	$(TINYEMU)/fs_disk.c \
	$(TINYEMU)/iomem.c \
	$(TINYEMU)/json.c \
	$(TINYEMU)/machine.c \
	$(TINYEMU)/pci.c \
	$(TINYEMU)/riscv_cpu.c \
	$(TINYEMU)/riscv_machine.c \
	$(TINYEMU)/simplefb.c \
	$(TINYEMU)/softfp.c \
	$(TINYEMU)/temu.c \
	$(TINYEMU)/virtio.c \
	$(TINYEMU_SLIRP)/bootp.c \
	$(TINYEMU_SLIRP)/cksum.c \
	$(TINYEMU_SLIRP)/if.c \
	$(TINYEMU_SLIRP)/ip_icmp.c \
	$(TINYEMU_SLIRP)/ip_input.c \
	$(TINYEMU_SLIRP)/ip_output.c \
	$(TINYEMU_SLIRP)/mbuf.c \
	$(TINYEMU_SLIRP)/misc.c \
	$(TINYEMU_SLIRP)/sbuf.c \
	$(TINYEMU_SLIRP)/slirp.c \
	$(TINYEMU_SLIRP)/socket.c \
	$(TINYEMU_SLIRP)/tcp_subr.c \
	$(TINYEMU_SLIRP)/tcp_input.c \
	$(TINYEMU_SLIRP)/tcp_output.c \
	$(TINYEMU_SLIRP)/tcp_timer.c \
	$(TINYEMU_SLIRP)/udp.c \

CFLAGS += -DCONFIG_RISCV_MAX_XLEN=64 \
		-DMAX_XLEN=64 \
		-DCONFIG_SLIRP \
		-DDEBUG_VIRTIO

# ----------------
# AWSteria infra

SRCS_H += \
	$(AWSTERIA_INFRA_REPO)/Include_API/AWSteria_Host_lib.h \
	$(AWSTERIA_INFRA_REPO)/Platform_Sim/Host/Bytevec.h \
	$(AWSTERIA_INFRA_REPO)/Platform_Sim/Host/TCP_Client_Lib.h

SRCS_C += \
	$(AWSTERIA_INFRA_REPO)/Platform_Sim/Host/AWSteria_Host_lib.c \
	$(AWSTERIA_INFRA_REPO)/Platform_Sim/Host/Bytevec.c \
	$(AWSTERIA_INFRA_REPO)/Platform_Sim/Host/TCP_Client_Lib.c

# ----------------
# App host side gdbstub

GDBSTUB = $(SRC_DIR)/RISCV_gdbstub

SRCS_H += \
	$(GDBSTUB)/gdbstub.h \
	$(GDBSTUB)/gdbstub_be.h \
	$(GDBSTUB)/gdbstub_fe.h \
	$(GDBSTUB)/gdbstub_dmi.h \
	$(GDBSTUB)/RVDM.h \
	$(GDBSTUB)/Elf_read.h \

SRCS_C += \
	$(GDBSTUB)/gdbstub.c \
	$(GDBSTUB)/gdbstub_be.c \
	$(GDBSTUB)/gdbstub_fe.c \
	$(GDBSTUB)/RVDM.c \
	$(GDBSTUB)/Elf_read.c \

# ================================================================
# Config AWSteria_Infra simulation for different targets

# Default target
TARGET ?= VCU118
$(info INFO: Please define TARGET=VCU118 or TARGET=AWSF1 for proper DDR setup)

ifeq ($(TARGET),VCU118)

  CFLAGS += -D SIM_FOR_VCU118
  $(info  INFO: TARGET is VCU118 (has DDR A and B))

else ifeq ($(TARGET),AWSF1)

  CFLAGS += -D SIM_FOR_AWSF1
  $(info  INFO: TARGET is AWSF1 (has DDR A, B, C and D))

else
  $(error ERROR: please define TARGET=VCU118 or TARGET=AWSF1 for proper DDR setup)
endif

# ================================================================
# C compilation

CFLAGS += -std=gnu11 -g -Wall -Werror

CFLAGS += -I $(SRC_DIR)
CFLAGS += -I $(TINYEMU)
CFLAGS += -I $(GDBSTUB)
CFLAGS += -I $(AWSTERIA_INFRA_REPO)/Include_API
CFLAGS += -I $(AWSTERIA_INFRA_REPO)/Platform_Sim/Host

CC     = gcc $(CFLAGS)

LDLIBS = -lpthread -lelf

EXE    = exe_Host_sim

$(EXE): $(SRCS_H) $(SRCS_C)
	$(CC) -g  -o $(EXE) $(SRCS_C) $(LDLIBS)
	@echo "Created executable $(EXE) for host-side, for HW-side simulation (Bluesim or Verilator)"


# ================================================================

.PHONY: clean
clean:
	rm -f  *.*~  Makefile*~  *.o

.PHONY: full_clean
full_clean:
	rm -f  *.*~  Makefile*~  *.o  exe_*

# ================================================================
