#!/usr/bin/env python3
"""Run integer or CHERI differential smoke tests against the local Sail model."""
from pathlib import Path
import argparse
import os
import signal
import subprocess
import sys

p = argparse.ArgumentParser()
p.add_argument('suite', choices=['riscv', 'cheri'])
p.add_argument('--tests', type=int, default=100)
p.add_argument('--length', type=int, default=64)
p.add_argument('--timeout', type=int, default=60)
p.add_argument('--wall-timeout', type=int, default=300)
p.add_argument('--include', help='TestRIG group-name regular expression')
p.add_argument('--exclude', help='TestRIG group-name regular expression')
a = p.parse_args()
repo = Path(__file__).resolve().parents[1]
rig = next((x for x in repo.parents if (x/'utils/scripts/runTestRIG.py').is_file()), None)
if os.environ.get('TEST_RIG_ROOT'):
    rig = Path(os.environ['TEST_RIG_ROOT']).resolve()
if rig is None:
    sys.exit('Set TEST_RIG_ROOT to the TestRIG checkout')
simdir = repo/'builds/RV64ACDFIMSUxCHERI_Toooba_RVFI_DII_bluesim'
sim = simdir/'exe_HW_sim'
if not sim.exists():
    sys.exit('First run: make -C builds/RV64ACDFIMSUxCHERI_Toooba_RVFI_DII_bluesim compile simulator')
arch = 'rv64gc' if a.suite == 'riscv' else 'rv64gcxcheri'
cmd = [sys.executable, str(rig/'utils/scripts/runTestRIG.py'), '-a', 'sail', '-b', 'toooba',
       '-r', 'rv64gcxcheri', '--verification-archstring', arch,
       '--path-to-toooba', str(sim),
       '--path-to-sail-riscv-dir', str(rig/'riscv-implementations/sail-cheri-riscv/c_emulator'),
       '-n', str(a.tests), '--test-len', str(a.length), '--timeout', str(a.timeout),
       '--no-save', '--no-shrink']
if a.include or a.suite == 'cheri':
    cmd += ['--test-include-regex', a.include or '^(cap|cloadtags)']
if a.exclude:
    cmd += ['--test-exclude-regex', a.exclude]
print(' '.join(cmd), flush=True)
# Simulator runtime files must be found relative to the build directory.
proc = subprocess.Popen(cmd, cwd=simdir, stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT, text=True, start_new_session=True)
expired = False
try:
    output, _ = proc.communicate(timeout=a.wall_timeout)
except subprocess.TimeoutExpired:
    expired = True
    os.killpg(proc.pid, signal.SIGINT)
    try:
        output, _ = proc.communicate(timeout=15)
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, signal.SIGKILL)
        output, _ = proc.communicate()
print(output, end='', flush=True)
if expired:
    print('FAIL: TestRIG wall-clock limit reached', flush=True)
# Some TestRIG versions force later tests to SUCCESS after a dead simulator.
invalid = any(marker in output for marker in
              ['Forcing all future tests', '*** Failed', 'Warning: no tests selected',
               'ERROR:', 'Error: implementation', 'implementations are not alive'])
raise SystemExit(1 if expired or invalid else proc.returncode)
