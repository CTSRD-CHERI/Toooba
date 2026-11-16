#!/usr/bin/env python3
"""Check production retry-credit flow with the real DTLB and speculative FIFOs.

DTLB bare-mode responses have the hit-path latency. ObjID-buffer verdicts are
forced hits/misses to isolate reservation throughput and retry capacity.
"""
from pathlib import Path
import contextlib, os, re, shlex, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'src_Core/RISCY_OOO/procs/RV64G_OOO/MemExePipeline.bsv').read_text()
def rule(name):
    m=re.search(r'    rule '+name+r'\b.*?    endrule',s,re.S)
    assert m,name
    return m.group()
retry=rule('sendObjIdTranslation').replace('rule sendObjIdTranslation;', 'rule sendObjIdTranslation (allowRetry);')
response=rule('doDataTlb')
code=r"""package Test;
import Vector::*;
import StmtFSM::*;
import Ehr::*;
import SpecFifo::*;
import HasSpecBits::*;
import Types::*;
import CacheUtils::*;
import ProcTypes::*;
import TlbTypes::*;
import DTlb::*;
import MemExePipeline::*;
(* synthesize *)
module mkTest(Empty);
    DTlbSynth dTlb <- mkDTlbSynth;
    let dTlbReqQ <- mkDTlbReqFifo;
    SpecFifo_SB_deq_enq_C_deq_enq#(ObjIdTranslationSlots,Bool) objIdTranslation <-
        mkSpecFifo_SB_deq_enq_C_deq_enq(True);
    SpecFifo_SB_deq_enq_C_deq_enq#(2,DTlbResp#(MemExeToFinish)) finishTranslationQ <-
        mkSpecFifo_SB_deq_enq_C_deq_enq(True);
    Vector#(TExp#(SizeOf#(LdStQTag)),Ehr#(2,Bool)) objIdLookupHits <- replicateM(mkEhr(True));
    Reg#(UInt#(16)) cycles <- mkReg(0);
    Reg#(UInt#(16)) admitted <- mkReg(0);
    Reg#(UInt#(16)) target <- mkReg(16);
    Reg#(UInt#(16)) completed <- mkReg(0);
    Reg#(UInt#(16)) metadataReplies <- mkReg(0);
    Reg#(UInt#(16)) lastAdmission <- mkReg(0);
    Reg#(Bool) havePrevious <- mkReg(False);
    Reg#(Bool) checkRate <- mkReg(False);
    Reg#(Bool) allowAdmit <- mkReg(False);
    Reg#(Bool) allowRetry <- mkReg(False);
    Reg#(SpecBits) activeMask <- mkReg(0);
    function Action check(Bool ok,String msg) = action
        if (!ok) begin $display("FAIL: %s",msg); $finish(1); end
    endaction;
    function Action setHits(Bool hit) = action
        for (Integer i=0;i<valueOf(TExp#(SizeOf#(LdStQTag)));i=i+1)
            objIdLookupHits[i][0] <= hit;
    endaction;
    rule watchdog;
        cycles <= cycles + 1;
        if (cycles == 2000) begin $display("FAIL: timeout"); $finish(1); end
    endrule
    // Same reservation + DTLB admission as production doExeMem. The producer
    // is always ready and every access may require a metadata translation.
    (* descending_urgency = "sendObjIdTranslation, admit" *)
    rule admit (allowAdmit && admitted < target);
        MemExeToFinish x=unpack(0);
        x.mem_func=Ld;
        x.ldstq_tag=tagged Ld 0;
        x.tmode=3;
        x.objIdAddr=Valid('h4000);
        x.inlineId=unpack(0);
        objIdTranslation.enq(ToSpecFifo {data:True,spec_bits:activeMask});
        dTlb.procReq(DTlbReq {inst:x,specBits:activeMask});
        if (checkRate && havePrevious)
            check(cycles == lastAdmission+1,"ObjID-hit stream has admission bubbles");
        lastAdmission <= cycles;
        havePrevious <= True;
        admitted <= admitted+1;
    endrule
"""+response+'\n'+retry+r"""
    rule finishData;
        finishTranslationQ.deq;
        completed <= completed+1;
    endrule
    rule finishMetadata (dTlb.procResp.inst.translateObjId);
        dTlb.deqProcResp;
        metadataReplies <= metadataReplies+1;
    endrule
    Stmt test=seq
        dTlb.updateVMInfo(unpack(0));
        delay(12);
        check(valueOf(ObjIdTranslationSlots)==3,"expected three reservations/retry slots");
        checkRate <= True;
        allowAdmit <= True;
        await(completed==16);
        allowAdmit <= False;
        check(!objIdTranslation.notEmpty && dTlb.noPendingReq,"hit stream leaked reservations");
        // Fill all reserved retry slots with genuine data-DTLB responses,
        // while deliberately preventing the metadata requests from issuing.
        setHits(False);
        checkRate <= False;
        target <= admitted+fromInteger(valueOf(ObjIdTranslationSlots));
        allowAdmit <= True;
        await(admitted==target);
        delay(8);
        check(!objIdTranslation.notFull && !dTlbReqQ.notFull,"retry storage/reservation capacities differ");
        check(dTlb.noPendingReq,"full retry queue prevented draining data responses");
        target <= admitted+1;
        delay(4);
        check(admitted==16+fromInteger(valueOf(ObjIdTranslationSlots)),"fourth potential miss admitted without retry credit");
        allowAdmit <= False;
        allowRetry <= True;
        await(metadataReplies==fromInteger(valueOf(ObjIdTranslationSlots)));
        await(!objIdTranslation.notEmpty && !dTlbReqQ.notEmpty && dTlb.noPendingReq);
        // Cancellation must release all three credits and discard all retries.
        allowRetry <= False;
        activeMask <= 1;
        target <= admitted+fromInteger(valueOf(ObjIdTranslationSlots));
        allowAdmit <= True;
        await(admitted==target);
        allowAdmit <= False;
        delay(8);
        check(!dTlbReqQ.notFull,"squash scenario did not fill retries");
        action
            objIdTranslation.specUpdate.incorrectSpeculation(False,0);
            dTlbReqQ.specUpdate.incorrectSpeculation(False,0);
            finishTranslationQ.specUpdate.incorrectSpeculation(False,0);
            dTlb.specUpdate.incorrectSpeculation(False,0);
        endaction
        delay(8);
        check(!objIdTranslation.notEmpty && !dTlbReqQ.notEmpty,"squash left live credits/retries");
        check(objIdTranslation.notFull && dTlbReqQ.notFull,"squash did not restore admission capacity");
        setHits(True);
        activeMask <= 0;
        havePrevious <= False;
        checkRate <= True;
        target <= admitted+16;
        allowAdmit <= True;
        await(completed==32);
        allowAdmit <= False;
        check(metadataReplies==fromInteger(valueOf(ObjIdTranslationSlots)),"squashed retries issued");
        check(!objIdTranslation.notEmpty && dTlb.noPendingReq,"post-squash hit stream leaked credit");
        $display("PASS: consecutive-cycle ObjID-hit admission, three retry slots, full-queue backpressure, draining, squash and reuse");
        $finish(0);
    endseq;
    mkAutoFSM(test);
endmodule
endpackage
"""
workspace=os.environ.get('TOOOBA_TRANSLATION_TEST_DIR')
with (contextlib.nullcontext(workspace) if workspace else tempfile.TemporaryDirectory(prefix='toooba-translation-credit-')) as temp:
    out=Path(temp);out.mkdir(parents=True,exist_ok=True)
    (out/'Test.bsv').write_text(code)
    ev=root/'libs/RISCV_HPM_Events'
    subprocess.run(['python3',str(ev/'parse_counters.py'),str(ev/'counters.yaml'),'-m','ProcTypes','-s',str(out/'StatCounters.bsv')],check=True)
    args=shlex.split(next(x for x in subprocess.check_output(['make','-n','compile_synth'],cwd=root/'src_SSITH_P3',text=True).splitlines() if x.startswith('bsc ')))[1:]
    flags=[]
    for i,x in enumerate(args[:-1]):
        if x in ('-D','-p'):flags.extend(args[i:i+2])
    flags+=['-check-assert','-aggressive-conditions','-show-schedule','-steps-max-intervals','10000000','-steps-warn-interval','1000000','+RTS','-K128M','-RTS','-p','+:'+str(out),'-bdir',str(out),'-simdir',str(out),'-info-dir',str(out)]
    subprocess.run(['bsc','-sim','-u','-g','mkTest',*flags,str(out/'Test.bsv')],cwd=root/'src_SSITH_P3',check=True)
    subprocess.run(['bsc','-sim','-e','mkTest',*flags,'-Xc++','-O1','-o',str(out/'test')],cwd=root/'src_SSITH_P3',check=True)
    result=subprocess.check_output([str(out/'test')],text=True,timeout=60)
    print(result,end='')
    assert 'PASS:' in result and 'FAIL:' not in result
