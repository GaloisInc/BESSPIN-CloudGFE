#!/usr/bin/python3

# Copyright (c) 2018-2020 Bluespec, Inc.
# See LICENSE for license details

usage_line = (
    "  Usage:\n"
    "    $ <this_prog>    ... args ...\n"
    "  Runs the RISC-V <simulation_executable>\n"
    "  on all ISA tests (ELF files) relevant for the specified ISA <arch>.\n"
    "\n"
    "  Args:\n"
    "  1 <simulation_executable>  The simulation executable (Bluesim, Verilator sim, ...)\n"
    "  2 <arch>                   Architecture string for simulator, such as RV64GC_MSU\n"
    "  3 <ISA_tests_dir>          Dir containing all the ISA test ELF files\n"
    "  4 <logs_dir>               Dir into which to place logs\n"
    "  5 <elf_to_memhex32>        Path to program converting an ELF file to a generic memhex32 file\n"
    "  6 <memhex32_to_512>        Path to program converting a generic memhex32 file to\n"
    "                                 specific memhex file expected by this simulation executable\n"
    "  7 <opt verbosity>          v1:    Print instruction trace during simulation\n"
    "                             v2:    Print pipeline stage state during simulation\n"
    "  8 <opt parallelism>        Integer indicating how many parallel processes to use.\n"
    "                                 (creates temporary separate working directories worker_0, worker_1, ...)\n"
    "                                 By default uses 1/2 the CPUs listed in /proc/cpuinfo.\n"
    "                                 In any case, limits it to 8.\n"
    "\n"
    "  For each ELF file FOO, saves simulation output in <logs_dir>/FOO.log.\n"
    "\n"
    "  Example:\n"
    "      $ <this_prog>  .exe_HW_sim  ~somebody/GitHub/Flute/Tests  ./Logs  RV32IMU  v1 4\n"
    "    will run the simulation executable on the following RISC-V ISA tests:\n"
    "            ~somebody/GitHub/Tests/isa/rv32ui-p*\n"
    "            ~somebody/GitHub/Tests/isa/rv32mi-p*\n"
    "            ~somebody/GitHub/Tests/isa/rv32um-p*\n"
    "    which are relevant for architecture RV32IMU\n"
    "    and will leave a transcript of each test's simulation output in files like\n"
    "            ./Logs/rv32ui-p-add.log\n"
    "    Each log will contain an instruction trace (because of the 'v1' arg).\n"
    "    It will use 4 processes in parallel to run the regressions.\n"
    "        (creating temporary working directories worker_0, ..., worker_4)\n"
)

import sys
import os
import stat
import subprocess
import shutil

import multiprocessing

# ================================================================
# DEBUGGING ONLY: This exclude list allows skipping some specific test
# (e.g., because it hangs)

exclude_list = []

n_workers_max = 8

# ================================================================

def main (argv = None):
    print ("Use flag -h, --h, or --help for a help message")
    if ((len (argv) <= 1) or
        ('-h' in argv) or
        ('--h' in argv) or
        ('--help' in argv) or
        (len (argv) < 7)):

        sys.stdout.write (usage_line)
        sys.stdout.write ("\n")
        return 0

    # ----------------
    # Simulation executable
    arg = argv [1]
    if not (os.path.exists (arg)):
        sys.stderr.write ("ERROR: The given simulation path does not seem to exist?\n")
        sys.stderr.write ("    Simulation path: " + sim_path + "\n")
        sys.exit (1)
    args_dict = {'sim_path': os.path.abspath (os.path.normpath (arg))}

    # ----------------
    # Architecture string and implied ISA test families
    arg = argv [2]
    arch_string = extract_arch_string (arg)
    if (arch_string == None):
        sys.stderr.write ("ERROR: no architecture specified?\n".format (arg))
        sys.stdout.write ("\n")
        sys.stdout.write (usage_line)
        sys.stdout.write ("\n")
        return 1
    args_dict ['arch_string'] = arch_string

    # ----------------
    # Path to dir containing ISA ELFs
    arg = argv [3]
    if (not os.path.exists (argv [3])):
        sys.stderr.write ("ERROR: ISA-tests directory ({0}) does not exist?\n".format (arg))
        sys.stdout.write ("\n")
        sys.stdout.write (usage_line)
        sys.stdout.write ("\n")
        return 1
    args_dict ['elfs_path'] = os.path.abspath (os.path.normpath (arg))

    # ----------------
    # Logs directory
    arg = argv [4]
    logs_path = os.path.abspath (os.path.normpath (arg))
    if not (os.path.exists (logs_path) and os.path.isdir (logs_path)):
        print ("Creating dir: " + logs_path)
        os.mkdir (logs_path)
    args_dict ['logs_path'] = logs_path

    # ----------------
    # Path to Elf_to_Memhex32 program
    arg = argv [5]
    if (not os.path.exists (arg)):
        sys.stderr.write ("ERROR: <elf_to_memhex32> program ({0}) does not exist?\n".format (arg))
        sys.stdout.write ("\n")
        sys.stdout.write (usage_line)
        sys.stdout.write ("\n")
        return 1
    args_dict ['elf_to_memhex32_exe'] = os.path.abspath (os.path.normpath (arg))

    # ----------------
    # Path to Memhex32_to_Memhex program
    arg = argv [6]
    if (not os.path.exists (arg)):
        sys.stderr.write ("ERROR: <memhex32_to_memhex> program ({0}) does not exist?\n".format (arg))
        sys.stdout.write ("\n")
        sys.stdout.write (usage_line)
        sys.stdout.write ("\n")
        return 1
    args_dict ['memhex32_to_memhex_exe'] = os.path.abspath (os.path.normpath (arg))

    # ----------------
    # Optional verbosity
    argv      = argv [7:]
    verbosity = 0
    if len (argv) >= 1:
        if argv [0] == "v1":
            verbosity = 1
            argv = argv [1:]
        elif argv [0] == "v2":
            verbosity = 2
            argv = argv [1:]
    args_dict ['verbosity'] = verbosity

    # ----------------
    # Optional parallelism; limited to 8
    if len (argv) != 0 and argv [0].isdecimal():
        n_workers = int (argv [0])
    else:
        n_workers = multiprocessing.cpu_count () // 2
    n_workers = min (n_workers_max, n_workers)
    sys.stdout.write ("Using {0} worker processes\n".format (n_workers))

    # End of command-line arg processing
    # ================================================================
    # Collect relevant test families

    test_families = select_test_families (args_dict ['arch_string'])
    args_dict ['test_families'] = test_families

    # ================================================================
    # Collect list of all ELF file paths in relevant test families

    def fn_filter_regular_file (level, filename):
        (dirname, basename) = os.path.split (filename)
        # Ignore filename if has any extension (heuristic that it's not an ELF file)
        if "." in basename: return False

        # TEMPORARY FILTER WHILE DEBUGGING:
        if basename in exclude_list:
            sys.stdout.write ("WARNING: TEMPORARY FILTER IN EFFECT; REMOVE AFTER DEBUGGING\n")
            sys.stdout.write ("    This test is in exclude_list: {0}\n".format (basename))
            return False

        # Ignore filename if does not match test_families
        for x in args_dict ['test_families']:
            if basename.find (x) != -1: return True
        return False

    def fn_filter_dir (level, filename):
        return True

    # Traverse the elfs_path and collect filenames of relevant isa tests
    filenames = traverse (fn_filter_dir, fn_filter_regular_file, 0, args_dict ['elfs_path'])
    n_tests   = len (filenames)
    if n_tests == 0:
        sys.stdout.write ("No relevant isa tests found under {1}; quitting\n".format (args_dict ['elfs_path']))
        return 0

    args_dict ['filenames'] = filenames
    args_dict ['n_tests']   = n_tests

    # ================================================================
    # Summarize to console before beginning work

    sys.stdout.write ("Parameters:\n")
    for key in iter (args_dict):
        if (key != "filenames"):
            sys.stdout.write ("  {:s}:\n".format (key))
            sys.stdout.write ("      {0}\n".format (args_dict [key]))

    print ("Testing the following families of ISA tests")
    for tf in args_dict ['test_families']:
        print ("    " + tf)
    sys.stdout.write ("{0} relevant isa tests found\n".format (n_tests))

    # ================================================================
    # Set up the parallel executions

    # Create a shared counter to index into the list of filenames
    index = multiprocessing.Value ('L', 0)    # Unsigned long (4 bytes)
    args_dict ['index'] = index

    # Create a shared array for each worker's (n_executed, n_passed) results
    results = multiprocessing.Array ('L', [ 0 for j in range (2 * n_workers) ])
    args_dict ['results'] = results

    # Create n workers
    sys.stdout.write ("Creating {0} workers (sub-processes)\n".format (n_workers))
    workers        = [multiprocessing.Process (target = do_worker,
                                               args = (w, args_dict))
                      for w in range (n_workers)]

    # Start the workers
    for worker in workers: worker.start ()

    # Wait for all workers to finish
    for worker in workers: worker.join ()

    # Collect all results
    num_executed = 0
    num_passed   = 0
    with results.get_lock ():
        for w in range (n_workers):
            n_e = results [2 * w]
            n_p = results [2 * w + 1]
            sys.stdout.write ("Worker {0} executed {1} tests, of which {2} passed\n"
                              .format (w, n_e, n_p))
            num_executed = num_executed + n_e
            num_passed   = num_passed   + n_p

    # Write final statistics
    sys.stdout.write ("Total tests: {0} tests\n".format (n_tests))
    sys.stdout.write ("Executed:    {0} tests\n".format (num_executed))
    sys.stdout.write ("PASS:        {0} tests\n".format (num_passed))
    sys.stdout.write ("FAIL:        {0} tests\n".format (num_executed - num_passed))
    return 0

# ----------------------------------------------------------------
# Extract the architecture string (e.g., RV64AIMSU) from the string s

def extract_arch_string (s):
    s1     = s.upper()
    j_rv32 = s1.find ("RV32")
    j_rv64 = s1.find ("RV64")

    if (j_rv32 >= 0):
        j = j_rv32
    elif (j_rv64 >= 0):
        j = j_rv64
    else:
        sys.stderr.write ("ERROR: cannot find architecture string beginning with RV32 or RV64 in: \n")
        sys.stderr.write ("    '" + s + "'\n")
        sys.exit (1)

    k = j + 4
    rv = s1 [j:k]

    extns = ""
    while (k < len (s)):
        ch = s [k]
        if (ch == "G"):
            extns += "IMAFD"
        elif ("A" <= ch) and (ch <= "Z"):
            extns += s [k]
        k     = k + 1

    arch = rv + extns
    return arch

# ----------------------------------------------------------------
# Select ISA test families based on provided arch string

def select_test_families (arch):
    arch = arch.lower ()

    families = []

    if arch.find ("32") != -1:
        rv = 32
        families = ["rv32ui-p", "rv32mi-p"]
    else:
        rv = 64
        families = ["rv64ui-p", "rv64mi-p"]

    if (arch.find ("s") != -1):
        s = True
        if rv == 32:
            families.extend (["rv32ui-v", "rv32si-p"])
        else:
            families.extend (["rv64ui-v", "rv64si-p"])
    else:
        s = False

    def add_family (extension):
        if (arch.find (extension) != -1):
            if rv == 32:
                families.append ("rv32u" + extension + "-p")
                if s:
                    families.append ("rv32u" + extension + "-v")
            else:
                families.append ("rv64u" + extension + "-p")
                if s:
                    families.append ("rv64u" + extension + "-v")

    add_family ("m")
    add_family ("a")
    add_family ("f")
    add_family ("d")
    add_family ("c")

    return families

# ----------------------------------------------------------------
# Recursively traverse the dir tree below path and collect filenames
# that pass the given filter functions

def traverse (fn_filter_dir, fn_filter_regular_file, level, path):
    st = os.stat (path)
    is_dir = stat.S_ISDIR (st.st_mode)
    is_regular = stat.S_ISREG (st.st_mode)

    if is_dir and fn_filter_dir (level, path):
        files = []
        for entry in os.listdir (path):
            path1 = os.path.join (path, entry)
            files.extend (traverse (fn_filter_dir, fn_filter_regular_file, level + 1, path1))
        return files

    elif is_regular and fn_filter_regular_file (level, path):
        return [path]

    else:
        return []

# ================================================================
# Worker that repeatedly picks off an  ELF filename and executes it in the RISC-V simulator

def do_worker (worker_num, args_dict):
    tmpdir = "./worker_" + "{0}".format (worker_num)
    if not os.path.exists (tmpdir):
        os.mkdir (tmpdir)
    elif not os.path.isdir (tmpdir):
        sys.stdout.write ("ERROR: Worker {0}: {1} exists but is not a dir".format (worker_num, tmpdir))
        return

    # For iverilog simulations, copy the 'directc' files into the worker dir
    # This is necessary because it seems that iverilog assumes these are in
    # the current working dir.
    if os.path.exists ("./directc_mkTop_HW_Side.so"):
        sys.stdout.write ("Copying ./directc_mkTop_HW_Side.so to dir {0}\n".format (tmpdir))
        shutil.copy ("./directc_mkTop_HW_Side.so", tmpdir);
    if os.path.exists ("./directc_mkTop_HW_Side.sft"):
        sys.stdout.write ("Copying ./directc_mkTop_HW_Side.sft to dir {0}\n".format (tmpdir))
        shutil.copy ("./directc_mkTop_HW_Side.sft", tmpdir);

    os.chdir (tmpdir)
    sys.stdout.write ("Worker {0} using dir: {1}\n".format (worker_num, tmpdir))

    n_tests   = args_dict ['n_tests']
    filenames = args_dict ['filenames']
    index     = args_dict ['index']
    results   = args_dict ['results']

    num_executed = 0
    num_passed   = 0

    while True:
        # Get a unique index into the filenames, and get the filename
        with index.get_lock():
            my_index    = index.value
            index.value = my_index + 1
        if my_index >= n_tests:
            # All done
            with results.get_lock():
                results [2 * worker_num]     = num_executed
                results [2 * worker_num + 1] = num_passed
            return
        filename = filenames [my_index]

        (message, passed) = do_isa_test (args_dict, filename)
        num_executed = num_executed + 1

        if passed:
            num_passed = num_passed + 1
            pass_fail = "PASS"
        else:
            pass_fail = "FAIL"

        message += ("Worker {0}: Test: {1} {2} [So far: total {3}, executed {4}, PASS {5}, FAIL {6}]\n"
                    .format (worker_num,
                             os.path.basename (filename),
                             pass_fail,
                             n_tests,
                             num_executed,
                             num_passed,
                             num_executed - num_passed))
        message += "----------------------------------------------------------------\n"
        sys.stdout.write (message)

# ================================================================
# For each ELF file, execute it in the RISC-V simulator

def do_isa_test (args_dict, full_filename):
    message = ""

    (dirname, basename) = os.path.split (full_filename)

    # ----------------
    # Construct the commands for sub-process execution

    commands = []

    # Command to convert ELF to generic memhex32
    memhex32_filename = "test.memhex32"
    commands.append ([args_dict ['elf_to_memhex32_exe'], full_filename, memhex32_filename])

    # Command to convert generic memhex32 to specific memhex
    memhex_specific_filename = "test.memhex512"
    commands.append ([args_dict ['memhex32_to_memhex_exe'],
                      memhex_specific_filename,
                      "512",            # Memory width in bits
                      "0",              # Memory starting word address (not byte address)
                      "0x_400_0000",    # Memory size in words (not bytes)
                      memhex32_filename])

    # Commands to link expected memhex filenames to specific memhex
    commands.append (["ln", "-s", "-f", memhex_specific_filename, "DDR4_A.memhex512"])
    commands.append (["ln", "-s", "-f", memhex_specific_filename, "DDR4_B.memhex512"])

    # Command to perform the simulation
    commands.append ([args_dict ['sim_path']])

    # ---- These are useful for identifying a test that hangs
    # command1_string = "    TEMPORARY: Exec:"
    # for x in command1:
    #    command1_string += " {0}".format (x)
    # command1_string += "\n"
    # sys.stdout.write (command1_string)
    # sys.stdout.flush ()

    message = message + "Exec:\n"
    for command in commands:
        for x in command:
            message = message + (" {0}".format (x))
        message = message + "\n"

    message = message + ("\n")

    # Run each command as a sub-process, sequentially
    completed_processes = []
    for command in commands:
        last_completed_process = run_command (command)
        completed_processes.append (last_completed_process)
    passed = last_completed_process.stdout.find ("PASS") != -1

    # Save stdouts in log file
    log_filename = os.path.join (args_dict ['logs_path'], basename + ".log")
    message = message + ("    Writing log: {0}\n".format (log_filename))

    # Write out all their stdouts to the logfile
    fd = open (log_filename, 'w')
    for completed_process in completed_processes:
        fd.write (completed_process.stdout)
    fd.close ()

    # If Tandem Verification trace file was created, save it as well
    if os.path.exists ("./trace_out.dat"):
        trace_filename = os.path.join (args_dict ['logs_path'], basename + ".trace_data")
        os.rename ("./trace_out.dat", trace_filename)
        message = message + ("    Trace output saved in: {0}\n".format (trace_filename))

    return (message, passed)

# ================================================================
# This is a wrapper around 'subprocess.run' because of an annoying
# incompatible change in moving from Python 3.5 to 3.6

def run_command (command):
    python_minor_version = sys.version_info [1]
    if python_minor_version < 6:
        # Python 3.5 and earlier
        result = subprocess.run (args = command,
                                 bufsize = 0,
                                 stdout = subprocess.PIPE,
                                 stderr = subprocess.STDOUT,
                                 universal_newlines = True)
    else:
        # Python 3.6 and later
        result = subprocess.run (args = command,
                                 bufsize = 0,
                                 stdout = subprocess.PIPE,
                                 stderr = subprocess.STDOUT,
                                 encoding='utf-8')
    return result

# ================================================================
# For non-interactive invocations, call main() and use its return value
# as the exit code.
if __name__ == '__main__':
  sys.exit (main (sys.argv))
