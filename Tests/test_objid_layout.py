#!/usr/bin/env python3
"""Run compiled ObjID layout ISA tests, keeping every result and trace.

Use objid_layout/build.py to build inputs. A simulator compiled with BSIM
emits OBJID_LAYOUT markers when +trace_objid_layout is supplied. A nonzero
architectural exit is a test failure even when the simulator exits normally.
"""
import argparse,concurrent.futures,gzip,hashlib,json,re,subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--sim',type=Path,required=True);p.add_argument('--binaries',type=Path,required=True)
p.add_argument('--output',type=Path,required=True);p.add_argument('--converter',type=Path,default=Path('/tmp/toooba-elf-to-hex'))
p.add_argument('--jobs',type=int,default=4);p.add_argument('--timeout',type=int,default=120)
a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
def run(binary):
 work=(a.output/binary.stem).resolve();work.mkdir(parents=True,exist_ok=True)
 row={'binary':binary.name,'sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),
      'markers':dict(hit=0,miss=0,fill=0)}
 with (work/'conversion.log').open('wb') as log:
  subprocess.run([str(a.converter.resolve()),str(binary.resolve()),'Mem.hex'],cwd=work,stdout=log,stderr=subprocess.STDOUT,check=True)
 logpath=work/'simulation.log'
 try:
  with logpath.open('wb') as log:
   cp=subprocess.run([str(a.sim.resolve()),'+tohost','+trace_objid_layout'],cwd=work,stdout=log,stderr=subprocess.STDOUT,timeout=a.timeout)
  text=logpath.read_text(errors='replace');row['returncode']=cp.returncode
  result=re.findall(r'(\d+): mmioPlatform.rl_tohost: 0x([0-9a-fA-F]+)',text)
  if result:row.update(cycles=int(result[-1][0]),exit_value=int(result[-1][1],16)>>1)
  row['markers']={name:text.count('OBJID_LAYOUT '+name) for name in ['hit','miss','fill']}
  row['passed']=cp.returncode==0 and row.get('exit_value')==0 and not re.search(r'assertion.*failed',text,re.I)
 except subprocess.TimeoutExpired:
  row.update(passed=False,error='timeout')
 with logpath.open('rb') as raw,gzip.open(str(logpath)+'.gz','wb') as zipped:
  import shutil;shutil.copyfileobj(raw,zipped)
 logpath.unlink()
 (work/'result.json').write_text(json.dumps(row,indent=2)+'\n');print(json.dumps(row),flush=True)
 return row
with concurrent.futures.ThreadPoolExecutor(max_workers=a.jobs) as pool:
 rows=list(pool.map(run,sorted(a.binaries.glob('*.bin'))))
(a.output/'results.json').write_text(json.dumps(rows,indent=2)+'\n')
raise SystemExit(0 if rows and all(r['passed'] for r in rows) else 1)
