TEST   = test
SDK    = /export/home/stoy/git-repos/aws-fpga/sdk
HDK    = /export/home/stoy/git-repos/aws-fpga/hdk

H_SRCS = Memhex32_read.h  Bytevec.h  test_dram_dma_common.h  AWS_BS_Lib.h TCP_Client_Lib.h
C_SRCS = Memhex32_read.c  Bytevec.c  test_dram_dma_common.c  AWS_BS_Lib.c loadelf.c TCP_Client_Lib.c $(TEST).c

BSC_PATH = -I$(SDK)/userspace/include -I$(SDK)/userspace -I$(HDK)/common/software/include -I.
LIBS     = -L/usr/lib/x86_64-linux-gnu -lelf

$(TEST)_bsim:  $(C_SRCS)  $(H_SRCS)
	cc -DAWS_BSIM -g -o $(TEST)_bsim  $(BSC_PATH) $(C_SRCS) $(LIBS)

$(TEST)_aws:  $(C_SRCS)  $(H_SRCS)
	cc -DAWS_FPGA -g -o $(TEST)_fpga  $(BSC_PATH) $(C_SRCS) $(LIBS) -lfpga_mgmt

$(TEST)_xsim:  $(C_SRCS)  $(H_SRCS)
	cc -DAWS_XSIM -DSV_TEST -DVIVADO_SIM -g -o $(TEST)_bsim  $(BSC_PATH) $(C_SRCS) $(LIBS) -lfpga_mgmt

.PHONY: clean
clean:
	rm -f  *.*~  Makefile*~  *.o

.PHONY: full_clean
full_clean:
	rm -f  *.*~  Makefile*~  *.o $(TEST)_bsim $(TEST)_fpga
