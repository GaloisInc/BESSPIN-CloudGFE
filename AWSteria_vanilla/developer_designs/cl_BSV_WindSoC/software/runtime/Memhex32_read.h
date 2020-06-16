#pragma once

// ================================================================

extern
int memhex32_read (char      *filename,
		   uint8_t   *buf,
		   uint64_t   buf_size,
		   uint64_t  *p_addr_base,
		   uint64_t  *p_addr_lim);

// ================================================================
