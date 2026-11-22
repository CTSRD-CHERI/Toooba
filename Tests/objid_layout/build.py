#!/usr/bin/env python3
"""Build bare-metal purecap ObjID layout tests using public CHERI LLVM custom encodings."""
import argparse,json,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--sdk',type=Path,default=Path('/local/scratch/jdw57/cheri/output/sdk'));p.add_argument('--output',type=Path,required=True);a=p.parse_args()
r=Path(__file__).resolve().parent;a.output.mkdir(parents=True,exist_ok=True)
cases=[]
for mode in range(8):
 locs=[1,33,5,0,32] if mode in (0,7) else [0,3,4,7,8,11,12,15,32,63] if mode in (1,2) else [0,32]
 for loc in locs:
  for store in (False,True):
   for stale in ([False,True] if loc==locs[0] else [False]):
    cases.append(dict(mode=mode,loc=loc,store=store,stale_first=stale))
for c in cases: c['new_id'] = 2
for mode in range(8):
 for store in (False,True):
  for new_id in (3,5,9,17,33,65,129):
   cases.append(dict(mode=mode,loc=1 if mode in (0,7) else 0,store=store,stale_first=False,new_id=new_id))
for mode in (0,1,3,6,7):
 for store in (False,True):
  for stale in (False,True):
   cases.append(dict(mode=mode,loc=1 if mode in (0,7) else 0,store=store,stale_first=stale,new_id=2,amo=True))
for mode in (0,7):
 for store in (False,True):
  cases.append(dict(mode=mode,loc=1,store=store,stale_first=False,new_id=2,data_offset=64))
for c in cases:
 name=f"mode{c['mode']}-loc{c['loc']}-{'store' if c['store'] else 'load'}"+('-stale-first' if c['stale_first'] else '')
 name += '' if c['new_id']==2 else '-id'+str(c['new_id'])
 name += '-amo' if c.get('amo') else ''
 name += '-offset'+str(c['data_offset']) if c.get('data_offset') else ''
 binary=a.output/(name+'.bin');c['binary']=binary.name
 sysroot=a.sdk/'baremetal/baremetal-riscv64-purecap/riscv64-unknown-elf'
 cmd=[str(a.sdk/'bin/clang'),'--target=riscv64-unknown-elf','-march=rv64imafdcxcheri','-mabi=l64pc128d','-mcmodel=medium','-mno-relax','--sysroot='+str(sysroot),'-O2','-g','-ffreestanding','-fno-builtin','-nostdlib','-fuse-ld=lld','-Wl,-T,'+str(r/'test.ld'),'-I'+str(r),'-DMODE='+str(c['mode']),'-DLOC='+str(c['loc']),'-DNEW_ID='+str(c['new_id'])]
 if c.get('data_offset'):cmd+=['-DDATA_OFFSET='+str(c['data_offset'])]
 if c.get('amo'):cmd+=['-DUPDATE_AMO']
 if c['store']:cmd+=['-DSTORE']
 if c['stale_first']:cmd+=['-DSTALE_FIRST']
 subprocess.run(cmd+[str(r/'crt.S'),str(r/'runtime.c'),str(r/'layout.c'),'-o',str(binary)],check=True)
(a.output/'cases.json').write_text(json.dumps(cases,indent=2)+'\n');print(f'Built {len(cases)} tests')
