#!/usr/bin/env python3
"""Simulate the production ObjID Bloom/flush rules with the real BRAM Map.

Requires bsc and the normal src_SSITH_P3 build dependencies. The harness
extracts the rules from MemExePipeline so it exercises the current implementation.
"""
from pathlib import Path
import re, shlex, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'src_Core/RISCY_OOO/procs/RV64G_OOO/MemExePipeline.bsv').read_text()
if 'import ObjIdReverseMap::*;' in s:
 print('SKIP: reverse-map branch; run Tests/test_objid_reversemap.py for coherence validation')
 raise SystemExit(0)
def rule(n):
 m=re.search(r'    rule '+n+r'\b.*?    endrule',s,re.S); assert m,n; return m.group()
a=s.index('    PulseWire objIdMode3Seen');b=s.index('    // Key with full address',a)
code='''package Test;
import Vector::*;
import FIFOF::*;
import StmtFSM::*;
import Fifos::*;
import Map::*;
import Types::*;
import CacheUtils::*;
import CCTypes::*;
import RWire::*;
import DReg::*;

typedef struct { LineAddr line; Bool flush1k; Bool flush4k; } ObjIdEvictReq deriving(Bits, FShow);
(* synthesize *)
module mkTest(Empty);
    MapSplit#(Addr, Bit#(4), Maybe#(MemTaggedData), 4) objIdBuf <- mkMapLossyBRAM;
    Fifo#(2, ObjIdEvictReq) objIdEvictQ <- mkCFFifo;
    // Exercise the enabled logic even during a temporary no-Bloom FPGA build.
    Bool objIdBloomEnabled = True;
    Reg#(Bool) objIdBufMayContainMode3 <- mkReg(False);
    Reg#(UInt#(16)) cycles <- mkReg(0);
    Reg#(UInt#(8)) flushes <- mkReg(0);
    rule timeout;
        cycles <= cycles + 1;
        if (cycles == 1000) begin $display("FAIL: timeout"); $finish(1); end
    endrule
'''+s[a:b]+''.join(rule(n)+'\n' for n in ['setObjIdBufMayContainMode3','doUpdateObjIdPAddrFilter','doObjIdFilterLookup','doObjIdFlush'])
# Count real clear requests, without changing the extracted flush rule.
code+='''
    rule countFlush (objIdFlushPending && objIdBuf.clearDone);
        flushes <= flushes + 1;
    endrule
    function Action check(Bool ok, String message) = action
        if (!ok) begin $display("FAIL: %s", message); $finish(1); end
    endaction;
    function Action evict(Addr addr, Bool oneK, Bool fourK) = action
        objIdEvictQ.enq(ObjIdEvictReq {line: getLineAddr(addr), flush1k: oneK, flush4k: fourK});
    endaction;
    Stmt test = seq
        await(objIdBuf.clearDone);
        action
            objIdBuf.update(MapKeyIndex {key: 64'h1000, index: 0}, Valid(unpack(129'h1234)));
            objIdPAddrFilterLdUpdate.wset(64'h1000);
        endaction
        delay(3);
        evict(64'h2000, True, True);
        delay(4);
        check(flushes == 0, "nonmatching eviction flushed");
        action objIdBuf.lookupStart(MapKeyIndex {key: 64'h1000, index: 0}); endaction
        action check(isValid(objIdBuf.lookupRead), "entry missing before flush"); endaction
        // Relaxed Map: a later write must not invalidate a held BRAM snapshot.
        action objIdBuf.update(MapKeyIndex {key: 64'h1000, index: 0}, Valid(unpack(129'h5678))); endaction
        delay(3);
        action
            let snapshot = objIdBuf.lookupRead;
            check(isValid(snapshot), "later write invalidated held snapshot");
            check(pack(fromMaybe(unpack(0), fromMaybe(Invalid, snapshot))) == 129'h1234,
                  "held snapshot was forwarded instead of remaining old");
        endaction
        action objIdBuf.lookupStart(MapKeyIndex {key: 64'h1000, index: 0}); endaction
        action
            check(pack(fromMaybe(unpack(0), fromMaybe(Invalid, objIdBuf.lookupRead))) == 129'h5678,
                  "fresh lookup did not see committed update");
        endaction
        evict(64'h1000, True, True);
        await(flushes == 1);
        check(!objIdBuf.clearDone, "clear did not start");
        check(!isValid(objIdBuf.lookupRead), "lookup hit during clear");
        await(objIdBuf.clearDone);
        action objIdBuf.lookupStart(MapKeyIndex {key: 64'h1000, index: 0}); endaction
        action check(!isValid(objIdBuf.lookupRead), "entry survived flush"); endaction
        evict(64'h1000, True, True);
        delay(4);
        check(flushes == 1, "filter did not reset");
        // Publish load/store fills in exactly the eviction-lookup cycle.
        evict(64'h3000, True, True);
        action
            objIdPAddrFilterLdUpdate.wset(64'h3000);
            objIdPAddrFilterStUpdate.wset(64'h4000);
        endaction
        await(flushes == 2);
        await(objIdBuf.clearDone);
        // Mode-3 gate: a 1KiB-only event is ignored until mode 3 is seen.
        action objIdPAddrFilterStUpdate.wset(64'h5000); endaction
        evict(64'h5000, True, False);
        delay(4);
        check(flushes == 2, "1KiB flushed without mode 3");
        evict(64'h5000, True, False);
        action objIdMode3Seen.send; endaction
        await(flushes == 3);
        await(objIdBuf.clearDone);
        // Store fills must also be visible in the eviction-lookup cycle.
        evict(64'h6000, True, True);
        action objIdPAddrFilterStUpdate.wset(64'h6000); endaction
        await(flushes == 4);
        await(objIdBuf.clearDone);
        // Single-hash collisions must cause a conservative flush.
        action
            check(objIdPAddrFilterIndex(0) == objIdPAddrFilterIndex((257 << valueOf(LgLineSzBytes))), "test collision wrong");
            objIdPAddrFilterLdUpdate.wset(0);
        endaction
        evict((257 << valueOf(LgLineSzBytes)), True, True);
        await(flushes == 5);
        await(objIdBuf.clearDone);
        $display("PASS: Bloom eviction, same-cycle fills, mode-3 gating, collisions, and BRAM flush");
        $finish(0);
    endseq;
    mkAutoFSM(test);
endmodule
endpackage
'''
workspace = tempfile.TemporaryDirectory(prefix='toooba-bloom-test-')
base = Path(workspace.name)
(base/'Test.bsv').write_text(code)
dry_run = subprocess.check_output(['make', '-n', 'compile_synth'], cwd=root/'src_SSITH_P3', text=True)
cmd=next(x for x in dry_run.splitlines() if x.startswith('bsc '))
args=shlex.split(cmd)[1:];defs=[];paths=[];i=0
while i<len(args):
 if args[i] in ['-D','-p']:
  (defs if args[i]=='-D' else paths).extend(args[i:i+2]);i+=2
 else:i+=1
common=defs+paths+['-p','+:'+str(base),'-bdir',str(base),'-simdir',str(base),'-info-dir',str(base)]
subprocess.run(['bsc','-sim','-u','-g','mkTest',*common,str(base/'Test.bsv')],cwd=root/'src_SSITH_P3',check=True)
subprocess.run(['bsc','-sim','-e','mkTest',*common,'-o',str(base/'test')],cwd=root/'src_SSITH_P3',check=True)
result = subprocess.check_output([str(base/'test')], text=True)
print(result, end='')
assert 'PASS:' in result and 'FAIL:' not in result, 'ObjID Bloom simulation failed'
workspace.cleanup()
