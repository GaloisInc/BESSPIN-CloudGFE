###  -*-Makefile-*-

# Copyright (c) 2020-2021 Bluespec, Inc.  All Rights Reserved

# ================================================================

.PHONY: help
help:
	@echo "Usage:"
	@echo "    make $(EXE)        create the host-side executable"
	@echo "    make clean         delete temporary files/dirs but keep the executable"
	@echo "    make full_clean    delete temporary files/dirs and delete the executable"

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

ifndef SDK_DIR
  $(error ERROR: SDK_DIR is undefined; please initialize aws-fpga repo with sdk_setup.sh, which also defines SDK_DIR)
else
  $(info  INFO: SDK_DIR = $(SDK_DIR))
endif

$(info INFO: Making executable for AWSteria-RISCV-Virtio host side on AWSF1)

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

SRCS_H += $(AWSTERIA_INFRA_REPO)/Include_API/AWSteria_Host_lib.h

SRCS_C += $(AWSTERIA_INFRA_REPO)/Platform_AWSF1/Host/AWSteria_Host_lib.c

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
# C compilation

CFLAGS += -std=gnu11 -g -Wall -Werror 
CFLAGS += -D IN_AWSF1

CFLAGS += -I $(AWSTERIA_INFRA_REPO)/Include_API
CFLAGS += -I $(SDK_DIR)/userspace/include
CFLAGS += -I $(SRC_DIR)
CFLAGS += -I $(TINYEMU)
CFLAGS += -I $(GDBSTUB)

CC     = gcc $(CFLAGS)

LDLIBS = -lfpga_mgmt -lcrypto -lpthread -lelf -laccelize_drmc

EXE    = exe_Host_AWSF1

# ================================================================
# Top-level target: the executable

$(EXE): $(SRCS_H) $(SRCS_C)
	$(CC) -g  -o $(EXE) $(SRCS_C) $(LDLIBS)

# ================================================================

.PHONY: clean
clean:
	rm -f  *.*~  Makefile*~  *.o

.PHONY: full_clean
full_clean:
	rm -f  *.*~  Makefile*~  *.o  exe_*

# ================================================================
