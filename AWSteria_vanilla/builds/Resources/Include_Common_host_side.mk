###  -*-Makefile-*-

# Copyright (c) 2020-2021 Bluespec, Inc.  All Rights Reserved

# This file is not a standalone Makefile, but 'include'd by other Makefiles
# for building host-side executable (x86-64 Linux) for AWSteria
# either for AWS F1
# or for simulation (Bluesim/verilator sim)

# ================================================================

CFLAGS += -std=gnu11 -g -Wall -Werror
OBJS   += HS_main.o  Memhex32_read.o \
		HS_syscontrol.o  HS_pc_trace.o  HS_tty.o  HS_virtio.o  HS_gdbstub.o  SimpleQueue.o \
		HS_msg.o

CC     = gcc $(CFLAGS)

SRC = $(AWSTERIA_REPO)/src_Host_Side

# ================================================================
# Defs for incorporating tinyemu

TINYEMU       = $(SRC)/tinyemu
TINYEMU_SLIRP = $(SRC)/tinyemu/slirp

TINYEMU_SRCS_C = $(TINYEMU)/cutils.c \
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

TINYEMU_CFLAGS= -DCONFIG_RISCV_MAX_XLEN=64 \
		-DMAX_XLEN=64 \
		-DCONFIG_SLIRP \
		-DDEBUG_VIRTIO \


# ================================================================
# Top-level command to build EXE

$(EXE): $(OBJS)
	$(CC) -g  -o $(EXE) \
	$(TINYEMU_CFLAGS) \
	-I $(SRC)  -I $(TINYEMU)  -I $(TINYEMU_SLIRP)  $(TINYEMU_SRCS_C) \
	$(OBJS) \
	$(LDLIBS) -lpthread

# ================================================================

HS_MAIN_SRCS_H = $(SRC)/Memhex32_read.h  $(SRC)/Memhex32_read_protos.h \
		$(SRC)/SimpleQueue.h     $(SRC)/SimpleQueue_protos.h \
		$(SRC)/HS_syscontrol.h   $(SRC)/HS_syscontrol_protos.h \
		$(SRC)/HS_tty.h          $(SRC)/HS_tty_protos.h \
		$(SRC)/HS_pc_trace.h     $(SRC)/HS_pc_trace_protos.h \
		$(SRC)/HS_virtio.h       $(SRC)/HS_virtio_protos.h \
		$(SRC)/HS_gdbstub.h      $(SRC)/HS_gdbstub_protos.h \
		$(SRC)/HS_msg.h          $(SRC)/HS_msg_protos.h \
		$(SRC)/Bytevec.h  \
		$(SRC)/AWS_Sim_Lib.h     $(SRC)/AWS_Sim_Lib_protos.h \
		$(SRC)/TCP_Client_Lib.h  $(SRC)/TCP_Client_Lib_protos.h

HS_main.o: $(SRC)/HS_main.c  $(HS_MAIN_SRCS_H)
	$(CC) -c  -I $(SRC) $(TINYEMU_CFLAGS) -I $(TINYEMU)  -I $(TINYEMU_SLIRP) \
	-DSV_TEST  $(SRC)/HS_main.c

# ================================================================

HS_syscontrol.o: $(SRC)/HS_syscontrol.h  $(SRC)/HS_syscontrol.c  $(SRC)/HS_syscontrol_protos.h
	$(CC) -c  $(SRC)/HS_syscontrol.c

$(SRC)/HS_syscontrol_protos.h: $(SRC)/HS_syscontrol.c
	C_Proto_Extract.py  $(SRC)/HS_syscontrol.c

# ================================================================

HS_tty.o: $(SRC)/HS_tty.h  $(SRC)/HS_tty.c  $(SRC)/HS_tty_protos.h
	$(CC) -c  $(SRC)/HS_tty.c

$(SRC)/HS_tty_protos.h: $(SRC)/HS_tty.c
	C_Proto_Extract.py  $(SRC)/HS_tty.c

# ================================================================

HS_pc_trace.o: $(SRC)/HS_pc_trace.h  $(SRC)/HS_pc_trace.c  $(SRC)/HS_pc_trace_protos.h
	$(CC) -c  $(SRC)/HS_pc_trace.c

$(SRC)/HS_pc_trace_protos.h: $(SRC)/HS_pc_trace.c
	C_Proto_Extract.py  $(SRC)/HS_pc_trace.c

# ================================================================

HS_virtio.o: $(SRC)/HS_virtio.h  $(SRC)/HS_virtio.c  $(SRC)/HS_virtio_protos.h  $(SRC)/SimpleQueue.h
	$(CC) -c  $(TINYEMU_CFLAGS) -I $(TINYEMU)  -I $(TINYEMU_SLIRP) \
	$(SRC)/HS_virtio.c

$(SRC)/HS_virtio_protos.h: $(SRC)/HS_virtio.c
	C_Proto_Extract.py  $(SRC)/HS_virtio.c

# ================================================================

HS_gdbstub.o: $(SRC)/HS_gdbstub.h  $(SRC)/HS_gdbstub.c  $(SRC)/HS_gdbstub_protos.h
	$(CC) -c  $(SRC)/HS_gdbstub.c

$(SRC)/HS_gdbstub_protos.h: $(SRC)/HS_gdbstub.c
	C_Proto_Extract.py  $(SRC)/HS_gdbstub.c

# ================================================================

HS_msg.o: $(SRC)/HS_msg.h  $(SRC)/HS_msg.c  $(SRC)/HS_msg_protos.h
	$(CC) -c  $(SRC)/HS_msg.c

$(SRC)/HS_msg_protos.h: $(SRC)/HS_msg.c
	C_Proto_Extract.py  $(SRC)/HS_msg.c

# ================================================================

SimpleQueue.o: $(SRC)/SimpleQueue.h  $(SRC)/SimpleQueue.c  $(SRC)/SimpleQueue_protos.h
	$(CC) -c  $(SRC)/SimpleQueue.c

SimpleQueue_protos.h: $(SRC)/SimpleQueue.c
	C_Proto_Extract.py  $(SRC)/SimpleQueue.c

# ================================================================

AWS_Sim_Lib.o:  $(SRC)/AWS_Sim_Lib.h  $(SRC)/AWS_Sim_Lib_protos.h  $(SRC)/AWS_Sim_Lib.c
	$(CC) -c  $(SRC)/AWS_Sim_Lib.c

AWS_Sim_Lib_protos.h: $(SRC)/AWS_Sim_Lib.c
	C_Proto_Extract.py  $(SRC)/AWS_Sim_Lib.c

# ================================================================

Bytevec.o: $(SRC)/Bytevec.h  $(SRC)/Bytevec.c
	$(CC) -c  $(SRC)/Bytevec.c

# ================================================================

TCP_Client_Lib.o:  $(SRC)/TCP_Client_Lib.h  $(SRC)/TCP_Client_Lib_protos.h  $(SRC)/TCP_Client_Lib.c
	$(CC) -c  $(SRC)/TCP_Client_Lib.c

$(SRC)/TCP_Client_Lib_protos.h: $(SRC)/TCP_Client_Lib.c
	C_Proto_Extract.py  $(SRC)/TCP_Client_Lib.c

# ================================================================

Memhex32_read.o: $(SRC)/Memhex32_read.h  $(SRC)/Memhex32_read.c  $(SRC)/Memhex32_read_protos.h
	$(CC) -c  $(SRC)/Memhex32_read.c

$(SRC)/Memhex32_read_protos.h: $(SRC)/Memhex32_read.c
	C_Proto_Extract.py  $(SRC)/Memhex32_read.c

# ================================================================

.PHONY: clean
clean:
	rm -f  *.*~  Makefile*~  *.o

.PHONY: full_clean
full_clean:
	rm -f  *.*~  Makefile*~  *.o  exe_*

# ================================================================
