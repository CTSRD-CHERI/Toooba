#!/usr/bin/env python3
"""Exercise production reverse-map coherence rules and the real ObjID BRAM map."""
from pathlib import Path
import re, shlex, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'src_Core/RISCY_OOO/procs/RV64G_OOO/MemExePipeline.bsv').read_text()
def rule(n):
    m=re.search(r'    rule '+n+r'\b.*?    endrule', s, re.S)
    assert m,n
    return m.group()
a=s.index('    PulseWire objIdMode3Seen'); b=s.index('    // Key with full address',a)
helper=re.search(r'    function Action updateObjIdBuf\(.*?    endfunction',s,re.S).group()
code=r'''package Test;
import Vector::*;
import StmtFSM::*;
import Fifos::*;
import Map::*;
import ObjIdReverseMap::*;
import Types::*;
import ProcTypes::*;
import CacheUtils::*;
import CCTypes::*;
import RWire::*;
typedef struct { LineAddr line; Bool flush1k; Bool flush4k; } ObjIdEvictReq deriving(Bits, FShow);
(* synthesize *)
module mkTest(Empty);
    MapSplit#(Addr, Bit#(4), Maybe#(MemTaggedData), 4) objIdBuf <- mkMapLossyBRAM;
    Fifo#(2, ObjIdEvictReq) objIdEvictQ <- mkCFFifo;
    Bool objIdCoherenceEnabled = True;
    Reg#(Bool) objIdBufMayContainMode3 <- mkReg(False);
    Reg#(UInt#(16)) cycles <- mkReg(0);
    Reg#(UInt#(8)) flushes <- mkReg(0);
    rule watchdog;
        cycles <= cycles + 1;
        if (cycles == 1500) begin $display("FAIL: timeout"); $finish(1); end
    endrule
'''+s[a:b]+helper+'\n'+''.join(rule(n)+'\n' for n in ['setObjIdBufMayContainMode3','doObjIdReverseLookup','doObjIdFlush'])+r'''
    rule countFlush (objIdFlushPending && objIdBuf.clearDone);
        flushes <= flushes + 1;
    endrule
    function Action check(Bool ok, String msg) = action
        if (!ok) begin $display("FAIL: %s",msg); $finish(1); end
    endaction;
    function Action fill(Addr va, Addr pa, Bool store) = action
        updateObjIdBuf(va, pa, unpack(129'h1234));
        if (store) objIdPAddrFilterStUpdate.wset(pa);
        else objIdPAddrFilterLdUpdate.wset(pa);
    endaction;
    function Action evict(Addr pa, Bool oneK, Bool fourK) = action
        objIdEvictQ.enq(ObjIdEvictReq {line:getLineAddr(pa),flush1k:oneK,flush4k:fourK});
    endaction;
    Stmt test = seq
        await(objIdBuf.clearDone);
        fill('h1000,'h1000,False);
        delay(3);
        // Same reverse-map set, different full tag: no false positive.
        evict('h2000,True,True);
        delay(4);
        check(flushes == 0, "tag collision flushed before saturation");
        // Lookup processes this eviction in the same cycle as the fill.
        evict('h4000,False,True);
        fill('h3000,'h4000,False);
        await(flushes == 1);
        await(objIdBuf.clearDone);
        check(!objIdPAddrBuf.contains(getLineAddr('h1000)), "reverse state survived flush");
        action objIdBuf.lookupStart(MapKeyIndex {key:'h3000,index:hash(64'h3000)}); endaction
        action check(!isValid(objIdBuf.lookupRead), "forward state survived flush"); endaction
        fill('h1000,'h1000,True);
        delay(3);
        evict('h1000,True,False);
        delay(4);
        check(flushes == 1, "mode-3 gating ignored");
        evict('h1000,True,False);
        objIdMode3Seen.send;
        await(flushes == 2);
        await(objIdBuf.clearDone);
        evict('h2000,False,True);
        fill('h5000,'h2000,True);
        await(flushes == 3);
        await(objIdBuf.clearDone);
        // Several words/virtual aliases may share one physical metadata line.
        fill('h10000,0,False);
        fill('h10010,16,True);
        fill('h10020,'h400,False);
        fill('h10030,'h800,False);
        fill('h10040,'hc00,False);
        delay(3);
        check(objIdPAddrBuf.contains(getLineAddr(0)), "alias update lost original line");
        check(!objIdPAddrBuf.contains(getLineAddr('h1040)), "duplicate line consumed a way");
        evict('h1040,False,True);
        delay(4);
        check(flushes == 3, "untracked physical line flushed");
        // A fifth line in one four-way set must never silently lose coverage.
        fill('h10050,'h1000,False);
        delay(3);
        check(objIdPAddrBuf.contains(getLineAddr(0)), "overflow lost old mapping");
        check(objIdPAddrBuf.contains(getLineAddr('h1000)), "overflow lost new mapping");
        check(objIdPAddrBuf.contains(getLineAddr('h1040)), "saturation not conservative");
        evict('h1040,False,True);
        await(flushes == 4);
        await(objIdBuf.clearDone);
        check(!objIdPAddrBuf.contains(getLineAddr('h1040)), "saturation survived flush");
        fill('h20000,'h8000,False);
        delay(3);
        evict('h9000,False,True);
        delay(4);
        check(flushes == 4, "clear failed to restore exact tracking");
        evict('h8000,False,True);
        await(flushes == 5);
        await(objIdBuf.clearDone);
        $display("PASS: reverse tags, aliases, same-cycle load/store fills, mode gating, saturation, and paired forward/reverse flush");
        $finish(0);
    endseq;
    mkAutoFSM(test);
endmodule
endpackage
'''
with tempfile.TemporaryDirectory(prefix='toooba-reversemap-test-') as temp:
    base=Path(temp); (base/'Test.bsv').write_text(code)
    ev=root/'libs/RISCV_HPM_Events'
    subprocess.run(['python3',str(ev/'parse_counters.py'),str(ev/'counters.yaml'),'-m','ProcTypes','-s',str(base/'StatCounters.bsv')],check=True)
    args=shlex.split(next(x for x in subprocess.check_output(['make','-n','compile_synth'],cwd=root/'src_SSITH_P3',text=True).splitlines() if x.startswith('bsc ')))[1:]
    flags=[]
    for i,x in enumerate(args[:-1]):
        if x in ('-D','-p'): flags.extend(args[i:i+2])
    flags+=['-check-assert','-aggressive-conditions','-p','+:'+temp,'-bdir',temp,'-simdir',temp,'-info-dir',temp]
    subprocess.run(['bsc','-sim','-u','-g','mkTest',*flags,str(base/'Test.bsv')],cwd=root/'src_SSITH_P3',check=True)
    subprocess.run(['bsc','-sim','-e','mkTest',*flags,'-Xc++','-O1','-o',str(base/'test')],cwd=root/'src_SSITH_P3',check=True)
    result=subprocess.check_output([str(base/'test')],text=True,timeout=60)
    print(result,end='')
    assert 'PASS:' in result and 'FAIL:' not in result
