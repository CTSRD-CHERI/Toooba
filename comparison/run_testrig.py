#!/usr/bin/env python3
"""Run integer or CHERI differential smoke tests against the local Sail model."""
from pathlib import Path
import argparse
import os
import subprocess
import sys

p = argparse.ArgumentParser()
p.add_argument('suite', choices=['riscv', 'cheri'])
p.add_argument('--tests', type=int, default=100)
p.add_argument('--length', type=int, default=64)
p.add_argument('--timeout', type=int, default=600)
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
if a.suite == 'cheri':
    cmd += ['--test-include-regex', '^(cap|cloadtags)']
print(' '.join(cmd), flush=True)
# Simulator runtime files must be found relative to the build directory.
raise SystemExit(subprocess.call(cmd, cwd=simdir))
