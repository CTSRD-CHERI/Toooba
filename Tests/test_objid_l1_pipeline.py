#!/usr/bin/env python3
"""Exercise the production L1 send rules with a backpressured cache stub."""
from pathlib import Path
import re
import shlex
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'src_Core/RISCY_OOO/procs/RV64G_OOO/MemExePipeline.bsv').read_text()
queues = []
for name in ('reqLdQ', 'checkedObjIdLdQ'):
    queues.append(next(line for line in source.splitlines() if ' ' + name + ' <-' in line))
rules = []
for name in ('sendLdObjSealRdToMem', 'sendLdToMem'):
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
interface TestPort;
    method Action req(ProcRq#(DProcReqId) request);
endinterface
interface TestMem;
    interface TestPort procReq;
endinterface
(* synthesize *)
module mkTest(Empty);
    Bool storeUrgent = False;
    Bool multicore = True;
    Bool verbose = False;
    Reg#(Bool) cacheReady <- mkReg(False);
    Reg#(UInt#(8)) count <- mkReg(0);
    Reg#(Addr) lastAddr <- mkReg(0);
    Reg#(UInt#(16)) cycles <- mkReg(0);
    rule timeout;
        cycles <= cycles + 1;
        if (cycles == 1000) begin $display("FAIL: timeout"); $finish(1); end
    endrule
    TestMem dMem = interface TestMem;
        interface TestPort procReq;
            method Action req(ProcRq#(DProcReqId) request) if (cacheReady);
                count <= count + 1;
                lastAddr <= request.addr;
            endmethod
        endinterface
    endinterface;
''' + '\n'.join(queues) + '''
    (* descending_urgency = "sendLdObjSealRdToMem, sendLdToMem" *)
''' + '\n'.join(rules) + '''
    function Action check(Bool ok, String message) = action
        if (!ok) begin $display("FAIL: %s", message); $finish(1); end
    endaction;
    function ProcRq#(DProcReqId) metadata(Addr addr) = ProcRq {
        id: 0, addr: addr, toState: S, op: Ld, byteEn: ?, data: ?, amoInst: ?,
        loadTags: False, objSealRdType: Ld, inlineId: unpack(0), pcHash: 0
    };
    Stmt test = seq
        // A checked metadata request cannot bypass straight into L1.
        action cacheReady <= True; checkedObjIdLdQ.enq(metadata('h1000)); endaction
        check(count == 0, "metadata request bypassed register boundary");
        action check(count == 1 && lastAddr == 'h1000, "metadata request did not issue next cycle"); cacheReady <= False; endaction
        // Independent queues accept normal and metadata traffic while stalled.
        action
            checkedObjIdLdQ.enq(metadata('h2000));
            reqLdQ.enq(tuple5(0, 'h3000, False, 0, unpack(0)));
        endaction
        checkedObjIdLdQ.enq(metadata('h2040));
        delay(3);
        action
            check(count == 1 && checkedObjIdLdQ.first.addr == 'h2000,
                  "backpressure lost or issued a queued request");
            cacheReady <= True;
        endaction
        // Preserve metadata-load, normal-load, metadata-store priority/order.
        action check(count == 1, "cache accepted while stalled"); endaction
        check(count == 2 && lastAddr == 'h2000, "first metadata load order");
        check(count == 3 && lastAddr == 'h2040, "second metadata load order");
        check(count == 4 && lastAddr == 'h3000, "normal load arbitration");
        action check(count == 4 && lastAddr == 'h3000, "payload drained"); cacheReady <= False; endaction
        checkedObjIdLdQ.enq(metadata('h4000));
        delay(2);
        action check(count == 4, "shared store-metadata FIFO ignored backpressure"); cacheReady <= True; endaction
        check(count == 4, "metadata FIFO bypassed register boundary");
        action check(count == 5 && lastAddr == 'h4000, "shared store metadata request"); cacheReady <= False; endaction
        delay(2);
        check(count == 5, "request duplicated");
        // Normal loads must also cross a register boundary.
        action cacheReady <= True; reqLdQ.enq(tuple5(0, 'h5000, False, 0, unpack(0))); endaction
        check(count == 5, "normal load bypassed register boundary");
        check(count == 6 && lastAddr == 'h5000, "normal load next-cycle issue");
        $display("PASS: registered L1 issue, arbitration, order, backpressure, no duplication");
        $finish(0);
    endseq;
    mkAutoFSM(test);
endmodule
endpackage
'''
with tempfile.TemporaryDirectory(prefix='toooba-l1-pipeline-') as temp:
    base = Path(temp)
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
    flags += ['-p', '+:'+temp, '-bdir', temp, '-simdir', temp, '-info-dir', temp]
    subprocess.run(['bsc', '-sim', '-u', '-g', 'mkTest', *flags, str(base/'Test.bsv')], cwd=root/'src_SSITH_P3', check=True)
    subprocess.run(['bsc', '-sim', '-e', 'mkTest', *flags, '-o', str(base/'test')], cwd=root/'src_SSITH_P3', check=True)
    result = subprocess.check_output([str(base/'test')], text=True)
    print(result, end='')
    assert 'PASS:' in result and 'FAIL:' not in result, 'L1 pipeline simulation failed'
