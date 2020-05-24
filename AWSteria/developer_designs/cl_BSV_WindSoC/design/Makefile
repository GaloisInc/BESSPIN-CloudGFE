# Copies design RTL from development dir and BLUESPECDIR to here
# Also prepares 

# This def points at the dir with the RTL generated from the BSV code
RTL_DIR = ../../../builds/RV64ACDFIMSU_Flute_verilator_AWS/Verilog_RTL

# BLUESPECDIR should point at the bsc installation library, from where
# we copy certain RTL files

all: copy_RTL  copy_BSV_lib_RTL

.PHONY: copy_RTL
copy_RTL:
	@echo "Copying from RTL_DIR = $(RTL_DIR)"
	cp -p  $(RTL_DIR)/*.v  .
	rm  mkTop_HW_Side*  mkMem_Model*  mkComms*
	ls -1  mk*.v > AA_design_files.txt
	sed  -f AA_sed_script.txt  AA_design_files.txt  > ../verif/scripts/top.vivado.f_design_files
	rm  -f AA_design_files.txt

.PHONY: copy_BSV_lib_RTL
copy_BSV_lib_RTL:
	@echo "Copying from BLUESPECDIR = $(BLUESPECDIR)"
	cp -p  $(BLUESPECDIR)/Verilog/BRAM2.v        .
	cp -p  $(BLUESPECDIR)/Verilog/FIFO2.v        .
	cp -p  $(BLUESPECDIR)/Verilog/FIFO20.v       .
	cp -p  $(BLUESPECDIR)/Verilog/FIFOL1.v       .
	cp -p  $(BLUESPECDIR)/Verilog/RegFile.v      .
	cp -p  $(BLUESPECDIR)/Verilog/SizedFIFO.v    .

clean:
	rm -f  *~  AA_design_files.txt

full_clean:
	rm -f  *~  AA_design_files.txt  mk*.v  *FIFO*.v  BRAM*.v  RegFile.v
