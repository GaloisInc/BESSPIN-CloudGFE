# Makefile to convert an ELF file into a Mem.hex512 file for AWS' DDR4 A

# ELF_DIR  ?= $(HOME)/git_clones/RISCV_Tests/GFE/c/
# ELF_FILE ?= rv64-hello

# ELF_DIR  ?= $(HOME)/git_clones/RISCV_Tests/GFE/isa/
# ELF_FILE ?= rv64ui-p-add

ELF_DIR  ?= .
ELF_FILE ?= bbl-riscv64.GFE

# ================================================================
# You need to point this at a standard Elf-to-MemHex32 converter

ELF_TO_HEX32 ?= Elf_to_Hex32

# ================================================================
# Parameters for Elfhex_to_Memhex.py

# Width of DDR4 in bits
DDR4_WIDTH                   ?= 512

# Base byte-address implemented by this DDR4
DDR4_BASE_ADDR               ?= 0

# Number of 512-bit-wide words implemented by this DDR4
# See 'implemented_words' in 'src_Testbench/Top/AWS_DDR4_Model.bsv'

DDR4_MODEL_IMPLEMENTED_WORDS ?= 0x_0400_0000

# ================================================================

default:
	@echo "----------------------------------------------------------------"
	@echo "Converting Elf file $(ELF_FILE) to $(ELF_FILE).Mem.hex32"
	$(ELF_TO_HEX32)  $(ELF_DIR)/$(ELF_FILE)  $(ELF_FILE).Mem.hex32
	@echo "----------------------------------------------------------------"
	@echo "Converting $(ELF_FILE).Mem.hex32 to $(ELF_FILE).Mem.hex512 for DDR4-load"
	./Elfhex_to_Memhex.py  $(ELF_FILE).Mem.hex32  $(DDR4_WIDTH)  $(DDR4_BASE_ADDR)  $(DDR4_MODEL_IMPLEMENTED_WORDS)
