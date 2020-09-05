#!/usr/bin/python3

# Copyright (c) 2020 Bluespec, Inc., All Rights Reserved
# Author: Rishiyur Nikhil

import os
import sys
import fileinput

# ================================================================

cmd_line_args = "<i_file>  <o_width>  <o_base>  <o_mem_size>"
help_text = '''  where
    <i_file>      Filename for input memhex version of ELF file
                      (32-bit width, base-address 0)
    <o_width>     Bit-width of output memhex file (integer format; must be multiple of 8)
    <o_base>      Byte-address of start of output file data (integer or hex format)
    <o_mem_size>  Output memory size (memory words, not bytes; integer or hex format)

    Output filename in input filename but ending with .hex<o_width>.

'''

#    Command-line inputs:
#    Write an output mem-hex file of the desired width

def process_argv (argv):
    if (("-h" in argv) or ("--help" in argv)):
        sys.stdout.write ("Usage:  {0} {1}\n".format (argv [0], cmd_line_args))
        sys.stdout.write (help_text)
        return 0

    if (len (argv) != 5):
        sys.stdout.write ("ERROR: wrong number of command-line args\n")
        sys.stdout.write ("Usage:  {0} {1}\n".format (argv [0], cmd_line_args))
        sys.stdout.write (help_text)
        return 1

    # ----------------
    i_filename = argv [1]

    # ----------------
    try:
        o_width_b = int (argv [2])
    except:
        sys.stdout.write ("ERROR: Could not interpret {:s} as a bit-width\n".format (argv [2]))
        return 1

    # ----------------
    try:
        o_base_addr = int (argv [3], 0)
    except:
        sys.stdout.write ("ERROR: Could not interpret {:s} as a base-byte-addr\n".format (argv [3]))
        return 1

    # ----------------
    try:
        o_mem_size = int (argv [4], 0)
    except:
        sys.stdout.write ("ERROR: Could not interpret {:s} as a final index\n".format (argv [4]))
        return 1

    # ----------------
    return {"i_filename":  i_filename,
            "o_width_b":   o_width_b,
            "o_base_addr": o_base_addr,
            "o_mem_size":  o_mem_size}

# ================================================================

def main (argv = None):
    params = process_argv (argv)

    if (type (params) == int):
        return params

    i_filename  = params ["i_filename"]
    o_width_b   = params ["o_width_b"]
    o_base_addr = params ["o_base_addr"]
    o_mem_size  = params ["o_mem_size"]

    if ((o_width_b % 8) != 0):
        sys.stdout.write ("ERROR: Output bit-width ({:d}) is not a multiple of 8\n"
                          .format (o_width_b))
        return 1
    o_width_B = o_width_b // 8

    if (o_base_addr % o_width_B != 0):
        sys.stdout.write ("ERROR: Output base addr (0x{:_x}) is aligned for output byte-width ({:d})\n"
                          .format (o_width_b, o_width_B))
        return 1

    sys.stdout.write ("Input file:  '{:s}'\n".format (i_filename))
    sys.stdout.write ("    Assumed ELF image (width 32 bits, base byte-address 0x0)\n")

    o_width_b_s = "{:d}".format (o_width_b)
    i_file_basename = os.path.basename (i_filename)
    if (i_file_basename.endswith (".hex")):
        o_filename = i_file_basename + o_width_b_s
    elif (i_file_basename.endswith (".hex32")):
        o_filename = i_file_basename [:-2] + o_width_b_s
    else:
        o_filename = i_file_basename + ".hex" + o_width_b_s
    if (i_filename == o_filename):
        o_filename = o_filename + "_new"

    sys.stdout.write ("Output file: '{:s}'\n".format (o_filename))
    sys.stdout.write ("    Width {:0d} bits ({:0d} bytes)    Base byte-address 0x_{:_x}\n"
                      .format (o_width_b,
                               o_width_B,
                               o_base_addr))

    try:
        f_in = open (i_filename, "r")
    except:
        sys.stdout.write ("ERROR: cannot open input file '{:s}'\n".format (i_filename))
        return 1

    try:
        f_out = open (o_filename, "w")
    except:
        sys.stdout.write ("ERROR: cannot open output file '{:s}'\n".format (o_filename))
        f_in.close()
        return 1

    i_line_number = 0
    i_total_bytes = 0

    o_line_number = 0
    o_word_s      = ""
    o_bytes       = 0
    o_index       = 0

    while (True):
        i_line = f_in.readline()
        if (i_line == ""): break
        i_line_number = i_line_number + 1

        # sys.stdout.write ("L{:d}:{:s}".format (i_line_number, i_line))
        if i_line.lstrip().startswith ("@"):
            # Note: @... lines contain ram indexes, not byte addresses
            try:
                i_index = int (i_line [1:], 16)
            except:
                sys.stdout.write ("ERROR: unable to parse index line\n")
                sys.stdout.write ("L{:0d}:{:s}".format (i_line_number, i_line))
                return 1

            addr    = i_index * 4

            sys.stdout.write ("Input word index 0x_{:_x}\n".format (i_index))
            sys.stdout.write ("Byte addr        0x_{:_x}\n".format (addr))
            if (addr % o_width_B != 0):
                sys.stdout.write ("ERROR: this is not aligned for an output index\n")
                return 1

            o_index = (addr - o_base_addr) // o_width_B
            sys.stdout.write ("Ouput word index 0x_{:_x}\n".format (o_index))
            f_out.write ("@{:08x}\n".format (o_index))
            o_line_number += 1
        else:
            # Data word
            try:
                word32 = int (i_line, 16)
            except:
                sys.stdout.write ("ERROR: unable to parse data word\n")
                sys.stdout.write ("L{:0d}:{:s}".format (i_line_number, i_line))
                break
            i_total_bytes += 4
            word32_s       = "{:08x}".format (word32)
            o_word_s       = word32_s + o_word_s
            o_bytes       += 4
            while (o_bytes >= o_width_B):
                f_out.write ("{:s}\n".format (o_word_s [-(o_width_B*2):]))
                o_line_number += 1
                o_index       += 1
                o_word_s       = o_word_s [:-(o_width_B*2)]
                o_bytes       -= o_width_B

    trailing_bytes = o_bytes
    if (o_bytes != 0):
        sys.stdout.write ("Padding trailing {:0d} bytes to {:0d} bytes\n".format (o_bytes, o_width_B))
        o_word_s = ((o_width_B - o_bytes) * "00") + o_word_s
        f_out.write ("{:s}\n".format (o_word_s))
        o_line_number += 1
        o_index       += 1
        trailing_bytes = o_width_B - o_bytes

    sys.stdout.write ("Written up to index {:d}\n".format (o_index))
    if (o_index < o_mem_size):
        sys.stdout.write ("Adding trailer for final index 0x{:x} ({:d})\n".format (o_mem_size - 1, o_mem_size - 1))
        f_out.write ("@{:x}\n".format (o_mem_size - 1))
        f_out.write ("0\n")

    sys.stdout.write ("Wrote output file: {0}\n".format(o_filename))
    sys.stdout.write ("Input:  {:10d} lines {:12d} bytes\n".format (i_line_number,
                                                                    i_total_bytes))
    sys.stdout.write ("Output: {:10d} lines {:12d} bytes\n".format (o_line_number,
                                                                    i_total_bytes + trailing_bytes))
    f_in.close()
    f_out.close()

    return 0

# ================================================================
# For non-interactive invocations, call main() and use its return value
# as the exit code.
if __name__ == '__main__':
  sys.exit (main (sys.argv))
