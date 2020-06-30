all:  prep  test

.PHONY: prep
prep:
	make -C ../../design  copy_BSV_lib_RTL  copy_RTL
	cat top.vivado.f_template  top.vivado.f_design_files > top.vivado.f

.PHONY: test
test:
	make  C_TEST=test  AXI_MEMORY_MODEL=1  clean
	make  C_TEST=test  AXI_MEMORY_MODEL=1
