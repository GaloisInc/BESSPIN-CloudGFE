#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <inttypes.h>
#include <string.h>
#include <stdbool.h>
#include <ctype.h>

#include "Memhex32_read.h"

// ================================================================
// Read mem-hex32 data from file into buf (seen as a byte-addressed
// mem from addr 0 onwards), and return the addr base and lim as well.

int memhex32_read (char      *filename,
		   uint8_t   *buf,
		   uint64_t   buf_size,
		   uint64_t  *p_addr_base,
		   uint64_t  *p_addr_lim)
{
    FILE *fd = fopen (filename, "r");
    if (fd == NULL) {
	fprintf (stdout, "memhex32_read ERROR: unable to open file: %s\n", filename);
	char *p = getenv ("PWD");
	if (p != NULL)
	    fprintf (stdout, "    PWD =  %s\n", p);
	goto err_return;
    }

    int       n;
    int       linenum = 1;
    uint64_t  x;
    uint64_t  addr_base, addr_lim, addr;
    addr      = 0;
    addr_lim  = 0;
    addr_base = (~ addr);
    
#define LINEBUFSIZE 64    
    char linebuf [LINEBUFSIZE], *p;

    while (true) {
	p = fgets (linebuf, LINEBUFSIZE, fd);
	if (p == NULL)
	    break;

	// fprintf (stdout, "L%0d: %s", linenum, linebuf);

	// Parse an address or data
	if (linebuf [0] == '@') {
	    n = sscanf (linebuf + 1, "%lx", & x);
	    // Note: in a memhex32 file, @x is an index of a 4-byte word, not a byte addr
	    if (n == 1) {
		if ((x << 2) < addr) {
		    fprintf (stdout, "WARNING on line %0d\n", linenum);
		    fprintf (stdout, "    Address 0x%0lx is < latest address 0x%0lx\n", x, addr);
		}
		addr = (x << 2);
		if (addr < addr_base) addr_base = addr;
		if (addr_lim < addr)  addr_lim  = addr;
	    }
	    else {
		fprintf (stdout, "ERROR on line %0d: syntax\n", linenum);
		fprintf (stdout, "    Error parsing address after '@'\n");
		goto err_return;
	    }
	}
	else if (isxdigit (linebuf [0])) {
	    n = sscanf (linebuf, "%lx", & x);
	    if (n == 1) {
		if (addr + 4 <= buf_size) {
		    uint32_t *p = (uint32_t *) (& buf [addr]);
		    *p = x;
		    addr = addr + 4;
		    if (addr_lim < addr) addr_lim = addr;
		}
		else {
		    fprintf (stdout, "ERROR on line %0d: addr %0lx out of buffer bounds\n",
			     linenum, addr);
		    fprintf (stdout, "    buffer size is: %0lx\n", buf_size);
		    goto err_return;
		}
	    }
	    else {
		fprintf (stdout, "ERROR on line %0d: syntax\n", linenum);
		fprintf (stdout, "    Error parsing data\n");
		goto err_return;
	    }
	}
	else {
	    // fprintf (stdout, "Skipping line %0d\n", linenum);
	    // fprintf (stdout, "Line: %s", linebuf);
	}

	// If the file line is longer than linebuf, skip the rest of the line.
	if ((strlen (linebuf) == (LINEBUFSIZE - 1))
	    && (linebuf [LINEBUFSIZE - 2] != '\n')) {
	    // fprintf (stdout, "Skipping long line\n");
	    while (true) {
		int ch = fgetc (fd);
		if (ch == '\n') {
		    linenum++;
		    break;
		}
		else {
		    ch = fgetc (fd);
		    if (ch == EOF)
			goto ok_return;
		}
	    }
	}
	else {
	    linenum++;
	}
    }

ok_return:
    *p_addr_base = addr_base;
    *p_addr_lim = addr_lim;
    return 0;

 err_return:
    return 1;
}

// ================================================================

#ifdef STANDALONE_TEST

#define BUF_SIZE 0x200000000llu

uint8_t buf [BUF_SIZE];

  int main (int argc, char *argv [])
{
    if (argc < 2) {
	fprintf (stdout, "Usage:    %s  <mem-hex filename>\n", argv [0]);
	return 0;
    }

    uint64_t addr_base, addr_lim;

    int retcode = memhex32_read (argv [1], buf, BUF_SIZE, & addr_base, & addr_lim);
    if (retcode != 0)
	return 1;

    fprintf (stdout, "@%0lx\n", addr_base);
    for (uint64_t addr = addr_base; addr < addr_lim; addr += 4) {
	uint32_t *p = (uint32_t *) (& buf [addr]);
	fprintf (stdout, "%08x\n", *p);
    }

    return 0;
}

#endif
