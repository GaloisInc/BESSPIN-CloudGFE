# Makefile to convert an ELF file into:
#     a hex32 file for AWS' host-side
#     a memhex512 file for AWS' DDR4 A (for AWSteria standalone)

# ================================================================
# ELF files to be converted

# ELF_DIR  ?= $(HOME)/git_clones/RISCV_Tests/GFE/c
# ELF_FILE ?= rv64-hello

ELF_DIR  ?= $(HOME)/git_clones/RISCV_Tests/GFE/c
ELF_FILE ?= rv64-cat

# ELF_DIR ?= $(HOME)/git_clones/RISCV_Tests/GFE/isa
# ELF_FILE ?= rv64ui-p-add
# ELF_FILE ?= rv64ui-v-add

# ELF_DIR  ?= $(HOME)/git_clones/RISCV_Tests/GFE/FreeRTOS
# ELF_FILE ?= freertos1000.elf

# ELF_DIR   ?= $(HOME)/git_clones/RISCV_Tests/GFE/FreeBSD_2020-09-03/
# ELF_FILE  ?= bbl-riscv64
# ELF_FILE2 ?= kernel-riscv64.GFE-NODEBUG

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

$(ELF_FILE).hex32:
	@echo "----------------------------------------------------------------"
	@echo "Converting Elf file"
	@echo "    $(ELF_FILE)"
	@echo "to  $(ELF_FILE).hex32 (zero offset)"
	$(ELF_TO_HEX32)  $(ELF_DIR)/$(ELF_FILE)  $(ELF_FILE).hex32

# For single ELF files

$(ELF_FILE).memhex512: $(ELF_FILE).hex32
	@echo "----------------------------------------------------------------"
	@echo "Converting $(ELF_FILE).hex32 (zero offset) to $(ELF_FILE).memhex512"
	$(ELFHEX_TO_MEMHEX) \
		$(ELF_FILE).memhex512 \
		$(DDR4_WIDTH) \
		$(DDR4_BASE_ADDR) \
		$(DDR4_MODEL_IMPLEMENTED_WORDS) \
		$(ELF_FILE).hex32

# For two ELF files

$(ELF_FILE)_and_$(ELF_FILE2).hex32: $(ELF_FILE).hex32  $(ELF_FILE2).hex32
	@echo "----------------------------------------------------------------"
	@echo "Converting $(ELF_FILE).hex32 (zero offset)"
	@echo "    and    $(ELF_FILE2).hex32 (zero offset)"
	@echo "    to     $(ELF_FILE)_and_$(ELF_FILE2).hex32 (zero offset)"
	cat  $(ELF_FILE).hex32  $(ELF_FILE2).hex32 > $(ELF_FILE)_and_$(ELF_FILE2).hex32

$(ELF_FILE)_and_$(ELF_FILE2).memhex512: $(ELF_FILE).hex32  $(ELF_FILE2).hex32
	@echo "----------------------------------------------------------------"
	@echo "Converting $(ELF_FILE).hex32 (zero offset)"
	@echo "    and    $(ELF_FILE2).hex32 (zero offset)"
	@echo "    to     $(ELF_FILE)_and_$(ELF_FILE2).memhex512"
	$(ELFHEX_TO_MEMHEX) \
		$(ELF_FILE)_and_$(ELF_FILE2).memhex512 \
		$(DDR4_WIDTH) \
		$(DDR4_BASE_ADDR) \
		$(DDR4_MODEL_IMPLEMENTED_WORDS) \
		$(ELF_FILE).hex32  $(ELF_FILE2).hex32

clean:
	rm -r -f *.memhex32

full_clean:
	rm -r -f *.memhex32 	rm -r -f memhex512
