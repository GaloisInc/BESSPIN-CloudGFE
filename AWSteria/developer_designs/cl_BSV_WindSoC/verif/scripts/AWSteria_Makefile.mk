all:  prep  test

.PHONY: prep
prep:
	make -C ../../design  copy_BSV_lib_RTL  copy_RTL
	cat top.vivado.f_template  top.vivado.f_design_files > top.vivado.f

.PHONY: test
test:
	make  C_TEST=test_dram_dma_hwsw_cosim  AXI_MEMORY_MODEL=1  clean
	mylogsave log_make.txt  make  C_TEST=test_dram_dma_hwsw_cosim  AXI_MEMORY_MODEL=1 
