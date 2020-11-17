# Makefile to convert an ELF file into a memhex512 file for AWS' DDR4 A

# ================================================================
# ELF files to be converted

# ELF_DIR  ?= $(HOME)/git_clones/RISCV_Tests/GFE/c/
# ELF_FILE ?= rv64-hello

ELF_DIR  ?= $(HOME)/git_clones/RISCV_Tests/GFE/isa/
ELF_FILE ?= rv64ui-p-add

# ELF_DIR  ?= .
# ELF_FILE ?= bbl-riscv64.GFE

# ================================================================
# You need to point this at a standard Elf-to-MemHex32 converter

ELF_TO_HEX32 ?= $(HOME)/git_clones/RISCV_Tests/Elf_to_Hex/Elf_to_Hex32.exe

# ================================================================
# Parameters for Elfhex_to_Memhex.py
#     <o_file>  <o_width>  <o_base>  <o_mem_size>  <i_file_1>  ... <i_file_N>

ELFHEX_TO_MEMHEX ?= $(HOME)/git_clones/RISCV_Tests/Elf_to_Hex/Elfhex_to_Memhex.py

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
	@echo "Converting Elf file $(ELF_FILE) to $(ELF_FILE).memhex32"
	$(ELF_TO_HEX32)  $(ELF_DIR)/$(ELF_FILE)  $(ELF_FILE).memhex32
	@echo "----------------------------------------------------------------"
	@echo "Converting $(ELF_FILE).memhex32 to $(ELF_FILE).memhex512 for DDR4-load"
	$(ELFHEX_TO_MEMHEX) \
		$(ELF_FILE).memhex512 \
		$(DDR4_WIDTH) \
		$(DDR4_BASE_ADDR) \
		$(DDR4_MODEL_IMPLEMENTED_WORDS) \
		$(ELF_FILE).memhex32

clean:
	rm -r -f *.memhex32

full_clean:
	rm -r -f *.memhex32 	rm -r -f memhex512
