# Generate Verilog for AWSteria_Core_Empty

# ================================================================

.PHONY: help
help:
	@echo "Usage:  make  gen_RTL        Generates an empty mkAWSteria_Core.v in Verilog_RTL/"

# ================================================================

# For Semi_FIFOF
BSC_PATH := $(BSC_PATH):$(HOME)/git_clones/Flute/src_Core/BSV_Additional_Libs

# For AXI4_Types and AXI4_Lite_Types
BSC_PATH := $(BSC_PATH):$(HOME)/git_clones/Flute/src_Testbench/Fabrics/AXI4
BSC_PATH := $(BSC_PATH):$(HOME)/git_clones/Flute/src_Testbench/Fabrics/AXI4_Lite

# For bsc standard libs
BSC_PATH := $(BSC_PATH):+

RTL_GEN_DIRS = -vdir Verilog_RTL  -bdir build_dir  -info-dir build_dir  -simdir build_dir

TOPFILE = AWSteria_Core_Empty.bsv

# ================================================================

.PHONY: gen_RTL
gen_RTL:
	mkdir -p  build_dir
	mkdir -p  Verilog_RTL
	@echo "INFO: generating Verilog RTL for hierarcy at $(TOPFILE) ..."
	bsc  -u -elab -verilog $(RTL_GEN_DIRS) $(BSC_COMPILATION_FLAGS)  -p $(BSC_PATH) $(TOPFILE)
	@echo "INFO: generated Verilog RTL for hierarcy at $(TOPFILE) ..."

# ================================================================

.PHONY: clean
clean:
	rm -r -f  *~

.PHONY: full_clean
full_clean:
	rm -r -f  *~  Verilog_RTL  build_dir
