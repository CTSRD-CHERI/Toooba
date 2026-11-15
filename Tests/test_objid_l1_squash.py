#!/usr/bin/env python3
"""Exercise real LSQ squash bookkeeping with stalled registered L1 queues.

TOOOBA_METADATA_FIRST=1 tests metadata-before-data replies; TOOOBA_KILL_ALL=1
uses a full squash. TOOOBA_SPEC_TEST_DIR optionally retains the compiler cache.
"""
from pathlib import Path
import re
import shlex
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'src_Core/RISCY_OOO/procs/RV64G_OOO/MemExePipeline.bsv').read_text()
queues = []
for name in ('reqLdQ', 'checkedObjIdLdQ', 'checkedObjIdStQ'):
    queues.append(next(line for line in source.splitlines() if ' ' + name + ' <-' in line))
rules = []
for name in ('sendLdObjSealRdToMem', 'sendLdToMem', 'sendStObjSealRdToMem'):
    match = re.search(r'    rule ' + name + r'\b.*?    endrule', source, re.S)
    assert match, name
    rules.append(match.group())
code = '''package Test;
import FIFOF::*;
import GetPut::*;
import StmtFSM::*;
import Types::*;
import ProcTypes::*;
import MemoryTypes::*;
import CacheUtils::*;
import CCTypes::*;
import L1CoCache::*;
import SplitLSQ::*;
import HasSpecBits::*;
import StoreBuffer::*;
interface TestPort;
    method Action req(ProcRq#(DProcReqId) request);
endinterface
interface TestMem;
    interface TestPort procReq;
endinterface
(* synthesize *)
module mkTest(Empty);
    SplitLSQ lsq <- mkSplitLSQ;
    FIFOF#(ProcRq#(DProcReqId)) accepted <- mkSizedFIFOF(8);
    Bool metadataFirst = __METADATA_FIRST__;
    Bool storeUrgent = False;
    Bool multicore = True;
    Bool verbose = False;
    Reg#(Bool) cacheReady <- mkReg(False);
    Reg#(UInt#(8)) count <- mkReg(0);
    Reg#(Addr) lastAddr <- mkReg(0);
    Reg#(UInt#(16)) cycles <- mkReg(0);
    rule timeout;
        cycles <= cycles + 1;
        if (cycles == 2000) begin $display("FAIL: timeout"); $finish(1); end
    endrule
    TestMem dMem = interface TestMem;
        interface TestPort procReq;
            method Action req(ProcRq#(DProcReqId) request) if (cacheReady);
                accepted.enq(request);
                count <= count + 1;
                lastAddr <= request.addr;
            endmethod
        endinterface
    endinterface;
''' + '\n'.join(queues) + '''
    (* descending_urgency = "sendLdObjSealRdToMem, sendLdToMem, sendStObjSealRdToMem" *)
''' + '\n'.join(rules) + '''
    function Action check(Bool ok, String message) = action
        if (!ok) begin $display("FAIL: %s", message); $finish(1); end
    endaction;
    function MemInst instruction(Bool store);
        MemInst m = unpack(0);
        m.mem_func = store ? St : Ld;
        m.byteOrTagEn = DataMemAccess(unpack('1));
        m.unsignedLd = True;
        return m;
    endfunction
    function ProcRq#(DProcReqId) metadata(Addr addr, DProcReqId tag, Bool store) = ProcRq {
        id: tag, addr: addr, toState: S, op: Ld, byteEn: ?, data: ?, amoInst: ?,
        loadTags: False, objSealRdType: store ? St : Ld, inlineId: unpack(0), pcHash: 0
    };
    function Action address(LdStQTag tag, Addr addr, Maybe#(Addr) meta, Bool waiting) = action
        let r <- lsq.updateAddr(tag, Invalid, True, addr, False, DataMemAccess(unpack('1)),
                               0, 0, meta, 0, unpack(0));
        check(r.waitWPResp == waiting, "unexpected old-response barrier during address update");
    endaction;
    function Action issue(LdQTag tag, Addr addr, Maybe#(Addr) meta) = action
        let r <- lsq.issueLd(tag, addr, meta, DataMemAccess(unpack('1)),
                            SBSearchRes {matchIdx: Invalid, sourceId: unpack(0), forwardData: Invalid}, unpack(0));
        check(r == ToCache, "load did not issue to cache");
        reqLdQ.enq(tuple5(tag, addr, False, 0, unpack(0)));
    endaction;
    Stmt test = seq
        delay(4);
        // Speculative requests become LSQ response obligations before entering FIFOs.
        lsq.enqLd(unpack(1), instruction(False), Invalid, 1, 0);
        address(tagged Ld 0, 'h1000, Invalid, False);
        issue(0, 'h1000, Invalid);
        lsq.enqLd(unpack(2), instruction(False), Invalid, 1, 0);
        address(tagged Ld 1, 'h2000, Valid('h8000), False);
        action
            let r <- lsq.issueLd(1, 'h2000, Valid('h8000), DataMemAccess(unpack('1)),
                                SBSearchRes {matchIdx: Invalid, sourceId: unpack(0), forwardData: Invalid}, unpack(0));
            check(r == ToCache, "metadata load did not issue");
            reqLdQ.enq(tuple5(1, 'h2000, False, 0, unpack(0)));
            checkedObjIdLdQ.enq(metadata('h8000, 1, False));
        endaction
        lsq.enqSt(unpack(3), instruction(True), Invalid, 1, 0);
        lsq.updateData(0, unpack(0));
        address(tagged St 0, 'h3000, Valid('h9000), False);
        checkedObjIdStQ.enq(metadata('h9000, 0, True));
        delay(3);
        check(count == 0, "cache accepted a stalled request");
        lsq.specUpdate.incorrectSpeculation(__KILL_ALL__, 0);
        action
            let r0 <- lsq.getHit(tagged Ld 0);
            check(r0.waitWPResp, "squashed data request not tracked");
            check(lsq.skipLdIdFill(1), "squashed load metadata could train ObjID buffer");
            check(lsq.skipStIdFill(0), "squashed store metadata could train ObjID buffer");
            check(!isValid(lsq.enqStTag), "store slot reused with metadata outstanding");
        endaction
        // Loads may reallocate tags, but cannot issue past old response barriers.
        lsq.enqLd(unpack(11), instruction(False), Invalid, 0, 0);
        address(tagged Ld 0, 'h4000, Invalid, True);
        lsq.enqLd(unpack(12), instruction(False), Invalid, 0, 0);
        address(tagged Ld 1, 'h5000, Invalid, True);
        delay(3);
        cacheReady <= True;
        await(count == 4);
        cacheReady <= False;
        // Check that all pre-squash requests drained exactly once with original tags/addresses.
        action check(accepted.first.addr == 'h8000 && accepted.first.id == 1, "old metadata-load request changed"); accepted.deq; endaction
        action check(accepted.first.addr == 'h1000 && accepted.first.id == 0, "old data-load request changed"); accepted.deq; endaction
        action check(accepted.first.addr == 'h2000 && accepted.first.id == 1, "second old data request changed"); accepted.deq; endaction
        action check(accepted.first.addr == 'h9000 && accepted.first.id == 0, "old metadata-store request changed"); accepted.deq; endaction
        if (metadataFirst) seq
            action
                check(lsq.skipLdIdFill(1), "stale metadata may fill on metadata-first response");
                lsq.updateLdObjIdSeal(1, unpack(129'hbad));
            endaction
            action
                let r <- lsq.getHit(tagged Ld 1);
                check(r.waitWPResp, "metadata response cleared data barrier");
            endaction
            action
                let r <- lsq.respLd(1, unpack(129'hdead), False, False);
                check(r.wrongPath && !isValid(r.dst), "metadata-first old data updated reused load");
            endaction
            action
                let r <- lsq.getHit(tagged Ld 1);
                check(!r.waitWPResp, "metadata-first responses failed to release barrier");
            endaction
        endseq else seq
        // Return data before metadata for reused load tag 1.
        action
            let r <- lsq.respLd(1, unpack(129'hdead), False, False);
            check(r.wrongPath && !isValid(r.dst), "old data updated reused load");
        endaction
        action
            let r <- lsq.getHit(tagged Ld 1);
            check(r.waitWPResp, "metadata barrier cleared by data response");
            check(lsq.skipLdIdFill(1), "metadata fill enabled before stale response drained");
        endaction
        lsq.updateLdObjIdSeal(1, unpack(129'hbad));
        action
            let r <- lsq.getHit(tagged Ld 1);
            check(!r.waitWPResp, "load metadata response failed to release barrier");
        endaction
        endseq
        action
            let r <- lsq.respLd(0, unpack(129'hdead), False, False);
            check(r.wrongPath && !isValid(r.dst), "old normal response updated reused load");
        endaction
        action
            let r <- lsq.updateStObjIdSeal(0, unpack(129'hbad));
            check(!isValid(r), "wrong-path store metadata completed an instruction");
        endaction
        check(isValid(lsq.enqStTag), "store slot remained blocked after stale metadata drained");
        lsq.enqSt(unpack(13), instruction(True), Invalid, 0, 0);
        // New owners can now issue and accept their own data normally.
        issue(0, 'h4000, Invalid);
        issue(1, 'h5000, Invalid);
        cacheReady <= True;
        await(count == 6);
        action check(accepted.first.addr == 'h4000 && accepted.first.id == 0, "new load 0 issue"); accepted.deq; endaction
        action check(accepted.first.addr == 'h5000 && accepted.first.id == 1, "new load 1 issue"); accepted.deq; endaction
        action
            let r <- lsq.respLd(0, unpack(129'h1234), False, False);
            check(!r.wrongPath && pack(r.data) == 129'h1234, "new load 0 did not accept own response");
        endaction
        action
            let r <- lsq.respLd(1, unpack(129'h5678), False, False);
            check(!r.wrongPath && pack(r.data) == 129'h5678, "new load 1 did not accept own response");
        endaction
        delay(3);
        check(count == 6, "queued request duplicated");
        $display("PASS: squash stalled data/metadata queues, load-tag reuse, store reuse barrier, delayed responses");
        $finish(0);
    endseq;
    mkAutoFSM(test);
endmodule
endpackage
'''
import contextlib
import os
workspace = os.environ.get('TOOOBA_SPEC_TEST_DIR')
with (contextlib.nullcontext(workspace) if workspace else tempfile.TemporaryDirectory(prefix='toooba-squash-')) as temp:
    base = Path(temp)
    base.mkdir(parents=True, exist_ok=True)
    code = code.replace('__METADATA_FIRST__', 'True' if os.environ.get('TOOOBA_METADATA_FIRST') == '1' else 'False')
    code = code.replace('__KILL_ALL__', 'True' if os.environ.get('TOOOBA_KILL_ALL') == '1' else 'False')
    (base / 'Test.bsv').write_text(code)
    dry_run = subprocess.check_output(['make', '-n', 'compile_synth'], cwd=root/'src_SSITH_P3', text=True)
    cmd = next(line for line in dry_run.splitlines() if line.startswith('bsc '))
    args = shlex.split(cmd)[1:]
    flags = []
    for i, arg in enumerate(args[:-1]):
        if arg in ('-D', '-p'):
            flags.extend(args[i:i+2])
    flags += ['+RTS', '-K128M', '-RTS']
    flags += ['-steps-max-intervals', '10000000', '-steps-warn-interval', '1000000', '-aggressive-conditions']
    flags += ['-p', '+:'+temp, '-bdir', temp, '-simdir', temp, '-info-dir', temp]
    subprocess.run(['bsc', '-sim', '-u', '-g', 'mkTest', *flags, str(base/'Test.bsv')], cwd=root/'src_SSITH_P3', check=True)
    subprocess.run(['bsc', '-sim', '-e', 'mkTest', *flags, '-o', str(base/'test')], cwd=root/'src_SSITH_P3', check=True)
    result = subprocess.check_output([str(base/'test')], text=True)
    print(result, end='')
    assert 'PASS:' in result and 'FAIL:' not in result, 'L1 pipeline simulation failed'
