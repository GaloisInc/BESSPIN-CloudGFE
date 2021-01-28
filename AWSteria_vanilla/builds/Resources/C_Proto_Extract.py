#!/usr/bin/python3

# Copyright (c) 2019-2020 Rishiyur S. Nikhil, All Rights Reserved

# ================================================================
# Program to extract extern (non-static) function prototypes from
# a file foo.c, outputting 'extern' prototypes to foo_protos.h.

# Note, this does not do a full C parse, and uses lightweight
# heuristics to recognize function headers from other text in the
# file. It could go horribly wrong if macros are used to
# include/exclude functions, or if macros are used in the function
# headers themselves.

# Here's how it looks for functions headers to be output as 'extern'
# declarations.
# - Should not be preceded by line beginning with 'static'
# - Should not be preceded by 'static' on the same line
# - Begins in column 0 (no leading spaces)
# - Begins with a type (C identifier)
# - Then, 1 or more whitespace
# - Then, optional '*' (for pointer return-types)
# - Then, 0 or more whitespace
# - Then, the function name (C identifier)
# - Then, 1 or more whitespace
# - Then, '(', the start of the argument list
# - Then, the argument list and closing ')'  on or more lines
# - Then, '{' in column 0 (the function body, no leading whitespace)

# ================================================================

import sys
import fileinput

# ================================================================

def main (argv = None):
    if (len (argv) != 2) or (argv [1] == '-h') or (argv [1] == '--help'):
        print ("Usage:  {0}  <foo.c>        generate function prototypes into foo_protos.h".format (argv [0]))
        return 0

    c_filename = (argv [1].rstrip())
    if (not c_filename.endswith (".c")):
        sys.stderr.write ("ERROR: input filename ({0}) does not end with .c".format (c_filename))
        return 1

    h_filename = c_filename [:-2] + ".h"

    protos_filename = c_filename [:-2] + "_protos.h"
    fout = open (protos_filename, "w")

    state = {'c_filename':      c_filename,
             'h_filename':      h_filename,
             'protos_filename': protos_filename,
             'fout':            fout,
             'line_num':        0,
             'fsm_state':       0,
             'function_header': [],
             'lines_out':       []}

    process_pre (state)

    for line in fileinput.input (c_filename):
        process_line (state, line)

    process_post (state)

    return 0

# ================================================================
# Actions before processing

def process_pre (state):
    # sys.stdout.write ("Input file:  {0}\n".format (state ['c_filename']))
    # sys.stdout.write ("Output file: {0}\n".format (state ['protos_filename']))

    state ['lines_out'].extend (
        ["// This file is generated automatically from the file '{:s}'\n".format (state ['c_filename']),
         "//     and contains 'extern' function prototype declarations for its functions.\n",
         "// In any C source file using these functions, add:\n",
         '//     #include "{:s}"\n'.format (state ['protos_filename']),
         "// You may also want to create/maintain a file '{:s}'\n".format (state ['h_filename']),
         "//     containing #defines and type declarations.\n"
         "// ****************************************************************\n",
         "\n",
         "#pragma once\n"
        ])

# ================================================================
# Actions after Processing

def process_post (state):
    for line in state ['lines_out']:
        state ['fout'].write (line)

    sys.stdout.write ("    INFO: {0} ({1} lines) generated from {2} ({3} lines)\n"
                      .format (state ['protos_filename'],
                               len (state ['lines_out']),
                               state ['c_filename'],
                               state ['line_num']))

# ================================================================
# Processing

# State:
#     0 = neutral
#     1 = seen line beginning with 'static': skip next line
#     2 = seen function header: output lines until line starting with '{'

def process_line (state, line):
    state ['line_num'] = state ['line_num'] + 1

    if (state ['fsm_state'] == 2):
        if (line.startswith ("{")):
            output_function_header (state)
            state ['fsm_state'] = 0
        else:
            state ['function_header'].append (line)

    elif (state ['fsm_state'] == 1):
        state ['fsm_state'] = 0
        pass

    else: # (state ['fsm_state'] == 0)
        if line.startswith ("static"):
            state ['fsm_state'] = 1

        elif is_function_header (state, line):
            state ['function_header'].append (line)
            state ['fsm_state'] = 2

        else:
            pass

# ----------------

def output_function_header (state):
    state ['lines_out'].append ("\n")
    state ['lines_out'].append ("extern\n")
    for line in state ['function_header'] [:-1]:
         state ['lines_out'].append (line)

    last = state ['function_header'] [-1]
    state ['lines_out'].append ("{0};\n".format (last.rstrip()))

    state ['function_header'] = []

# ================================================================

def is_function_header (state, line):
    if (not line [:1].isalpha()):
        return False

    debug_print ("{0}:{1}".format (state ['line_num'], line))

    # Find the function return-type
    (s1, s2, s3) = line.partition (" ")
    if (s2 == "") or (not is_C_identifier (s1)):
        debug_print ("Could not find whitespace after return-type\n")
        return False

    # Skip '*' if any
    s3 = s3.lstrip()
    if s3.startswith ("*"):
        s3 = s3 [1:]

    # Find the space or '(' just past the function name
    j = s3.find (" ")
    if (j == -1):
        j = s3.find ("(")
        if (j == -1):
            debug_print ("Could not find whitespace or '(' after function name\n")
            return False

    # Check if the function name is an identifier
    function_name = s3 [0:j]
    if not is_C_identifier (function_name):
        debug_print ("Function name is not an identifier\n")
        return False

    # Check that this is followed by a '('
    s4 = (s3 [j:]).lstrip()
    if (not s4.startswith ("(")):
        debug_print ("Function name is not followed by '('\n")
        return False

    return True
    
# ================================================================

def is_C_identifier (s):
    for c in s:
        if not (c.isalpha ()
                or c.isdigit ()
                or (c == "_")
                or (c == "$")):
            return False
    return True

# ================================================================

def debug_print (s):
    debug = False

    if debug:
        sys.stdout.write (s)

# ================================================================
# For non-interactive invocations, call main() and use its return value
# as the exit code.
if __name__ == '__main__':
  sys.exit (main (sys.argv))
