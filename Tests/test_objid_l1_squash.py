#!/usr/bin/env python3
"""Squash/reuse real child LQ tags with the production registered send rules.

TOOOBA_METADATA_FIRST=1 reverses reply order; TOOOBA_KILL_ALL=1 tests full squash.
TOOOBA_SPEC_TEST_DIR retains the compiler cache for repeated configurations.
"""
from pathlib import Path
import contextlib, os, re, shlex, subprocess, tempfile
root = Path(__file__).resolve().parents[1]
source = (root/'src_Core/RISCY_OOO/procs/RV64G_OOO/MemExePipeline.bsv').read_text()
queues = [next(line for line in source.splitlines() if ' '+name+' <-' in line)
          for name in ('reqLdQ', 'checkedObjIdLdQ')]
rules = []
for name in ('sendLdObjSealRdToMem', 'sendLdToMem'):
    match = re.search(r'    rule '+name+r'\b.*?    endrule', source, re.S)
    assert match, name
    rules.append(match.group())
code = r'''
package Test;
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
import StoreBuffer::*;
import HasSpecBits::*;
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
    Reg#(UInt#(16)) cycles <- mkReg(0);
    rule watchdog;
        cycles <= cycles + 1;
        if (cycles == 2000) begin $display("FAIL: timeout"); $finish(1); end
    endrule
    TestMem dMem = interface TestMem;
        interface TestPort procReq;
            method Action req(ProcRq#(DProcReqId) request) if(cacheReady);
                accepted.enq(request);
                count <= count + 1;
            endmethod
        endinterface
    endinterface;
__QUEUES__
    (* descending_urgency = "sendLdObjSealRdToMem, sendLdToMem" *)
__RULES__
    function Action check(Bool ok, String message) = action
        if (!ok) begin $display("FAIL: %s", message); $finish(1); end
    endaction;
    function MemInst instruction(Bool store);
        MemInst x = unpack(0);
        x.mem_func = store ? St : Ld;
        x.byteOrTagEn = DataMemAccess(unpack('1));
        return x;
    endfunction
    function Action address(LdStQTag tag, Addr data, Maybe#(Addr) metadata) = action
        let result <- lsq.updateAddr(tag, Invalid, True, data, False, DataMemAccess(unpack('1)), 1, 0, metadata, 0, unpack(0));
    endaction;
    function Action issue(LdQTag tag, Addr addr, Bool checkId) = action
        let result <- lsq.issueLd(tag, addr, Invalid, checkId, DataMemAccess(unpack('1)),
            SBSearchRes { matchIdx: Invalid, sourceId: unpack(0), forwardData: Invalid }, unpack(0));
        check(result == ToCache, "payload did not issue");
        reqLdQ.enq(tuple5(tag, addr, False, 0, unpack(0)));
        if (checkId) lsq.startObjIdCheck(tagged Ld tag);
    endaction;
    function Action issueChild(ObjIdQTag child, Addr addr) = action
        let info = lsq.getIssueObjId;
        check(info.tag == child && info.paddr == addr, "wrong child selected");
        lsq.issueObjId;
        checkedObjIdLdQ.enq(ProcRq { id: zeroExtend(child), addr: addr,
            toState: S, op: Ld, byteEn: ?, data: ?, amoInst: ?,
            loadTags: False, objSealRdType: Ld, inlineId: unpack(0), pcHash: 0 });
    endaction;
    Stmt test = seq
        delay(4);
        lsq.enqLd(unpack(1), instruction(False), Invalid, 1, 0);
        address(tagged Ld 0, 'h1000, Invalid);
        issue(0, 'h1000, False);
        lsq.enqLd(unpack(2), instruction(False), Invalid, 1, 0);
        address(tagged Ld 1, 'h2000, Valid('h8000));
        issue(1, 'h2000, True);
        issueChild(1, 'h8000);
        lsq.enqSt(unpack(3), instruction(True), Invalid, 1, 0);
        lsq.updateData(0, unpack(0));
        address(tagged St 0, 'h3000, Valid('h9000));
        issueChild(2, 'h9000);
        delay(3);
        check(count == 0, "cache accepted stalled requests");
        lsq.specUpdate.incorrectSpeculation(__KILL_ALL__, 0);
        check(lsq.skipObjIdFill(1), "wrong-path load metadata could fill buffer");
        check(lsq.skipObjIdFill(2), "wrong-path store metadata could fill buffer");
        check(isValid(lsq.enqStTag), "store tag held by old child reply");
        lsq.enqLd(unpack(11), instruction(False), Invalid, 0, 0);
        address(tagged Ld 0, 'h4000, Invalid);
        lsq.enqLd(unpack(12), instruction(False), Invalid, 0, 0);
        address(tagged Ld 1, 'h5000, Invalid);
        lsq.enqSt(unpack(13), instruction(True), Invalid, 0, 0);
        lsq.updateData(0, unpack(0));
        address(tagged St 0, 'h6000, Valid('ha000));
        cacheReady <= True;
        await(count == 4);
        cacheReady <= False;
        action check(accepted.first.addr == 'h8000 && accepted.first.id == 1, "old load-child request changed"); accepted.deq; endaction
        action check(accepted.first.addr == 'h9000 && accepted.first.id == 2, "old store-child request changed"); accepted.deq; endaction
        action check(accepted.first.addr == 'h1000 && accepted.first.id == 0, "old payload 0 changed"); accepted.deq; endaction
        action check(accepted.first.addr == 'h2000 && accepted.first.id == 1, "old payload 2 changed"); accepted.deq; endaction
        if (metadataFirst) seq
            action let done <- lsq.completeObjId(1, unpack(1)); check(!isValid(done), "stale load child notified ROB"); endaction
            action let hit <- lsq.getHit(tagged Ld 1); check(hit.waitWPResp, "metadata reply cleared payload barrier"); endaction
            action let reply <- lsq.respLd(1, unpack(129'hdead), False, False); check(reply.wrongPath, "old payload reached new parent"); endaction
        endseq else seq
            action let reply <- lsq.respLd(1, unpack(129'hdead), False, False); check(reply.wrongPath, "old payload reached new parent"); endaction
            action let hit <- lsq.getHit(tagged Ld 1); check(!hit.waitWPResp && lsq.skipObjIdFill(1), "payload/child barriers not independent"); endaction
            action let done <- lsq.completeObjId(1, unpack(1)); check(!isValid(done), "stale load child notified ROB"); endaction
        endseq
        action let reply <- lsq.respLd(0, unpack(129'hdead), False, False); check(reply.wrongPath, "old payload 0 reached new parent"); endaction
        action
            let done <- lsq.completeObjId(2, unpack(0));
            check(!isValid(done), "old child completed new store at same SQ tag");
        endaction
        issueChild(5, 'ha000);
        issue(0, 'h4000, False);
        issue(1, 'h5000, False);
        cacheReady <= True;
        await(count == 7);
        action check(accepted.first.addr == 'ha000 && accepted.first.id == 5, "new store-child request changed"); accepted.deq; endaction
        action check(accepted.first.addr == 'h4000 && accepted.first.id == 0, "new payload 0 issue"); accepted.deq; endaction
        action check(accepted.first.addr == 'h5000 && accepted.first.id == 1, "new payload 2 issue"); accepted.deq; endaction
        action let reply <- lsq.respLd(0, unpack(129'h1234), False, False); check(!reply.wrongPath, "new payload 0 discarded"); endaction
        action let reply <- lsq.respLd(1, unpack(129'h5678), False, False); check(!reply.wrongPath, "new payload 2 discarded"); endaction
        action
            let done <- lsq.completeObjId(5, unpack(1));
            check(done == Valid(tuple2(unpack(13), St)), "new child did not identify new instruction");
        endaction
        check(lsq.noWrongPathLoads, "response barriers did not drain");
        $display("PASS: registered child requests, backpressure, squash, independent barriers, reused store/load tags");
        $finish(0);
    endseq;
    mkAutoFSM(test);
endmodule
endpackage
'''
code = code.replace('__QUEUES__', '\n'.join(queues)).replace('__RULES__', '\n'.join(rules))
workspace = os.environ.get('TOOOBA_SPEC_TEST_DIR')
with (contextlib.nullcontext(workspace) if workspace else tempfile.TemporaryDirectory(prefix='toooba-squash-')) as temp:
    base = Path(temp)
    base.mkdir(parents=True, exist_ok=True)
    code = code.replace('__METADATA_FIRST__', 'True' if os.environ.get('TOOOBA_METADATA_FIRST') == '1' else 'False')
    code = code.replace('__KILL_ALL__', 'True' if os.environ.get('TOOOBA_KILL_ALL') == '1' else 'False')
    (base / 'Test.bsv').write_text(code)
    # Source-only checkouts generate this build dependency locally.
    events = root/'libs/RISCV_HPM_Events'
    subprocess.run(['python3', str(events/'parse_counters.py'), str(events/'counters.yaml'),
                    '-m', 'ProcTypes', '-s', str(base/'StatCounters.bsv')], check=True)
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
