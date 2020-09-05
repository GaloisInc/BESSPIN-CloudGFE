#!/usr/bin/python3

# Copyright (c) 2020 Bluespec, Inc., All Rights Reserved
# Author: Rishiyur Nikhil

#    From an input file like:      fn_read_ROM_64.bsvi
#    creates an output file like:  boot_ROM_RV64.memhex

# This is a hack to reverse-engineer a memhex from fn_read_ROM_64.bsvi.

# Normally the .bsvi file might be created from a memhex file,
# but I don't have access to the original memhex file.

import sys
import fileinput

boot_ROM_base_addr = 0x_7000_0000

# ================================================================

def main (argv = None):
    if (len (argv) != 3) or (argv [1] == '-h') or (argv [1] == '--help'):
        print ("Usage:  {0}  <file_in:fn_read_ROM_64.bsvi>  <file_out:boot_ROM_RV64.memhex>".
               format (argv [0]))
        return 0

    try:
        f_in = open (argv [1], "r")
    except:
        sys.stdout.write ("ERROR: cannot open input file {s}\n".format (argv [1]));
        return 1

    try:
        f_out = open (argv [2], "w")
    except:
        sys.stdout.write ("ERROR: cannot open output file {s}\n".format (argv [2]));
        f_in.close()
        return 1

    lines = [line for line in f_in.readlines() if ((": 32" in line) and ("default" not in line))]

    sys.stdout.write ("Unsorted addrs and data\n")
    addrs_and_data = []
    for line in lines:
        separator = ": 32'h_"
        j = line.find (separator)
        if (j < 0):
            sys.stdout.write ("ERROR: No ':' found in this line {s}\n".format (line))
            return 1
        addr = int (line [:j])
        data = int (line [j + len (separator):-2], 16)
        sys.stdout.write ("addr {0}  data {1:08x}\n".format (addr, data))
        addrs_and_data.append ((addr, data))
        
    sys.stdout.write ("Sorted addrs and data\n")
    out_lines = []
    addrs_and_data_sorted = sorted (addrs_and_data)
    for (addr,data) in addrs_and_data_sorted:
        sys.stdout.write ("addr {0}  data {1:08x}\n".format (addr, data))
        out_lines.append ("{0:08x}\n".format (data))

    f_out.writelines (["@{0:08x}\n".format (boot_ROM_base_addr)]
                      + out_lines)
    sys.stdout.write ("Wrote mem hex to {0}\n".format(argv [2]))

    f_in.close()
    f_out.close()

    return 0

# ================================================================
# For non-interactive invocations, call main() and use its return value
# as the exit code.
if __name__ == '__main__':
  sys.exit (main (sys.argv))
