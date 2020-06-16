# ================================================================

EXE    = exe_host_side

OBJS   = HS_main.o  Memhex32_read.o \
	HS_syscontrol.o  HS_tty.o  HS_virtio.o  HS_gdbstub.o  SimpleQueue.o \
	HS_msg.o  AWS_Sim_Lib.o  Bytevec.o  TCP_Client_Lib.o

$(EXE): $(OBJS)
	cc -g  -o $(EXE)  $(OBJS)

# ================================================================

H_SRCS = Memhex32_read.h  Memhex32_read_protos.h \
	SimpleQueue.h     SimpleQueue_protos.h \
	HS_syscontrol.h   HS_syscontrol_protos.h \
	HS_tty.h          HS_tty_protos.h \
	HS_virtio.h       HS_virtio_protos.h \
	HS_gdbstub.h      HS_gdbstub_protos.h \
	HS_msg.h          HS_msg_protos.h \
	Bytevec.h  \
	AWS_Sim_Lib.h     AWS_Sim_Lib_protos.h \
	TCP_Client_Lib.h  TCP_Client_Lib_protos.h

HS_main.o: HS_main.c  $(H_SRCS)
	cc -c  -DSV_TEST  HS_main.c

# ================================================================

HS_syscontrol.o: HS_syscontrol.h  HS_syscontrol.c  HS_syscontrol_protos.h
	cc -c HS_syscontrol.c

HS_syscontrol_protos.h: HS_syscontrol.c
	C_Proto_Extract.py  HS_syscontrol.c

# ================================================================

HS_tty.o: HS_tty.h  HS_tty.c  HS_tty_protos.h
	cc -c HS_tty.c

HS_tty_protos.h: HS_tty.c
	C_Proto_Extract.py  HS_tty.c

# ================================================================

HS_virtio.o: HS_virtio.h  HS_virtio.c  HS_virtio_protos.h
	cc -c HS_virtio.c

HS_virtio_protos.h: HS_virtio.c
	C_Proto_Extract.py  HS_virtio.c

# ================================================================

HS_gdbstub.o: HS_gdbstub.h  HS_gdbstub.c  HS_gdbstub_protos.h
	cc -c HS_gdbstub.c

HS_gdbstub_protos.h: HS_gdbstub.c
	C_Proto_Extract.py  HS_gdbstub.c

# ================================================================

HS_msg.o: HS_msg.h  HS_msg.c  HS_msg_protos.h
	cc -c HS_msg.c

HS_msg_protos.h: HS_msg.c
	C_Proto_Extract.py  HS_msg.c

# ================================================================

SimpleQueue.o: SimpleQueue.h  SimpleQueue.c  SimpleQueue_protos.h
	cc -c SimpleQueue.c

SimpleQueue_protos.h: SimpleQueue.c
	C_Proto_Extract.py  SimpleQueue.c

# ================================================================

AWS_Sim_Lib.o:  AWS_Sim_Lib.h  AWS_Sim_Lib_protos.h  AWS_Sim_Lib.c
	cc -c AWS_Sim_Lib.c

AWS_Sim_Lib_protos.h: AWS_Sim_Lib.c
	C_Proto_Extract.py  AWS_Sim_Lib.c

# ================================================================

Bytevec.o: Bytevec.h  Bytevec.c
	cc -c Bytevec.c

# ================================================================

TCP_Client_Lib.o:  TCP_Client_Lib.h  TCP_Client_Lib_protos.h  TCP_Client_Lib.c
	cc -c TCP_Client_Lib.c

TCP_Client_Lib_protos.h: TCP_Client_Lib.c
	C_Proto_Extract.py  TCP_Client_Lib.c

# ================================================================

Memhex32_read.o: Memhex32_read.h  Memhex32_read.c  Memhex32_read_protos.h
	cc -c Memhex32_read.c

Memhex32_read_protos.h: Memhex32_read.c
	C_Proto_Extract.py  Memhex32_read.c

# ================================================================

.PHONY: clean
clean:
	rm -f  *.*~  Makefile*~  *.o

.PHONY: full_clean
full_clean:
	rm -f  *.*~  Makefile*~  *.o  $(EXE)
