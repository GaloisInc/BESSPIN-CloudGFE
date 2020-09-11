#!/usr/bin/python3

# Copyright (c) 2020 Bluespec, Inc., All Rights Reserved
# Author: Rishiyur Nikhil

import os
import sys
import fileinput

# ================================================================

cmd_line_args = "<o_file>  <o_width>  <o_base>  <o_mem_size>  <i_file_1>  ... <i_file_N>"
help_text = '''  where
    <o_file>      Output filename (typically ending with Mem.hex<o_width>)
    <o_width>     Bit-width of output memhex file (integer format; must be multiple of 8)
    <o_base>      Byte-address of start of output file data (integer or hex format)
    <o_mem_size>  Output memory size (memory words, not bytes; integer or hex format)

    <i_file> ...  One or more filenames for input memhex version of ELF file
    <i_file>          (32-bit width, base-address 0)
                      (typically ending with .Mem.hex32)
'''

# ================================================================

def main (argv = None):
    params = process_argv (argv)

    if (type (params) == int):
        return params

    if ((params ["o_width_b"] % 8) != 0):
        sys.stdout.write ("ERROR: Output bit-width ({:d}) is not a multiple of 8\n"
                          .format (params ["o_width_b"]))
        return 1
    params ["o_width_B"] = params ["o_width_b"] // 8

    if (params ["o_base_addr"] % params ["o_width_B"] != 0):
        sys.stdout.write ("ERROR: Output base addr (0x{:_x}) is aligned for output byte-width ({:d})\n"
                          .format (params ["o_width_b"], params ["o_width_B"]))
        return 1

    sys.stdout.write ("Output file: '{:s}'\n".format (params ["o_filename"]))
    sys.stdout.write ("    Width {:0d} bits ({:0d} bytes)    Base byte-address 0x_{:_x}\n"
                      .format (params ["o_width_b"],
                               params ["o_width_B"],
                               params ["o_base_addr"]))

    try:
        params ["f_out"] = open (params ["o_filename"], "w")
    except:
        sys.stdout.write ("ERROR: cannot open output file '{:s}'\n".format (params ["o_filename"]))
        f_in.close()
        return 1

    params ["i_total_bytes"] = 0
    params ["i_total_lines"] = 0

    params ["o_line_number"] = 0
    params ["o_index"]       = 0

    # Process all input files
    ok = True
    for f in params ["i_filenames"]:
        ok = ok and process_input_file (f, params)
        if not ok: return 1

    sys.stdout.write ("Written up to index {:d}\n".format (params ["o_index"]))
    if (params ["o_index"] < params ["o_mem_size"]):
        sys.stdout.write ("Adding trailer for final index 0x{:x} ({:d})\n"
                          .format (params ["o_mem_size"] - 1, params ["o_mem_size"] - 1))
        params ["f_out"].write ("@{:x}\n".format (params ["o_mem_size"] - 1))
        params ["f_out"].write ("0\n")
        params ["o_line_number"] += 2

    elif (params ["o_index"] > params ["o_mem_size"]):
        sys.stdout.write ("WARNING: last output index was {:d}\n".format (params ["o_index"]))
        sys.stdout.write ("         > output memory size  {:d}\n".format (params ["o_mem_size"]))

    sys.stdout.write ("Wrote output file: {0}\n".format(params ["o_filename"]))
    sys.stdout.write ("Input:  {:10d} lines {:12d} bytes\n"
                      .format (params ["i_total_lines"], params ["i_total_bytes"]))
    sys.stdout.write ("Output: {:10d} lines\n".format (params ["o_line_number"]))
    params ["f_out"].close()

    return 0

# ================================================================

def process_input_file (i_filename, params):
    sys.stdout.write ("----------------\n")
    sys.stdout.write ("Input Mem.hex32 file:  '{:s}'\n".format (i_filename))
    sys.stdout.write ("    (assumed width 32 bits, base byte-address 0x0)\n")

    try:
        f_in = open (i_filename, "r")
    except:
        sys.stdout.write ("ERROR: cannot open input file '{:s}'\n".format (i_filename))
        return False

    i_line_number = 0
    i_index       = 0
    o_word_s      = ""
    o_bytes       = 0    # number of bytes in o_word_s

    while (True):
        i_line = f_in.readline()
        if (i_line == ""): break
        i_line_number = i_line_number + 1

        i_line = i_line.lstrip ()

        # sys.stdout.write ("L{:d}:{:s}".format (i_line_number, i_line))
        if i_line.startswith ("@"):
            # Note: @... lines contain ram indexes, not byte addresses
            try:
                new_i_index = int (i_line [1:], 16)
                if (new_i_index < i_index):
                    sys.stdout.write ("WARNING: input file {:s}"
                                      .format (i_line_number, i_filename))
                    sys.stdout.write ("  L{:d}:{:s}".format (i_line_number, i_line))
                    sys.stdout.write ("  Address is being bumped down\n")
                i_index = new_i_index
            except:
                sys.stdout.write ("ERROR: unable to parse index line\n")
                sys.stdout.write ("L{:0d}:{:s}".format (i_line_number, i_line))
                f_in.close()
                return False

            addr = i_index * 4

            sys.stdout.write ("  Input addr line: word index 0x_{:_x}\n".format (i_index))
            sys.stdout.write ("  Byte addr                   0x_{:_x}\n".format (addr))
            if (addr % params ["o_width_B"] != 0):
                sys.stdout.write ("ERROR: this is not aligned for an output index\n")
                f_in.close()
                return False

            # Write address line in output file
            params ["o_index"] = (addr - params ["o_base_addr"]) // params ["o_width_B"]
            sys.stdout.write ("  Ouput addr line: word index 0x_{:_x}\n".format (params ["o_index"]))
            params ["f_out"].write ("@{:08x}\n".format (params ["o_index"]))
            params ["o_line_number"] += 1

        elif (len (i_line) > 0) and (ishexdigit (i_line [0])):
            # Collect data word into o_word_S
            try:
                word32 = int (i_line, 16)
            except:
                sys.stdout.write ("ERROR: unable to parse data word\n")
                sys.stdout.write ("L{:0d}:{:s}".format (i_line_number, i_line))
                f_in.close()
                return False
            params ["i_total_bytes"]  += 4

            word32_s = "{:08x}".format (word32)
            o_word_s = word32_s + o_word_s
            o_bytes += 4

            # Dump bytes from o_word_S if collected enough bytes
            while (o_bytes >= params ["o_width_B"]):
                params ["f_out"].write ("{:s}\n".format (o_word_s [-(params ["o_width_B"] * 2):]))
                params ["o_line_number"] += 1
                params ["o_index"]       += 1
                o_bytes                  -= params ["o_width_B"]
                o_word_s                  = o_word_s [:-(params ["o_width_B"] * 2)]
        else:
            # Neither an '@' line nor a data line; ignore it
            pass

    params ["i_total_lines"] += i_line_number
    # If any trailing data bytes in last output word, pad with zeros and write them out
    trailing_bytes = o_bytes
    if (o_bytes != 0):
        sys.stdout.write ("Padding trailing {:0d} bytes to {:0d} bytes\n"
                          .format (o_bytes, params ["o_width_B"]))
        o_word_s = ((params ["o_width_B"] - o_bytes) * "00") + o_word_s
        params ["f_out"].write ("{:s}\n".format (o_word_s))
        params ["o_line_number"] += 1
        params ["o_index"]       += 1

    f_in.close()
    return True

# ================================================================

def process_argv (argv):
    if (("-h" in argv) or ("--help" in argv)):
        sys.stdout.write ("Usage: {0}  {1}\n".format (argv [0], cmd_line_args))
        sys.stdout.write (help_text)
        return 0

    if (len (argv) < 6):
        sys.stdout.write ("ERROR: wrong number of command-line args\n")
        sys.stdout.write ("Usage: {0}  {1}\n".format (argv [0], cmd_line_args))
        sys.stdout.write (help_text)
        return 1

    # ----------------
    o_filename = argv [1]

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
    i_filenames = argv [5:]

    # ----------------
    return {"o_filename":  o_filename,
            "o_width_b":   o_width_b,
            "o_base_addr": o_base_addr,
            "o_mem_size":  o_mem_size,
            "i_filenames": i_filenames}

# ================================================================

def ishexdigit (s):
    for x in s:
        if x not in "0123456789abcdefABCDEF": return False
    return True

# ================================================================
# For non-interactive invocations, call main() and use its return value
# as the exit code.
if __name__ == '__main__':
  sys.exit (main (sys.argv))
