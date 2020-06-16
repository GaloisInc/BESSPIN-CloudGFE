// Copyright (c) 2013-2019 Bluespec, Inc. All Rights Reserved

// This program reads an ELF file into an in-memory byte-array.
// This can then sent to a debugger.

// ================================================================
// Standard C includes

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <inttypes.h>
#include <string.h>
#include <fcntl.h>
#include <gelf.h>

// ================================================================
// Features of the ELF binary

typedef struct {
    uint8_t  *mem_buf;
    int       bitwidth;
    uint64_t  min_addr;
    uint64_t  max_addr;

    uint64_t  pc_start;       // Addr of label  '_start'
    uint64_t  pc_exit;        // Addr of label  'exit'
    uint64_t  tohost_addr;    // Addr of label  'tohost'
} Elf_Features;

// ================================================================
// Read the ELF file into the array buffer

#define  RESULT_OK   0
#define  RESULT_ERR  1

// ================================================================
// Memory buffer into which we load the ELF file.

// Supports addrs from 0..4GB
#define MAX_MEM_SIZE ((uint64_t) 0x100000000)

static uint8_t mem_buf [MAX_MEM_SIZE];

// ================================================================
// Load an ELF file.

static
int c_mem_load_elf (const char    *elf_filename,
		    const char    *start_symbol,
		    const char    *exit_symbol,
		    const char    *tohost_symbol,
		    Elf_Features  *p_features)
{
    int fd;
    // int n_initialized = 0;
    Elf *e;

    // Default start, exit and tohost symbols
    if (start_symbol == NULL)
	start_symbol = "_start";
    if (exit_symbol == NULL)
	exit_symbol = "exit";
    if (tohost_symbol == NULL)
	tohost_symbol = "tohost";
    
    // Verify the elf library version
    if (elf_version (EV_CURRENT) == EV_NONE) {
	fprintf (stdout,
		 "ERROR: c_mem_load_elf: Failed to initialize the libelf library.\n");
	return RESULT_ERR;
    }

    // Open the file for reading
    fd = open (elf_filename, O_RDONLY, 0);
    if (fd < 0) {
	fprintf (stdout,
		 "ERROR: c_mem_load_elf: could not open elf input file: %s\n",
		 elf_filename);
	return RESULT_ERR;
    }

    // Initialize the Elf pointer with the open file
    e = elf_begin (fd, ELF_C_READ, NULL);
    if (e == NULL) {
	fprintf (stdout,
		 "ERROR: c_mem_load_elf: elf_begin() initialization failed!\n");
	return RESULT_ERR;
    }

    // Verify that the file is an ELF file
    if (elf_kind (e) != ELF_K_ELF) {
        elf_end (e);
	fprintf (stdout,
		 "ERROR: c_mem_load_elf: specified file '%s' is not an ELF file!\n",
		 elf_filename);
	return RESULT_ERR;
    }

    // Get the ELF header
    GElf_Ehdr ehdr;
    if (gelf_getehdr (e, & ehdr) == NULL) {
        elf_end (e);
	fprintf (stdout,
		 "ERROR: c_mem_load_elf: get_getehdr() failed: %s\n",
		 elf_errmsg (-1));
	return RESULT_ERR;
    }

    // Is this a 32b or 64 ELF?
    if (gelf_getclass (e) == ELFCLASS32) {
	fprintf (stdout, "c_mem_load_elf: %s is a 32-bit ELF file\n", elf_filename);
	p_features->bitwidth = 32;
    }
    else if (gelf_getclass (e) == ELFCLASS64) {
	fprintf (stdout, "c_mem_load_elf: %s is a 64-bit ELF file\n", elf_filename);
	p_features->bitwidth = 64;
    }
    else {
	fprintf (stdout,
		 "ERROR: c_mem_load_elf: ELF file '%s' is not 32b or 64b\n",
		 elf_filename);
	elf_end (e);
	return RESULT_ERR;
    }

    // Verify we are dealing with a RISC-V ELF
    if (ehdr.e_machine != 243) {
	// EM_RISCV is not defined, but this returns 243 when used with a valid elf file.
        elf_end (e);
	fprintf (stdout,
		 "ERROR: c_mem_load_elf: %s is not a RISC-V ELF file\n",
		 elf_filename);
	return RESULT_ERR;
    }

    // Verify we are dealing with a little endian ELF
    if (ehdr.e_ident[EI_DATA] != ELFDATA2LSB) {
        elf_end (e);
	fprintf (stdout,
		 "ERROR: c_mem_load_elf: %s is big-endian 64-bit RISC-V executable, not supported\n",
		 elf_filename);
	return RESULT_ERR;
    }

    // Grab the string section index
    size_t shstrndx;
    shstrndx = ehdr.e_shstrndx;

    // Iterate through each of the sections looking for code that should be loaded
    Elf_Scn  *scn   = 0;
    GElf_Shdr shdr;

    p_features->min_addr    = 0xFFFFFFFFFFFFFFFFllu;
    p_features->max_addr    = 0x0000000000000000llu;
    p_features->pc_start    = 0xFFFFFFFFFFFFFFFFllu;
    p_features->pc_exit     = 0xFFFFFFFFFFFFFFFFllu;
    p_features->tohost_addr = 0xFFFFFFFFFFFFFFFFllu;

    while ((scn = elf_nextscn (e,scn)) != NULL) {
        // get the header information for this section
        gelf_getshdr (scn, & shdr);

	char *sec_name = elf_strptr (e, shstrndx, shdr.sh_name);
	fprintf (stdout, "Section %-16s: ", sec_name);

	Elf_Data *data = 0;
	// If we find a code/data section, load it into the model
	if (   ((shdr.sh_type == SHT_PROGBITS)
		|| (shdr.sh_type == SHT_NOBITS)
		|| (shdr.sh_type == SHT_INIT_ARRAY)
		|| (shdr.sh_type == SHT_FINI_ARRAY))
	    && ((shdr.sh_flags & SHF_WRITE)
		|| (shdr.sh_flags & SHF_ALLOC)
		|| (shdr.sh_flags & SHF_EXECINSTR))) {
	    data = elf_getdata (scn, data);

	    // n_initialized += data->d_size;
	    if (shdr.sh_addr < p_features->min_addr)
		p_features->min_addr = shdr.sh_addr;
	    if (p_features->max_addr < (shdr.sh_addr + data->d_size - 1))   // shdr.sh_size + 4))
		p_features->max_addr = shdr.sh_addr + data->d_size - 1;    // shdr.sh_size + 4;

	    if (p_features->max_addr >= MAX_MEM_SIZE) {
		fprintf (stdout,
			 "INTERNAL ERROR: addr 0x%0" PRIx64 " in ELF file is too large.\n",
			 p_features->max_addr);
		fprintf (stdout,
			 "    This program has: #define MAX_MEM_SIZE  0x%0" PRIx64 "\n",
			 MAX_MEM_SIZE);
		fprintf (stdout,
			 "    Please increase this, recompile, and re-run\n");
		return RESULT_ERR;
	    }

	    if (shdr.sh_type != SHT_NOBITS) {
		memcpy (& (mem_buf [shdr.sh_addr]), data->d_buf, data->d_size);
	    }
	    fprintf (stdout, "addr %16" PRIx64 " to addr %16" PRIx64 "; size 0x%8lx (= %0ld) bytes\n",
		     shdr.sh_addr, shdr.sh_addr + data->d_size, data->d_size, data->d_size);
	}

	// If we find the symbol table, search for symbols of interest
	else if (shdr.sh_type == SHT_SYMTAB) {
	    fprintf (stdout, "Searching for addresses of '%s', '%s' and '%s' symbols\n",
		     start_symbol, exit_symbol, tohost_symbol);

 	    // Get the section data
	    data = elf_getdata (scn, data);

	    // Get the number of symbols in this section
	    int symbols = shdr.sh_size / shdr.sh_entsize;

	    // search for the uart_default symbols we need to potentially modify.
	    GElf_Sym sym;
	    int i;
	    for (i = 0; i < symbols; ++i) {
	        // get the symbol data
	        gelf_getsym (data, i, &sym);

		// get the name of the symbol
		char *name = elf_strptr (e, shdr.sh_link, sym.st_name);

		// Look for, and remember PC of the start symbol
		if (strcmp (name, start_symbol) == 0) {
		    p_features->pc_start = sym.st_value;
		}
		// Look for, and remember PC of the exit symbol
		else if (strcmp (name, exit_symbol) == 0) {
		    p_features->pc_exit = sym.st_value;
		}
		// Look for, and remember addr of 'tohost' symbol
		else if (strcmp (name, tohost_symbol) == 0) {
		    p_features->tohost_addr = sym.st_value;
		}
	    }

	    fprintf (stdout, "Symbols of interest\n");

	    fprintf (stdout, "    _start");
	    if (p_features->pc_start == -1)
		fprintf (stdout, "    Not found\n");
	    else
		fprintf (stdout, "    0x%0" PRIx64 "\n", p_features->pc_start);

	    fprintf (stdout, "    exit  ");
	    if (p_features->pc_exit == -1)
		fprintf (stdout, "    Not found\n");
	    else
		fprintf (stdout, "    0x%0" PRIx64 "\n", p_features->pc_exit);

	    fprintf (stdout, "    tohost");
	    if (p_features->tohost_addr == -1)
		fprintf (stdout, "    Not found\n");
	    else
		fprintf (stdout, "    0x%0" PRIx64 "\n", p_features->tohost_addr);
	}
	else {
	    fprintf (stdout, "ELF section ignored\n");
	}
    }

    elf_end (e);

    p_features->mem_buf = & (mem_buf [0]);

    fprintf (stdout, "Min addr:            %16" PRIx64 " (hex)\n", p_features->min_addr);
    fprintf (stdout, "Max addr:            %16" PRIx64 " (hex)\n", p_features->max_addr);
    return RESULT_OK;
}

// ================================================================
// Read the ELF file into the array buffer

int elf_readfile (const  char   *elf_filename,
		  Elf_Features  *p_features)
{
    // Zero out the memory buffer before loading the ELF file
    bzero (mem_buf, MAX_MEM_SIZE);

    return c_mem_load_elf (elf_filename, "_start", "exit", "tohost", p_features);
}

// ================================================================

int main (int argc, char *argv [])
{
    if (argc < 3) {
	fprintf (stdout, "Usage:    %s  <elf_file_name>  <mem_hex_file_name>\n", argv [0]);
	return 1;
    }

    Elf_Features  elf_features;

    int retcode = elf_readfile (argv [1], & elf_features);
    if (retcode != 0)
	return 1;

    fprintf (stdout, "min_addr = %0lx\n", elf_features.min_addr);
    fprintf (stdout, "max_addr = %0lx\n", elf_features.max_addr);

    fprintf (stdout, "Writing memhex file: %s\n", argv [2]);
    FILE *fout = fopen (argv [2], "w");
    if (fout == NULL) {
	fprintf (stdout, "ERROR: unable to open file for writing: %s\n", argv [2]);
	return 1;
    }

    fprintf (fout, "@%0lx\n", elf_features.min_addr);
    for (uint64_t addr = elf_features.min_addr; addr < elf_features.max_addr; addr += 4) {
	uint32_t *p = (uint32_t *) (elf_features.mem_buf + addr);
	fprintf (fout, "%08x\n", *p);
    }
    fclose (fout);
    fprintf (stdout, "Memhex file written: %s\n", argv [2]);

    return 0;
}
