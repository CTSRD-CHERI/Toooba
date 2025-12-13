#!/usr/bin/python3

# Copyright (c) 2018-2019 Bluespec, Inc.
# See LICENSE for license details

from os import PathLike
import multiprocessing
from argparse import ArgumentParser, RawDescriptionHelpFormatter

parser = ArgumentParser(\
    prog = "Run_benchmarks.py", \
    description = "Runs a RISC-V simulation executable on Benchmark tests - ELF files taken from <repo>/Tests/benchmarks and its sub-directories.", \
    epilog = """For Example: `$ <this_prog>  .exe_HW_sim  ~somebody/GitHub/Toooba ./Logs -v -p 4` will run the verilator simulation executable on the following RISC-V ISA tests: `~somebody/GitHub/Toooba/Tests/benchmarks/*.bin` and will leave a transcript of each test's simulation output in files like `./Logs/rv32ui-p-add.log`. Each log will contain an instruction trace (because of the '-v' arg). It will use 4 processes in parallel to run the regressions.(creating temporary working directories worker_0, ..., worker_3). \n\nFor more details, see $(REPO)/Tests/Run_benchmarks.py""", \
    add_help = True, \
    formatter_class=RawDescriptionHelpFormatter
)

parser.add_argument("sim_path", type=str, help="Run this simulation executable on the Benchmark tests - Required")
parser.add_argument("repo", type=str, help="Root Directory of the Toooba Repository - used to locate the Benchmarks - Required")
parser.add_argument("logs_path", type=str, help="For each ELF file FOO, saves simulation output in `<logs_path>/FOO.log` - Required")
parser.add_argument("csvFile", type=str, help="Write CSV of performance results to this file")
parser.add_argument("--verbose", "-v", action="count", default=0, help="Print additional information during simulation: `-v` = instruction trace; `-vv` = pipeline stage state")
parser.add_argument("--parallelism", "-p", type=int, default=multiprocessing.cpu_count ()-4 ,help="Specifies the number of parallel processes used (creates temporary separate working directories worker_0, worker_1, ...). By default uses the number of CPUs listed in `/proc/cpuinfo - 4`.")
parser.add_argument("--timeout_secs", type=int, default=6000, help="Specifies the number of seconds to wait for each command run. Defaults to 6000s")
# Log files currently take up ~25GB per run, use this flag to minimise logfile storage
parser.add_argument("--no_write_logs", action="store_false", help="Don't write success logfiles to reduce storage overhead of run - requires Python >= 3.6")

args = parser.parse_args()

import sys
import os
import stat
import subprocess
import re

# ================================================================
# DEBUGGING ONLY: This exclude list allows skipping some specific test

exclude_list = []

def error(line:str):
    sys.stderr.write(line)
    parser.print_usage(file=sys.stderr)
    sys.exit(1)

# ================================================================

timeout = args.timeout_secs

def main (argv = None):
    args_dict = {}
    # Simulation executable
    sim_path = args.sim_path
    if not (os.path.exists (sim_path)):
        error(f"ERROR: The given simulation path does not seem to exist?\n    Simulation path: {sim_path}\n")
    args_dict['sim_path'] = os.path.abspath (os.path.normpath (sim_path))

    # Repo in which to find ELFs and elf_to_hex executable
    repo = os.path.abspath (os.path.normpath (args.repo))
    if (not os.path.exists (repo)):
        error(f"ERROR: repo directory ({repo}) does not exist?\n")
    
    elfs_path = os.path.join (repo, "Tests", "benchmarks")
    if (not os.path.exists (elfs_path)):
        error(f"ERROR: BINs directory ({elfs_path}) does not exist?\n")
    args_dict ['elfs_path'] = elfs_path

    # Logs directory
    logs_path = os.path.abspath (os.path.normpath (args.logs_path))
    if not (os.path.exists (logs_path) and os.path.isdir (logs_path)):
        print ("Creating dir: " + logs_path)
        os.mkdir (logs_path)
    args_dict ['logs_path'] = logs_path


    args_dict ['verbosity'] = args.verbose

    # Optional parallelism
    n_workers = min(max(args.parallelism, 1), multiprocessing.cpu_count())
    sys.stdout.write ("Using {0} worker processes\n".format (n_workers))

    global timeout
    sys.stdout.write (f"Using {timeout}s timeout\n")

    csvFile = os.path.abspath(os.path.normpath(args.csvFile))
    if not (os.path.exists(csvFile) and os.path.isfile(csvFile)):
        print (f"Creating performance output CSV {csvFile}")
        (dir, f) = os.path.split(csvFile)
        os.makedirs(dir, exist_ok=True)
        with open(csvFile, "x") as f: # `touch csvFile`
            pass
    

    # End of command-line arg processing
    # ================================================================

    # elf_to_hex executable
    elf_to_hex_exe = os.path.join (repo, "Tests", "elf_to_hex", "elf_to_hex")
    if (not os.path.exists (elf_to_hex_exe)):
        error(f"ERROR: elf_to_hex executable does not exist?\n    at {elf_to_hex_exe}\n")
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

    n_workers = min(n_tests, n_workers)

    # Create a shared counter to index into the list of filenames
    index = multiprocessing.Value ('L', 0)    # Unsigned long (4 bytes)
    args_dict ['index'] = index

    # Create a shared array for each worker's (n_executed, n_passed) results
    results = multiprocessing.Array ('L', [ 0 for j in range (2 * n_workers) ])
    man = multiprocessing.Manager()
    csvQ = man.Queue()
    args_dict ['results'] = results

    args_dict['write_logs'] = args.no_write_logs
    args_dict['csvQ'] = csvQ

    # Create a TAP file to output individual test results in TAP format
    tap_out = open("./benchmark_report.tap", "w")
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

    # Write the Performance CSV - replaces `report_log.sh`
    csvLines = []
    while not(csvQ.empty()):
        csvLines.append(csvQ.get())
    csvLines.sort()
    with open(csvFile, "w") as f:
        f.write("Log, Cycles, Instructions\n")
        f.write("".join(csvLines))

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
    csvQ = args_dict ['csvQ']

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

        (message, passed, csvline) = do_benchmark (args_dict, filename)
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
        csvQ.put(csvline)
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

    csvline = ""

    with open (log_filename, 'w') as fd:
        completed_process1 = run_command (command1, fd, args_dict["write_logs"])
        
        if completed_process1 is not None and completed_process1.returncode == 0:
            completed_process2 = run_command (command2, fd, args_dict["write_logs"])
            passed = completed_process2 is not None and \
                completed_process2.returncode == 0 and \
                not completed_process2.stdout.endswith ("FAIL 1")
        else:
            passed = False

        if passed:
            out = list(completed_process2.stdout.split("\n")[-1000:].__reversed__()) # Truncate and `tac`
            instretLine = list(filter((lambda s: "instret" in s), out))[0] # `grep -m 1`
            csvline = f"{basename}.log, {re.sub(r"^instret:(\d+).*? (\d+)$", r"\2, \1", instretLine)}\n" # `sed ...`

    # If Tandem Verification trace file was created, save it as well
    if os.path.exists ("./trace_out.dat"):
        trace_filename = os.path.join (args_dict ['logs_path'], basename + ".trace_data")
        os.rename ("./trace_out.dat", trace_filename)
        message = message + ("    Trace output saved in: {0}\n".format (trace_filename))

    return (message, passed, csvline)

# ================================================================
# This is a wrapper around 'subprocess.run' because of an annoying
# incompatible change in moving from Python 3.5 to 3.6

def run_command (command, log_fd, write_log=True):
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
        if write_log or result.returncode != 0:
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
