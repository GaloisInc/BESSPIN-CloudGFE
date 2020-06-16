// This file is generated automatically from the file 'Memhex32_read.c'
//     and contains 'extern' function prototype declarations for its functions.
// In any C source file using these functions, add:
//     #include 'Memhex32_read_protos.h'
// You may also want to create/maintain a file 'Memhex32_read.h'
//     containing #defines and type declarations.
// ****************************************************************

#pragma once

extern
int memhex32_read (char      *filename,
		   uint8_t   *buf,
		   uint64_t   buf_size,
		   uint64_t  *p_addr_base,
		   uint64_t  *p_addr_lim);
