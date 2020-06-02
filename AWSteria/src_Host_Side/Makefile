TEST   = test

H_SRCS = Memhex32_read.h  Bytevec.h  test_dram_dma_common.h  AWS_Sim_Lib.h TCP_Client_Lib.h
C_SRCS = $(TEST).c  Memhex32_read.c  Bytevec.c  test_dram_dma_common.c  AWS_Sim_Lib.c TCP_Client_Lib.c

$(TEST):  $(C_SRCS)  $(H_SRCS)
	cc -g -o $(TEST)  -DAWSTERIA_SIM  -DSV_TEST  $(C_SRCS)

.PHONY: clean
clean:
	rm -f  *.*~  Makefile*~  *.o

.PHONY: full_clean
full_clean:
	rm -f  *.*~  Makefile*~  *.o  $(TEST)
