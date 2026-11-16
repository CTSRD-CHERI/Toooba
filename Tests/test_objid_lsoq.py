#!/usr/bin/env python3
"""Exercise the independent ObjID queue through the real split LSQ."""
from pathlib import Path
import contextlib, os, shlex, subprocess, tempfile
root = Path(__file__).resolve().parents[1]
code = r'''
package Test;
import Types::*;
import ProcTypes::*;
import SplitLSQ::*;
import StoreBuffer::*;
import CCTypes::*;
import CacheUtils::*;
import StmtFSM::*;
import Vector::*;
import GetPut::*;
import HasSpecBits::*;
(* synthesize *)
module mkTest(Empty);
    SplitLSQ lsq <- mkSplitLSQ;
    Reg#(Bool) drain <- mkReg(False);
    Reg#(Bool) observeLr <- mkReg(False);
    Reg#(Bool) lrReady <- mkReg(False);
    Reg#(UInt#(16)) cycles <- mkReg(0);
    Reg#(UInt#(8)) retired <- mkReg(0);
    Reg#(UInt#(8)) filled <- mkReg(0);
    Reg#(UInt#(8)) stores <- mkReg(0);
    Reg#(ObjIdQTag) lookup <- mkReg(0);
    Reg#(ObjIdQTag) oldLookup <- mkReg(0);
    rule watchdog;
        cycles <= cycles + 1;
        if (cycles == 2500) begin $display("FAIL: timeout"); $finish(1); end
    endrule
    rule retireLoads(drain);
        let entry = lsq.firstLd;
        lsq.deqLd;
        retired <= retired + 1;
    endrule
    rule observeAtomic(observeLr);
        let entry = lsq.firstLd;
        lsq.deqLd;
        lrReady <= True;
        observeLr <= False;
    endrule
    function Action check(Bool ok, String message) = action
        if (!ok) begin $display("FAIL: %s", message); $finish(1); end
    endaction;
    function MemInst instruction(Bool store);
        MemInst x = unpack(0);
        x.mem_func = store ? St : Ld;
        x.byteOrTagEn = DataMemAccess(unpack('1));
        return x;
    endfunction
    function Action address(LdStQTag tag, Addr data, Maybe#(Addr) metadata, Bit#(8) generation) = action
        let result <- lsq.updateAddr(tag, Invalid, True, data, False, DataMemAccess(unpack('1)),
                                    generation, 0, metadata, 0, unpack(0));
    endaction;
    function Action issueData(LdQTag tag, Addr data, Bool metadata) = action
        let result <- lsq.issueLd(tag, data, Invalid, metadata, DataMemAccess(unpack('1)),
            SBSearchRes {matchIdx: Invalid, sourceId: unpack(0), forwardData: Invalid}, unpack(0));
        check(result == ToCache, "payload issue");
        if (metadata) lsq.startObjIdCheck(tagged Ld tag);
    endaction;
    function Action issueLookup(ObjIdQTag tag, LdStQTag parent, Addr addr) = action
        let info = lsq.getIssueObjId;
        check(info.tag == tag && info.parent == parent && info.paddr == addr, "lookup ownership/address");
        lsq.issueObjId;
    endaction;
    Bit#(16) creditDrainDelay = fromInteger(valueOf(ObjIdQSize)+3);
    Stmt test = seq
        delay(4);
        // Unresolved instructions exhaust the independent ObjID credit pool.
        while (filled < fromInteger(min(valueOf(ObjIdQSize), valueOf(LdQSize)))) action
            check(isValid(lsq.enqLdTag), "load reservation blocked early");
            lsq.enqLd(unpack(zeroExtend(pack(filled))), instruction(False), Invalid, 1, 0);
            filled <= filled + 1;
        endaction
        while (stores < fromInteger(max(0, min(valueOf(ObjIdQSize)-valueOf(LdQSize), valueOf(StQSize))))) action
            check(isValid(lsq.enqStTag), "store reservation blocked early");
            lsq.enqSt(unpack(128+zeroExtend(pack(stores))), instruction(True), Invalid, 1, 0);
            stores <= stores + 1;
        endaction
        check(!isValid(lsq.enqLdTag) && !isValid(lsq.enqStTag), "reservation pool over-allocated");
        lsq.specUpdate.incorrectSpeculation(True, 0);
        delay(creditDrainDelay);
        filled <= 0;
        stores <= 0;
        // Resolving no-check reservations allows the full payload queues
        // to fill even when ObjID credit capacity is smaller than either.
        while (filled < fromInteger(valueOf(LdQSize))) seq
            action
                check(isValid(lsq.enqLdTag), "no-check load failed to return credit");
                lsq.enqLd(unpack(zeroExtend(pack(filled))), instruction(False), Invalid, 1, 0);
            endaction
            action
                address(tagged Ld truncate(pack(filled)), 'h10000 + (zeroExtend(pack(filled)) << 4), Invalid, 0);
                filled <= filled + 1;
            endaction
        endseq
        while (stores < fromInteger(valueOf(StQSize))) seq
            action
                check(isValid(lsq.enqStTag), "no-check store failed to return credit");
                lsq.enqSt(unpack(128+zeroExtend(pack(stores))), instruction(True), Invalid, 1, 0);
            endaction
            action
                address(tagged St truncate(pack(stores)), 'h20000 + (zeroExtend(pack(stores)) << 4), Invalid, 0);
                stores <= stores + 1;
            endaction
        endseq
        check(!isValid(lsq.enqLdTag) && !isValid(lsq.enqStTag), "full payload queues over-allocated");
        lsq.specUpdate.incorrectSpeculation(True, 0);
        delay(creditDrainDelay);
        // Buffer-hit/no-check reservation is returned while the payload is
        // still outstanding. Ordinary LQ tags remain consecutive.
        lsq.enqLd(unpack(1), instruction(False), Invalid, 0, 0);
        address(tagged Ld 0, 'h1000, Invalid, 1);
        issueData(0, 'h1000, False);
        drain <= True;
        delay(4);
        check(retired == 0 && lsq.objIdQueueEmpty && !isValid(lsq.objIdChild(tagged Ld 0)), "no-check credit held until payload/commit");
        check(lsq.enqLdTag == Valid(tagged Ld 1), "metadata interdigitated with ordinary loads");
        action let response <- lsq.respLd(0, unpack(0), False, False); endaction
        await(retired == 1);
        drain <= False;
        lsq.enqLd(unpack(2), instruction(False), Invalid, 0, 0);
        lookup <= fromMaybe(?, lsq.objIdChild(tagged Ld 1));
        // Exercise the production same-cycle translate-and-immediately-issue path.
        action
            let translated <- lsq.updateAddr(tagged Ld 1, Invalid, True, 'h2000, False,
                DataMemAccess(unpack('1)), 1, 0, Valid('h8000), 0, unpack(0));
            let issued <- lsq.issueLd(1, 'h2000, Invalid, True, DataMemAccess(unpack('1)),
                SBSearchRes {matchIdx:Invalid, sourceId:unpack(0), forwardData:Invalid}, unpack(0));
            check(issued == ToCache, "same-cycle issue");
            lsq.startObjIdCheck(tagged Ld 1);
        endaction
        issueLookup(lookup, tagged Ld 1, 'h8000);
        action let response <- lsq.respLd(1, unpack(0), False, False); endaction
        drain <= True;
        delay(3);
        check(retired == 1, "load retired before lookup verdict");
        action let result <- lsq.completeObjId(lookup, unpack(1)); check(!isValid(result), "load lookup notified store ROB"); endaction
        await(retired == 2);
        drain <= False;
        // Store lookup release is independent of both LQ and ROB retirement.
        lsq.enqSt(unpack(3), instruction(True), Invalid, 0, 0);
        lookup <= fromMaybe(?, lsq.objIdChild(tagged St 0));
        lsq.updateData(0, unpack(0));
        address(tagged St 0, 'h3000, Valid('h9000), 1);
        issueLookup(lookup, tagged St 0, 'h9000);
        action
            let result <- lsq.completeObjId(lookup, unpack(1));
            check(result == Valid(tuple2(unpack(3), St)), "store instruction linkage");
        endaction
        delay(4);
        check(retired == 2 && !lsq.stqEmpty && lsq.objIdQueueEmpty && !isValid(lsq.objIdChild(tagged St 0)), "store lookup tied to data/commit retirement");
        lsq.setAtCommit[0].put(tagged St 0);
        lsq.deqSt;
        // Squash leaves the lookup tag reserved until its old reply drains,
        // while the SQ slot can immediately belong to another instruction.
        lsq.enqSt(unpack(4), instruction(True), Invalid, 1, 0);
        oldLookup <= fromMaybe(?, lsq.objIdChild(tagged St 1));
        lsq.updateData(1, unpack(0));
        address(tagged St 1, 'h4000, Valid('ha000), 1);
        issueLookup(oldLookup, tagged St 1, 'ha000);
        lsq.specUpdate.incorrectSpeculation(False, 0);
        check(!lsq.noWrongPathLoads && isValid(lsq.enqStTag), "wrong-path lookup/parent lifetime");
        lsq.enqSt(unpack(5), instruction(True), Invalid, 0, 0);
        lookup <= fromMaybe(?, lsq.objIdChild(tagged St 1));
        check(lookup != oldLookup, "lookup tag reused with old reply outstanding");
        lsq.updateData(1, unpack(0));
        address(tagged St 1, 'h5000, Valid('hb000), 1);
        issueLookup(lookup, tagged St 1, 'hb000);
        action
            check(lsq.skipObjIdFill(oldLookup), "old lookup may train buffer");
            let result <- lsq.completeObjId(oldLookup, unpack(1));
            check(!isValid(result), "old lookup completed reused SQ instruction");
        endaction
        action let result <- lsq.completeObjId(lookup, unpack(0)); check(!isValid(result), "ID mismatch completed store"); endaction
        action let entry = lsq.firstSt; check(isValid(entry.fault), "new store lost mismatch"); lsq.deqSt; endaction
        delay(4);
        check(lsq.noWrongPathLoads, "old lookup barrier not drained");
        // At-commit protection covers the associated speculative lookup too.
        lsq.enqSt(unpack(6), instruction(True), Invalid, 0, 0);
        lookup <= fromMaybe(?, lsq.objIdChild(tagged St 2));
        lsq.updateData(2, unpack(0));
        address(tagged St 2, 'h6000, Valid('hc000), 1);
        issueLookup(lookup, tagged St 2, 'hc000);
        lsq.setAtCommit[0].put(tagged St 2);
        lsq.specUpdate.incorrectSpeculation(True, 0);
        action let result <- lsq.completeObjId(lookup, unpack(1)); check(result == Valid(tuple2(unpack(6), St)), "committed lookup canceled"); endaction
        lsq.deqSt;
        check(retired == 2 && lsq.stqEmpty && lsq.noWrongPathLoads, "final bookkeeping");
        // LR must resolve its metadata obligation before releasing its
        // parent slot to the atomic payload path at commit.
        action
            let lr = instruction(False);
            lr.mem_func = Lr;
            lsq.enqLd(unpack(7), lr, Invalid, 0, 0);
        endaction
        lookup <= fromMaybe(?, lsq.objIdChild(tagged Ld 2));
        address(tagged Ld 2, 'h7000, Valid('hd000), 1);
        lsq.setAtCommit[0].put(tagged Ld 2);
        observeLr <= True;
        delay(4);
        check(!lrReady, "LR issued before metadata verdict");
        issueLookup(lookup, tagged Ld 2, 'hd000);
        action let result <- lsq.completeObjId(lookup, unpack(1)); check(!isValid(result), "LR metadata notified store ROB"); endaction
        await(lrReady);
        action
            let fence = instruction(True);
            fence.mem_func = Fence;
            fence.byteOrTagEn = DataMemAccess(replicate(False));
            lsq.enqSt(unpack(8), fence, Invalid, 0, 0);
        endaction
        lsq.setAtCommit[0].put(tagged St 3);
        action
            let entry = lsq.firstSt;
            check(entry.objIdSealOk, "fence acquired metadata obligation");
            lsq.deqSt;
        endaction
        $display("PASS: independent ObjID credit exhaustion/wraparound, full LQ/SQ capacity, execute-time credit return, same-cycle issue, independent lookup tags, squash/reuse, commit protection, LR gating, fences");
        $finish(0);
    endseq;
    mkAutoFSM(test);
endmodule
endpackage
'''
workspace = os.environ.get('TOOOBA_LSOQ_TEST_DIR')
with (contextlib.nullcontext(workspace) if workspace else tempfile.TemporaryDirectory(prefix='toooba-lsoq-')) as temp:
    base = Path(temp)
    base.mkdir(parents=True, exist_ok=True)
    (base/'Test.bsv').write_text(code)
    events = root/'libs/RISCV_HPM_Events'
    subprocess.run(['python3', str(events/'parse_counters.py'), str(events/'counters.yaml'), '-m', 'ProcTypes', '-s', str(base/'StatCounters.bsv')], check=True)
    dry = subprocess.check_output(['make', '-n', 'compile_synth', *(['OBJIDQ_SIZE='+os.environ['TOOOBA_OBJIDQ_SIZE']] if os.environ.get('TOOOBA_OBJIDQ_SIZE') else [])], cwd=root/'src_SSITH_P3', text=True)
    args = shlex.split(next(line for line in dry.splitlines() if line.startswith('bsc ')))[1:]
    flags = []
    for i, arg in enumerate(args[:-1]):
        if arg in ('-D', '-p'): flags.extend(args[i:i+2])
    flags += ['-D', 'BSIM', '-check-assert', '+RTS', '-K128M', '-RTS', '-steps-max-intervals', '10000000', '-steps-warn-interval', '1000000', '-aggressive-conditions']
    flags += ['-p', '+:'+str(base), '-bdir', str(base), '-simdir', str(base), '-info-dir', str(base)]
    subprocess.run(['bsc', '-sim', '-u', '-g', 'mkTest', *flags, str(base/'Test.bsv')], cwd=root/'src_SSITH_P3', check=True)
    subprocess.run(['bsc', '-sim', '-e', 'mkTest', *flags, '-Xc++', '-O1', '-o', str(base/'test')], cwd=root/'src_SSITH_P3', check=True)
    result = subprocess.check_output([str(base/'test')], text=True, timeout=60)
    print(result, end='')
    assert 'PASS:' in result and 'FAIL:' not in result
