#pragma once
#include <stdint.h>

// returns start address
uint64_t loadElf(const char *elf_filename, uint64_t * tohost_addr);
