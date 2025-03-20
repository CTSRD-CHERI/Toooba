#!/usr/bin/python3

# Copyright (c) 2018-2019 Bluespec, Inc.
# See LICENSE for license details

usage_line = (
    "  Usage:\n"
    "    $ <this_prog>    <simulation_executable>  <repo_dir>  <logs_dir> <opt verbosity>  <opt parallelism> <opt timeout_secs>\n"
    "\n"
    "  Runs the RISC-V <simulation_executable>\n"
    "  on ISA tests: ELF files taken from <repo-dir>/isa and its sub-directories.\n"
    "\n"
    "  For each ELF file FOO, saves simulation output in <logs_dir>/FOO.log. \n"
    "\n"
    "  If <opt verbosity> is given, it must be one of the following:\n"
    "      v1:    Print instruction trace during simulation\n"
    "      v2:    Print pipeline stage state during simulation\n"
    "\n"
    "  If <opt parallelism> is given, it must be an integer\n"
    "      Specifies the number of parallel processes used\n"
    "        (creates temporary separate working directories worker_0, worker_1, ...)\n"
    "      By default uses the number of CPUs listed in /proc/cpuinfo - 4.\n"
    "      In any case, limits it to 8.\n"
    "\n"
    " If <opt timeout_secs> is given, it must be an integer and must follow an explicit <opt parallelism>\n"
    "      Specifies the number of seconds to wait for each command run.\n"
    "      Defaults to 60s\n."
    "\n"
    "  Example:\n"
    "      $ <this_prog>  .exe_HW_sim  ~somebody/GitHub/Toooba ./Logs v1 4\n"
    "    will run the verilator simulation executable on the following RISC-V ISA tests:\n"
    "            ~somebody/GitHub/Tests/benchmarks/*.bin\n"
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

import multiprocessing

# ================================================================
# DEBUGGING ONLY: This exclude list allows skipping some specific test

exclude_list = []

n_workers_max = 8

timeout = 6000

def print_hello ():
    print ("hello")
# ================================================================

def main (argv = None):
    print ("Use flag --help  or --h for a help message")
    if ((len (argv) <= 1) or
        (argv [1] == '-h') or (argv [1] == '--help') or
        (len (argv) < 4)):

        sys.stdout.write (usage_line)
        sys.stdout.write ("\n")
        return 0

    # Simulation executable
    if not (os.path.exists (argv [1])):
        sys.stderr.write ("ERROR: The given simulation path does not seem to exist?\n")
        sys.stderr.write ("    Simulation path: " + sim_path + "\n")
        sys.exit (1)
    args_dict = {'sim_path': os.path.abspath (os.path.normpath (argv [1]))}

    # Repo in which to find ELFs and elf_to_hex executable
    if (not os.path.exists (argv [2])):
        sys.stderr.write ("ERROR: repo directory ({0}) does not exist?\n".format (argv [2]))
        sys.stdout.write ("\n")
        sys.stdout.write (usage_line)
        sys.stdout.write ("\n")
        return 1
    repo = os.path.abspath (os.path.normpath (argv [2]))

    elfs_path = os.path.join (repo, "Tests", "benchmarks")
    if (not os.path.exists (elfs_path)):
        sys.stderr.write ("ERROR: BINs directory ({0}) does not exist?\n".format (elfs_path))
        sys.stdout.write ("\n")
        sys.stdout.write (usage_line)
        sys.stdout.write ("\n")
        return 1
    args_dict ['elfs_path'] = elfs_path

    # Logs directory
    logs_path = os.path.abspath (os.path.normpath (argv [3]))
    if not (os.path.exists (logs_path) and os.path.isdir (logs_path)):
        print ("Creating dir: " + logs_path)
        os.mkdir (logs_path)
    args_dict ['logs_path'] = logs_path

    # Optional verbosity
    verbosity = 0
    j = 4
    if len (argv) >= 5:
        if argv [4] == "v1":
            verbosity = 1
            j = 5
        elif argv [4] == "v2":
            verbosity = 2
            j = 5
    args_dict ['verbosity'] = verbosity

    # Optional parallelism; limit it to 8
    if len (argv [j:]) != 0 and isdecimal (argv [j]):
        n_workers = int (argv [j])
        j = 6
    else:
        n_workers = multiprocessing.cpu_count () - 4
    n_workers = max(min (n_workers_max, n_workers), 1)
    sys.stdout.write ("Using {0} worker processes\n".format (n_workers))

    global timeout
    if len(argv[j:]) != 0 and isdecimal (argv[j]):
        timeout = int(argv[j])
        j = 7
    sys.stdout.write (f"Using {timeout}s timeout\n")

    # End of command-line arg processing
    # ================================================================

    # elf_to_hex executable
    elf_to_hex_exe = os.path.join (repo, "Tests", "elf_to_hex", "elf_to_hex")
    if (not os.path.exists (elf_to_hex_exe)):
        sys.stderr.write ("ERROR: elf_to_hex executable does not exist?\n")
        sys.stderr.write ("    at {0}\n".format (elf_to_hex_exe))
        sys.stdout.write ("\n")
        sys.stdout.write (usage_line)
        sys.stdout.write ("\n")
        return 1
    args_dict ['elf_to_hex_exe'] = elf_to_hex_exe

    sys.stdout.write ("Parameters:\n")
    for key in iter (args_dict):
        sys.stdout.write ("    {0:<16}: {1}\n".format (key, args_dict [key]))

    def fn_filter_regular_file (level, filename):
        (dirname, basename) = os.path.split (filename)

        # TEMPORARY FILTER WHILE DEBUGGING:
        if basename in exclude_list:
            sys.stdout.write ("WARNING: TEMPORARY FILTER IN EFFECT; REMOVE AFTER DEBUGGING\n")
            sys.stdout.write ("    This test is in exclude_list: {0}\n".format (basename))
            return False

        # Ignore filename if it is not a "*.bin"
        if basename.find (".bin") != -1:
            return True
        
        return False

    def fn_filter_dir (level, filename):
        return True

    # Traverse the elfs_path and collect filenames of relevant isa tests
    filenames = traverse (fn_filter_dir, fn_filter_regular_file, 0, elfs_path)
    n_tests   = len (filenames)
    sys.stdout.write ("{0} relevant benchmarks found under {1}\n".format (n_tests, elfs_path))
    if n_tests == 0:
        return 0
    args_dict ['filenames'] = filenames
    args_dict ['n_tests']   = n_tests

    # Create a shared counter to index into the list of filenames
    index = multiprocessing.Value ('L', 0)    # Unsigned long (4 bytes)
    args_dict ['index'] = index

    # Create a shared array for each worker's (n_executed, n_passed) results
    results = multiprocessing.Array ('L', [ 0 for j in range (2 * n_workers) ])
    args_dict ['results'] = results

    # Create a TAP file to output individual test results in TAP format
    tap_out = open("../isa_test_report.tap", "w")
    tap_out.write("1.." + str(n_tests) + "\n")
    tap_out.close()

    # Create n workers
    sys.stdout.write ("Creating {0} workers (sub-processes)\n".format (n_workers))
    workers        = [multiprocessing.Process (target = do_worker,
                                               #args = (w, args_dict, tap_out))
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
    sys.stdout.write ("Total benchmarks: {0} tests\n".format (n_tests))
    sys.stdout.write ("Executed:    {0} tests\n".format (num_executed))
    sys.stdout.write ("PASS:        {0} tests\n".format (num_passed))
    sys.stdout.write ("FAIL:        {0} tests\n".format (num_executed - num_passed))
    return 0

# ================================================================
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
# For each ELF file, execute it in the RISC-V simulator

def do_worker (worker_num, args_dict):
    tmpdir = "./worker_" + "{0}".format (worker_num)
    if not os.path.exists (tmpdir):
        os.mkdir (tmpdir)
    elif not os.path.isdir (tmpdir):
        sys.stdout.write ("ERROR: Worker {0}: {1} exists but is not a dir".format (worker_num, tmpdir))
        return

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

        (message, passed) = do_benchmark (args_dict, filename)
        num_executed = num_executed + 1

        if passed:
            num_passed = num_passed + 1
            pass_fail = "PASS"
        else:
            pass_fail = "FAIL"

        message = message + ("Worker {0}: Test: {1} {2} [So far: total {3}, executed {4}, PASS {5}, FAIL {6}]\n"
                             .format (worker_num,
                                      os.path.basename (filename),
                                      pass_fail,
                                      n_tests,
                                      num_executed,
                                      num_passed,
                                      num_executed - num_passed))
        sys.stdout.write (message)
        # Create a TAP file to output individual test result in TAP format
        tap_out = open("../benchmark_report.tap", "a+")
        tap_out.write(("ok" if passed else "not ok") + " " + str(my_index + 1) + " - " + filenames[my_index] + "\n")
        tap_out.close()

# ================================================================
# For each ELF file, execute it in the RISC-V simulator

def do_benchmark (args_dict, full_filename):
    message = ""

    (dirname, basename) = os.path.split (full_filename)

    # Construct the commands for sub-process execution
    command1 = [args_dict ['elf_to_hex_exe'], full_filename, "Mem.hex"]

    command2 = [args_dict ['sim_path'],  "+tohost"]
    if (args_dict ['verbosity'] == 1): command2.append ("+v1")
    elif (args_dict ['verbosity'] == 2): command2.append ("+v2")

    message = message + "    Exec:"
    for x in command1:
        message = message + (" {0}".format (x))
    message = message + "\n"

    message = message + ("    Exec:")
    for x in command2:
        message = message + (" {0}".format (x))
    message = message + ("\n")
    
    # Save stdouts in log file
    log_filename = os.path.join (args_dict ['logs_path'], basename + ".log")
    message = message + ("    Writing log: {0}\n".format (log_filename))

    with open (log_filename, 'w') as fd:
        completed_process1 = run_command (command1, fd)
        
        if completed_process1 is not None and completed_process1.returncode == 0:
            completed_process2 = run_command (command2, fd)
            passed = completed_process2 is not None and \
                completed_process2.returncode == 0 and \
                not completed_process2.stdout.endswith ("FAIL 1")
        else:
            passed = False

    # If Tandem Verification trace file was created, save it as well
    if os.path.exists ("./trace_out.dat"):
        trace_filename = os.path.join (args_dict ['logs_path'], basename + ".trace_data")
        os.rename ("./trace_out.dat", trace_filename)
        message = message + ("    Trace output saved in: {0}\n".format (trace_filename))

    return (message, passed)

# ================================================================
# This is a wrapper around 'subprocess.run' because of an annoying
# incompatible change in moving from Python 3.5 to 3.6

def run_command (command, log_fd):
    command_str = " ".join(command)
    log_fd.write (f"Running: {command_str}\n")
    try:
        python_minor_version = sys.version_info [1]
        if python_minor_version < 6:
            # Python 3.5 and earlier
            result = subprocess.run (args = command,
                                    bufsize = 0,
                                    stdout = subprocess.PIPE,
                                    stderr = subprocess.STDOUT,
                                    universal_newlines = True,
                                    timeout=timeout)
        else:
            # Python 3.6 and later
            result = subprocess.run (args = command,
                                    bufsize = 0,
                                    stdout = subprocess.PIPE,
                                    stderr = subprocess.STDOUT,
                                    encoding='utf-8',
                                    timeout=timeout)
        log_fd.write(f"Finished with exit code {result.returncode}\n")
        log_fd.write("Stdout:\n")
        log_fd.write (result.stdout)
        return result
    except subprocess.TimeoutExpired:
        sys.stderr.write(f"TIMEOUT: {command_str} !\n")
        log_fd.write("TIMEOUT!\n")
        return None

# ================================================================
# For non-interactive invocations, call main() and use its return value
# as the exit code.
if __name__ == '__main__':
  sys.exit (main (sys.argv))
