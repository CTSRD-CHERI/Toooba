// Copyright (c) 2017 Massachusetts Institute of Technology
//
//-
// RVFI_DII + CHERI modifications:
//     Copyright (c) 2020 Alexandre Joannou
//     Copyright (c) 2020 Peter Rugg
//     Copyright (c) 2020 Jonathan Woodruff
//     Copyright (c) 2021 Marno van der Maas
//     All rights reserved.
//
//     This software was developed by SRI International and the University of
//     Cambridge Computer Laboratory (Department of Computer Science and
//     Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
//     DARPA SSITH research programme.
//
//     This work was supported by NCSC programme grant 4212611/RFA 15971 ("SafeBet").
//-
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

`include "ProcConfig.bsv"

import Types::*;
import ProcTypes::*;
import Vector::*;
import CHERICap::*;
import CHERICC_Fat::*;
import ISA_Decls_CHERI::*;
import CacheUtils::*; // For CLoadTags alignment

(* noinline *)
function Maybe#(CSR_XCapCause) capChecksExec(CapPipe a, CapPipe b, CapPipe ddc, CapChecks toCheck, ImmData imm);
    function Maybe#(CSR_XCapCause) e1(CHERIException e)   = Valid(CSR_XCapCause{cheri_exc_reg: toCheck.rn1, cheri_exc_code: e});
    function Maybe#(CSR_XCapCause) e2(CHERIException e)   = Valid(CSR_XCapCause{cheri_exc_reg: toCheck.rn2, cheri_exc_code: e});
    function Maybe#(CSR_XCapCause) eDDC(CHERIException e) = Valid(CSR_XCapCause{cheri_exc_reg: {1'b1, pack(scrAddrDDC)}, cheri_exc_code: e});
    Maybe#(CSR_XCapCause) result = Invalid;
    if (toCheck.src1_tag                  && !isValidCap(a))
        result = e1(cheriExcTagViolation);
    else if (toCheck.src2_tag                  && !isValidCap(b))
        result = e2(cheriExcTagViolation);
    else if (toCheck.src1_unsealed_or_sentry   && isValidCap(a) && (getKind(a) != UNSEALED) && (getKind(a) != SENTRY))
        result = e1(cheriExcSealViolation);
    else if (toCheck.src1_unsealed_or_imm_zero && isValidCap(a) && (getKind(a) != UNSEALED) && (imm != 0))
        result = e1(cheriExcSealViolation);
    else if (toCheck.src1_sealed_with_type     && (getKind (a) matches tagged SEALED_WITH_TYPE .t ? False : True))
        result = e1(cheriExcSealViolation);
    else if (toCheck.src2_sealed_with_type     && (getKind (b) matches tagged SEALED_WITH_TYPE .t ? False : True))
        result = e2(cheriExcSealViolation);
    else if (toCheck.src1_type_not_reserved    && !validAsType(a, zeroExtend(getKind(a).SEALED_WITH_TYPE)))
        result = e1(cheriExcTypeViolation);
    else if (toCheck.src1_src2_types_match     && getKind(a).SEALED_WITH_TYPE != getKind(b).SEALED_WITH_TYPE)
        result = e1(cheriExcTypeViolation);
    else if (toCheck.src1_permit_ccall         && !getHardPerms(a).permitCCall)
        result = e1(cheriExcPermitCCallViolation);
    else if (toCheck.src2_permit_ccall         && !getHardPerms(b).permitCCall)
        result = e2(cheriExcPermitCCallViolation);
    else if (toCheck.src1_permit_x             && !getHardPerms(a).permitExecute)
        result = e1(cheriExcPermitXViolation);
    else if (toCheck.src2_no_permit_x          && getHardPerms(b).permitExecute)
        result = e2(cheriExcPermitXViolation);
    return result;
endfunction

(* noinline *)
function Maybe#(CSR_XCapCause) capChecksMem(CapPipe auth, CapPipe data, CapChecks toCheck, MemFunc mem_func, ByteOrTagEn byteOrTagEn);
    function Maybe#(CSR_XCapCause) eAuth(CHERIException e)   = Valid(CSR_XCapCause{cheri_exc_reg: case (toCheck.check_authority_src) matches Src1: toCheck.rn1;
                                                                                                                                       Ddc: {1'b1, pack(scrAddrDDC)};
                                                                                              endcase
                                                                             , cheri_exc_code: e});
    Maybe#(CSR_XCapCause) result = Invalid;
    match {.isLoad, .isStore} = case (mem_func)
        Ld, Lr: tuple2(True, False);
        St, Sc: tuple2(False, True);
        Amo:    tuple2(True, True);
    endcase;
    Bool storeValidCap = isStore && isValidCap(data) && byteOrTagEn == DataMemAccess(replicate(True));
    if      (!isValidCap(auth))
        result = eAuth(cheriExcTagViolation);
    else if (getKind(auth) != UNSEALED)
        result = eAuth(cheriExcSealViolation);
    else if (isLoad && !getHardPerms(auth).permitLoad)
        result = eAuth(cheriExcPermitRViolation);
    else if (isLoad && !getHardPerms(auth).permitLoadCap && byteOrTagEn == TagMemAccess)
        result = eAuth(cheriExcPermitRCapViolation);
    else if (isStore && !getHardPerms(auth).permitStore)
        result = eAuth(cheriExcPermitWViolation);
    else if (storeValidCap && !getHardPerms(auth).permitStoreCap)
        result = eAuth(cheriExcPermitWCapViolation);
    else if (storeValidCap && !getHardPerms(auth).permitStoreLocalCap && !getHardPerms(data).global)
        result = eAuth(cheriExcPermitWLocalCapViolation);
    return result;
endfunction

(* noinline *)
function Maybe#(BoundsCheck) prepareBoundsCheck(CapPipe a, CapPipe b, CapPipe pcc,
                                                CapPipe ddc, Data vaddr, Bit#(TAdd#(CacheUtils::LogCLineNumMemDataBytes,1)) size, // These two are only used in the memory pipe. May factor into two functions later.
                                                CapChecks toCheck);
    BoundsCheck ret = ?;
    CapPipe authority = ?;
    case(toCheck.check_authority_src)
        Src1: begin
            authority = a;
            ret.authority_idx = toCheck.rn1;
        end
        Src2: begin
            authority = b;
            ret.authority_idx = toCheck.rn2;
        end
        Pcc: begin
            authority = pcc;
            ret.authority_idx = {1'b1, pack(scrAddrPCC)};
        end
        Ddc: begin
            authority = ddc;
            ret.authority_idx = {1'b1, pack(scrAddrDDC)};
        end
    endcase
    ret.authority_base = getBase(authority);
    ret.authority_top = getTop(authority);

    case(toCheck.check_low_src)
        Src1Addr: ret.check_low = getAddr(a);
        Src1Base: ret.check_low = getBase(a);
        Src1Type: ret.check_low = zeroExtend(getKind(a).SEALED_WITH_TYPE);
        Src2Addr: ret.check_low = getAddr(b);
        Vaddr:    ret.check_low = vaddr;
    endcase

    case(toCheck.check_high_src)
        Src1AddrPlus2: ret.check_high = {1'b0,getAddr(a)+2};
        Src1Top: ret.check_high = getTop(a);
        Src1Type: ret.check_high = zeroExtend(getKind(a).SEALED_WITH_TYPE);
        Src2Addr: ret.check_high = {1'b0,getAddr(b)};
        ResultTop: ret.check_high = {1'b0,getAddr(a)} + {1'b0,getAddr(b)};
        VaddrPlusSize: ret.check_high = {1'b0,vaddr} + zeroExtend(size);
    endcase

    ret.check_inclusive = toCheck.check_inclusive;
    if (toCheck.check_enable) return Valid(ret);
    else                      return Invalid;
endfunction

(* noinline *)
function Data alu(Data a, Data b, AluFunc func);
    Data res = (case(func)
            Add     : (a + b);
            Addw    : signExtend((a + b)[31:0]);
            Sub     : (a - b);
            Subw    : signExtend((a[31:0] - b[31:0])[31:0]);
            And     : (a & b);
            Or      : (a | b);
            Xor     : (a ^ b);
            Slt     : zeroExtend( pack( signedLT(a, b) ) );
            Sltu    : zeroExtend( pack( a < b ) );
            Sll     : (a << b[5:0]);
            Sllw    : signExtend((a[31:0] << b[4:0])[31:0]);
            Srl     : (a >> b[5:0]);
            Sra     : signedShiftRight(a, b[5:0]);
            Srlw    : signExtend((a[31:0] >> b[4:0])[31:0]);
            Sraw    : signExtend(signedShiftRight(a[31:0], b[4:0])[31:0]);
            Csrw    : b;
            Csrs    : (a | b); // same as Or
            Csrc    : (a & ~b);
            default : 0;
        endcase);
    return res;
endfunction

(* noinline *)
function CapPipe setBoundsALU(CapPipe cap, Data len, SetBoundsFunc boundsOp);
    let combinedResult = setBoundsCombined(cap, len);
    CapPipe res = (case (boundsOp) matches
        SetBoundsRounding: combinedResult.cap;
        SetBoundsExact: combinedResult.cap;
        CRRL: nullWithAddr(combinedResult.length);
        CRAM: nullWithAddr(combinedResult.mask);
    endcase);
    if (!combinedResult.inBounds) res = setValidCap(res, False);
    if (boundsOp == SetBoundsExact && !combinedResult.exact) res = setValidCap(res, False);
    return res;
endfunction

(* noinline *)
function CapPipe specialRWALU(CapPipe cap, CapPipe oldCap, SpecialRWFunc scrType);
    function csrOp (oldAddr, val, f) =
        case (f)
            Write: val;
            Set: (oldAddr | val);
            Clear: (oldAddr & ~val);
        endcase;
    let addr = getAddr(cap);
    let oldAddr = getAddr(oldCap);
    CapPipe res = (case (scrType) matches
        tagged TVEC .csrf: update_scr_via_csr(oldCap, csrOp(oldAddr, getAddr(cap), csrf) & ~64'h2, False);
        tagged EPC .csrf: update_scr_via_csr(oldCap, csrOp(oldAddr, getAddr(cap), csrf) & ~64'h1, False);
        tagged TCC: update_scr_via_csr(cap, addr & ~64'h2, False); // Mask out bit 1
        tagged EPCC: update_scr_via_csr(cap, addr & ~64'h1, addr[0] == 1'b0); // Mask out bit 0
        tagged Normal: cap;
    endcase);
    return res;
endfunction

function Tuple2#(Data, Bool) extractType(CapPipe a);
    if      (getKind(a) == UNSEALED) return tuple2(otype_unsealed_ext, True);
    else if (getKind(a) == SENTRY  ) return tuple2(otype_sentry_ext, True);
    else if (getKind(a) == RES0    ) return tuple2(otype_res0_ext, True);
    else if (getKind(a) == RES1    ) return tuple2(otype_res1_ext, True);
    else return tuple2(zeroExtend(getKind(a).SEALED_WITH_TYPE), False);
endfunction

function CapPipe clearTagIf(CapPipe a, Bool cond);
    return setValidCap(a, isValidCap(a) && !cond);
endfunction

(* noinline *)
function CapPipe capModify(CapPipe a, CapPipe b, CapModifyFunc func);
    let a_mut = setValidCap(a, isValidCap(a) && getKind(a) == UNSEALED);
    let b_mut = setValidCap(b, isValidCap(b) && getKind(b) == UNSEALED);
    match {.a_type, .a_res} = extractType(a);
    Bool sealPassthrough = !isValidCap(b) || getKind(a) != UNSEALED || !isInBounds(b, False) || getAddr(b) == otype_unsealed_ext;
    Bool sealIllegal = getKind(b) != UNSEALED || !getHardPerms(b).permitSeal || !validAsType(b, getAddr(b));
    let new_hard_perms = getHardPerms(a);
    new_hard_perms.global = new_hard_perms.global && getHardPerms(b).global;
    Bool unsealIllegal = !isValidCap(b) || getKind(a) != UNSEALED || getKind(b) == UNSEALED || a_res || getAddr(b) != a_type || !getHardPerms(b).permitUnseal || !isInBounds(b, False);
    Bool buildCapIllegal = !isValidCap(b) || getKind(b) != UNSEALED || !isDerivable(a) || (getPerms(a) & getPerms(b)) != getPerms(a) || getBase(a) < getBase(b) || getTop(a) > getTop(b); // XXX needs optimisation
    CapPipe res = (case(func) matches
            tagged ModifyOffset .offsetOp :
                modifyOffset(a_mut, getAddr(b), offsetOp == IncOffset).value;
            tagged SetBounds .boundsOp    :
                setBoundsALU(a_mut, getAddr(b), boundsOp);
            tagged SpecialRW .scrType     :
                case (scrType) matches
                      tagged TCC: b;
                      tagged EPCC: b;
                      tagged Normal: b;
                      tagged TVEC ._: nullWithAddr(getAddr(b));
                      tagged EPC ._: nullWithAddr(getAddr(b));
                   endcase
            tagged SetAddr .addrSource    :
                clearTagIf(setAddr(b_mut, (addrSource == Src1Type) ? a_type : getAddr(a) ).value, (addrSource == Src1Type) ? a_res : False);
            tagged SealEntry              :
                setKind(a_mut, SENTRY);
            tagged Seal                   :
                clearTagIf( setKind(a_mut, SEALED_WITH_TYPE (truncate(getAddr(b))))
                          , sealPassthrough || sealIllegal);
            tagged CSeal                  :
                (sealPassthrough ? a :
                     clearTagIf(setKind(a_mut, SEALED_WITH_TYPE (truncate(getAddr(b)))), sealIllegal));
            tagged Unseal .src            :
                clearTagIf(setHardPerms(setKind(((src == Src1) ? a:b), UNSEALED), new_hard_perms), (src == Src1) && unsealIllegal);
            tagged AndPerm                :
                setPerms(a_mut, pack(getPerms(a)) & truncate(getAddr(b)));
            tagged SetFlags               :
                setFlags(a_mut, truncate(getAddr(b)));
            tagged FromPtr                :
                (getAddr(a) == 0 ? nullCap : setAddr(b_mut, getAddr(a)).value);
            tagged SetHigh:
                fromMem(tuple2(False, {getAddr(b), getAddr(a)}));
            tagged BuildCap               :
                setKind(setValidCap(a_mut, !buildCapIllegal), getKind(a)==SENTRY ? SENTRY : UNSEALED);
            tagged Move                   :
                a;
            tagged ClearTag               :
                setValidCap(a, False);
            default: ?;
        endcase);
    return res;
endfunction

(* noinline *)
function Data capInspect(CapPipe a, CapPipe b, CapInspectFunc func);
    Data res = (case(func) matches
               tagged TestSubset             :
                   // TODO will be bad for timing. Would like to reuse bounds check
                   zeroExtend(pack(   (isValidCap(b) == isValidCap(a))
                                   && ((getPerms(a) & getPerms(b)) == getPerms(a))
                                   && (getBase(a) >= getBase(b))
                                   && (getTop(a) <= getTop(b))));
               tagged SetEqualExact          :
                   zeroExtend(pack(toMem(a) == toMem(b)));
               tagged GetLen                 :
                   truncate(getLength(a));
               tagged GetBase                :
                   getBase(a);
               tagged GetTag                 :
                   zeroExtend(pack(isValidCap(a)));
               tagged GetSealed              :
                   zeroExtend(pack(getKind(a) != UNSEALED));
               tagged GetAddr                :
                   getAddr(a);
               tagged GetOffset              :
                   getOffset(a);
               tagged GetFlags               :
                   zeroExtend(getFlags(a));
               tagged GetPerm                :
                   zeroExtend(getPerms(a));
               tagged GetHigh                :
                   zeroExtend(tpl_2(toMem(a))[127:64]);
               tagged GetType                :
                   tpl_1(extractType(a));
               tagged ToPtr                  :
                   (isValidCap(a) ? getAddr(a) - getBase(b) : 0);
               default: ?;
        endcase);
    return res;
endfunction

function CapPipe capALU(CapPipe a, CapPipe b, CapFunc func);
    CapPipe res = (case (func) matches
        tagged CapInspect .x:
            nullWithAddr(capInspect(a,b,func.CapInspect));
        default:
            capModify(a,b,func.CapModify);
    endcase);
    return res;
endfunction

(* noinline *)
function Bool aluBr(Data a, Data b, BrFunc brFunc);
    Bool brTaken = (case(brFunc)
            Eq      : (a == b);
            Neq     : (a != b);
            Lt      : signedLT(a, b);
            Ltu     : (a < b);
            Ge      : signedGE(a, b);
            Geu     : (a >= b);
            AT      : True;
            NT      : False;
            default : False;
        endcase);
    return brTaken;
endfunction

(* noinline *)
function CapPipe brAddrCalc(CapPipe pc, CapPipe val, IType iType, Data imm, Bool taken, Bit #(32) orig_inst, Bool cap);
    CapPipe pcPlusN = addPc(pc, ((orig_inst [1:0] == 2'b11) ? 4 : 2));

    //if (!cap) val = setOffset(pc, getAddr(val)).value;
    //CapPipe branchTarget = incOffset(pc, imm).value;
    //CapPipe jumpTarget = incOffset(val, imm).value;

    CapPipe nextPc = pc;
    Data offset = imm;
    Bool doInc = True;
    if (iType==Jr || iType==CCall || iType ==CJALR) begin
        if (cap) nextPc = val;
        else begin
          offset = getAddr(val) + imm;
          doInc = False;
        end
    end
    CapPipe targetAddr = ?;
    if(doInc) targetAddr = modifyOffset(nextPc, offset, doInc).value;
    else targetAddr = setAddr(nextPc, offset).value;
    // jumpTarget.address[0] = 1'b0;
    targetAddr = setAddrUnsafe(targetAddr, {truncateLSB(getAddr(targetAddr)), 1'b0});
    targetAddr = setKind(targetAddr, UNSEALED); // It is checked elsewhere that we have an unsealed cap already, or sentry if permitted

    return (case (iType)
            J, CJAL, Jr, CCall, CJALR: targetAddr;
            Br      : (taken ? targetAddr : pcPlusN);
            default : pcPlusN;
        endcase);
endfunction
/*
(* noinline *)
function ControlFlow getControlFlow(DecodedInst dInst, Data rVal1, Data rVal2, Addr pc, Addr ppc, Bit #(32) orig_inst);
    ControlFlow cf = unpack(0);

    Bool taken = dInst.execFunc matches tagged Br .br_f ? aluBr(rVal1, rVal2, br_f) : False;
    Addr nextPc = brAddrCalc(pc, rVal1, dInst.iType, validValue(getDInstImm(dInst)), taken, orig_inst);
    Bool mispredict = nextPc != ppc;

    cf.pc = pc;
    cf.nextPc = nextPc;
    cf.taken = taken;
    cf.mispredict = mispredict;

    return cf;
endfunction
*/
(* noinline *)
function ExecResult basicExec(DecodedInst dInst, CapPipe rVal1, CapPipe rVal2, CapPipe pcc, CapPipe ppc, Bit #(32) orig_inst);
    // just data, addr, and control flow
    CapPipe data = nullCap;
    CapPipe addr = nullCap;

    Bool newPcc = dInst.iType == CJALR || dInst.iType == CCall;
    ControlFlow cf = ControlFlow{pc: pcc, nextPc: nullCap, taken: False, newPcc: newPcc, mispredict: False};

    Maybe#(CapPipe) capImm = isValid(getDInstImm(dInst)) ? Valid (nullWithAddr(getDInstImm(dInst).Valid)) : Invalid;
    let aluVal2 = dInst.capFunc matches tagged CapModify .cm &&& cm matches tagged SpecialRW ._ ? rVal2 : fromMaybe(rVal2, capImm);
    // Get the alu function. By default, it adds. This is used by memory instructions
    AluFunc alu_f = dInst.execFunc matches tagged Alu .alu_f ? alu_f : Add;
    Data alu_result = alu(getAddr(rVal1), getAddr(aluVal2), alu_f);

    CapPipe cap_alu_result = capALU(rVal1, aluVal2, dInst.capFunc);
    CapPipe link_pcc = addPc(pcc, ((orig_inst [1:0] == 2'b11) ? 4 : 2));

    // Default branch function is not taken
    BrFunc br_f = dInst.execFunc matches tagged Br .br_f ? br_f : NT;
    cf.taken = aluBr(getAddr(rVal1), getAddr(rVal2), br_f);
    cf.nextPc = brAddrCalc(pcc, rVal1, dInst.iType, fromMaybe(0,getDInstImm(dInst)), cf.taken, orig_inst, newPcc);

    Maybe#(CSR_XCapCause) capException = capChecksExec(rVal1, aluVal2, nullCap, dInst.capChecks, dInst.imm.Valid);
    if (dInst.execFunc matches tagged Br .unused) begin
        rVal1 = cf.nextPc;
        if (!cf.taken) dInst.capChecks.check_enable = False;
    end
    Maybe#(BoundsCheck) boundsCheck = prepareBoundsCheck(rVal1, aluVal2, pcc,
                                                         nullCap, 0, 0, // These three are only used in the memory pipe
                                                         dInst.capChecks);

    cf.nextPc = setKind(cf.nextPc, UNSEALED);
    cf.mispredict = cf.nextPc != ppc;

    data = (case (dInst.iType)
            St          : rVal2;
            Sc          : rVal2;
            Amo         : rVal2;
            J           : nullWithAddr(getAddr(link_pcc));
            CJAL        : setKind(link_pcc, SENTRY);
            CCall       : cap_alu_result;
            CJALR       : setKind(link_pcc, SENTRY);
            Jr          : nullWithAddr(getAddr(link_pcc));
            Auipc       : nullWithAddr(getAddr(pcc) + getDInstImm(dInst).Valid);
            Auipcc      : incOffset(pcc, getDInstImm(dInst).Valid).value; // could be computed with alu
            Csr         : rVal1;
            Scr         : cap_alu_result;
            Cap         : cap_alu_result;
            default     : nullWithAddr(alu_result);
        endcase);
    CapMem csr_data = (case (dInst.iType)
                       Scr: cast(specialRWALU(fromMaybe(rVal1, capImm), rVal2, dInst.capFunc.CapModify.SpecialRW));
                       default: nullWithAddr(alu_result);
                    endcase);
    addr = (case (dInst.iType)
            Ld, St, Lr, Sc, Amo : nullWithAddr(alu_result);
            default             : cf.nextPc; //TODO should this be nullified?
        endcase);

    return ExecResult{data: data, csrData: csr_data, addr: addr, controlFlow: cf, capException: capException, boundsCheck: boundsCheck};
endfunction

(* noinline *)
function Maybe#(Trap) checkForException(
    DecodedInst dInst,
    ArchRegs regs,
    CsrDecodeInfo csrState,
    CapMem pcc,
    Bool fourByteInst
); // regs needed to check if x0 is a src
    Maybe#(Trap) exception = Invalid;
    let prv = csrState.prv;

    if(dInst.iType == Ecall) begin
        exception = Valid (Exception (case(prv)
            prvU: excEnvCallU;
            prvS: excEnvCallS;
            prvM: excEnvCallM;
            default: excIllegalInst;
        endcase));
    end
    else if(dInst.iType == Ebreak) begin
        exception = Valid (Exception (excBreakpoint));
    end
    else if(dInst.iType == Mret) begin
        if(prv < prvM) begin
            exception = Valid (Exception (excIllegalInst));
        end
        else if (!getHardPerms(pcc).accessSysRegs) begin
            exception = Valid (CapException (CSR_XCapCause {cheri_exc_reg: {1'b1, pack(scrAddrPCC)}, cheri_exc_code: cheriExcPermitASRViolation}));
        end
    end
    else if(dInst.iType == Sret) begin
        if(prv < prvS) begin
            exception = Valid (Exception (excIllegalInst));
        end
        else if(prv == prvS && csrState.trapSret) begin
            exception = Valid (Exception (excIllegalInst));
        end
        else if (!getHardPerms(pcc).accessSysRegs) begin
            exception = Valid (CapException (CSR_XCapCause {cheri_exc_reg: {1'b1, pack(scrAddrPCC)}, cheri_exc_code: cheriExcPermitASRViolation}));
        end
    end
    else if(dInst.iType == SFence) begin
        if(prv == prvS && csrState.trapVM) begin
            exception = Valid (Exception (excIllegalInst));
        end
    end
    else if(dInst.iType == Csr) begin
        let csr = pack(fromMaybe(csrAddrNone, dInst.csr));
        Bool csr_has_priv = (prv >= csr[9:8]);
        if(!csr_has_priv) begin
            exception = Valid (Exception (excIllegalInst));
        end
        else if(prv == prvS && csrState.trapVM &&
                validValue(dInst.csr) == csrAddrSATP) begin
            exception = Valid (Exception (excIllegalInst));
        end
        let rs1 = case (regs.src2) matches
                     tagged Valid (tagged Gpr .r) : r;
                     default: 0;
                  endcase;
        let imm = case (dInst.imm) matches
                     tagged Valid .n: n;
                     default: 0;
                  endcase;
        Bool writes_csr = ((dInst.execFunc == tagged Alu Csrw) || (rs1 != 0) || (imm != 0));
        Bool read_only  = (csr [11:10] == 2'b11);
        Bool write_deny = (writes_csr && read_only);
        Bool asr_allow = getHardPerms(pcc).accessSysRegs
                      || ((pack(csrAddrHPMCOUNTER3) <= csr) && (csr <= pack(csrAddrHPMCOUNTER31)) && !writes_csr)
                      || (csr == pack(csrAddrFFLAGS))
                      || (csr == pack(csrAddrFRM))
                      || (csr == pack(csrAddrFCSR))
                      || (csr == pack(csrAddrCYCLE) && !writes_csr)
                      || (csr == pack(csrAddrTIME) && !writes_csr)
                      || (csr == pack(csrAddrINSTRET) && !writes_csr);
        Bool unimplemented = (csr == pack(csrAddrNone));    // Added by Bluespec
        if (write_deny || !csr_has_priv || unimplemented) begin
            exception = Valid (Exception (excIllegalInst));
        end else if (!asr_allow) begin
            exception = Valid (CapException (CSR_XCapCause {cheri_exc_reg: {1'b1, pack(scrAddrPCC)}, cheri_exc_code: cheriExcPermitASRViolation}));
        end
    end
    else if(dInst.scr matches tagged Valid .scr) begin
        Bool scr_has_priv = (prv >= pack(scr)[4:3]);
        Bool unimplemented = (scr == scrAddrNone);
        Bool writes_scr = regs.src1 == Valid (tagged Gpr 0) ? False : True;
        Bool read_only  = (scr == scrAddrPCC);
        Bool write_deny = (writes_scr && read_only);
        Bool asr_allow = getHardPerms(pcc).accessSysRegs ||
          scr == scrAddrDDC || scr == scrAddrPCC;
        if(!scr_has_priv || unimplemented || write_deny) begin
            exception = Valid (Exception (excIllegalInst));
        end else if (!asr_allow) begin
            exception = Valid (CapException (CSR_XCapCause {cheri_exc_reg: {1'b1, pack(scrAddrPCC)}, cheri_exc_code: cheriExcPermitASRViolation}));
        end
    end
    else if(dInst.iType == Fpu) begin
        if(dInst.execFunc matches tagged Fpu .fpu_f) begin
            // Get rounding mode
            let rm = (fpu_f.rm == rmRDyn) ? unpack(csrState.frm) : fpu_f.rm;
            case(rm)
                rmRNE, rmRTZ, rmRDN, rmRUP, rmRMM: exception = exception; // legal modes
                default                          : exception = Valid (Exception (excIllegalInst));
            endcase
        end
        else begin
            // Fpu instruction without FPU execFunc
            exception = Valid (Exception (excIllegalInst));
        end
    end

    // Check that the end of the instruction is in bounds of PCC.
    CapPipe pcc_end = cast(addPc(pcc, (fourByteInst?4:2)));
    CapPipe pcc_start = cast(pcc);
    Maybe#(CSR_XCapCause) capException = Invalid;
    if (!isValidCap(pcc_start)) capException = Valid(CSR_XCapCause{cheri_exc_reg: {1'b1,pack(scrAddrPCC)}, cheri_exc_code: cheriExcTagViolation});
    if (getKind(pcc_start) != UNSEALED) capException = Valid(CSR_XCapCause{cheri_exc_reg: {1'b1,pack(scrAddrPCC)}, cheri_exc_code: cheriExcSealViolation});
    if (!getHardPerms(pcc_start).permitExecute) capException = Valid(CSR_XCapCause{cheri_exc_reg: {1'b1,pack(scrAddrPCC)}, cheri_exc_code: cheriExcPermitXViolation});
    if (!isInBounds(pcc_end, True)) capException = Valid(CSR_XCapCause{cheri_exc_reg: {1'b1,pack(scrAddrPCC)}, cheri_exc_code: cheriExcLengthViolation});
    if (!isInBounds(pcc_start, True)) capException = Valid(CSR_XCapCause{cheri_exc_reg: {1'b1,pack(scrAddrPCC)}, cheri_exc_code: cheriExcLengthViolation});

    Maybe#(Trap) retval = Invalid;
    if (capException matches tagged Valid .ce) retval = Valid(CapException(ce));
    else retval = exception;

    return retval;
endfunction

// check mem access misaligned: byteEn is unshifted (just from Decode)
function Bool memAddrMisaligned(Addr addr, ByteOrTagEn byteOrTagEn);
    MemDataByteEn byteEn = byteOrTagEn.DataMemAccess;
    if (byteOrTagEn == TagMemAccess) begin
        return(!isCLineAlignAddr(addr));
    end
    else if(byteEn[15]) begin
        return addr[3:0] != 0;
    end
    else if(byteEn[7]) begin
        return addr[2:0] != 0;
    end
    else if(byteEn[3]) begin
        return addr[1:0] != 0;
    end
    else if(byteEn[1]) begin
        return addr[0] != 0;
    end
    else begin
        return False;
    end
endfunction

function MemTaggedData gatherLoad( Addr addr, ByteOrTagEn byteOrTagEn
                                 , Bool unsignedLd, MemTaggedData data);
    function extend = unsignedLd ? zeroExtend : signExtend;
    Bit#(IndxShamt) offset = truncate(addr);

    MemDataByteEn byteEn = byteOrTagEn.DataMemAccess;
    if((byteOrTagEn == TagMemAccess) || pack(byteEn) == ~0) return data;
    else if(byteEn[7]) begin
        Vector#(2, Bit#(64)) dataVec = unpack(pack(data.data));
        return dataToMemTaggedData(extend(dataVec[offset[3]]));
    end else if(byteEn[3]) begin
        Vector#(4, Bit#(32)) dataVec = unpack(pack(data.data));
        return dataToMemTaggedData(extend(dataVec[offset[3:2]]));
    end else if(byteEn[1]) begin
        Vector#(8, Bit#(16)) dataVec = unpack(pack(data.data));
        return dataToMemTaggedData(extend(dataVec[offset[3:1]]));
    end else begin
        Vector#(16, Bit#(8)) dataVec = unpack(pack(data.data));
        return dataToMemTaggedData(extend(dataVec[offset]));
    end
endfunction

function Tuple2#(ByteEn, Data) scatterStore(Addr addr, ByteEn byteEn, Data data);
    Bit#(IndxShamt) offset = truncate(addr);
    if(byteEn[7]) begin
        return tuple2(byteEn, data);
    end else if(byteEn[3]) begin
        return tuple2(unpack(pack(byteEn) << (offset)), data << {(offset), 3'b0});
    end else if(byteEn[1]) begin
        return tuple2(unpack(pack(byteEn) << (offset)), data << {(offset), 3'b0});
    end else begin
        return tuple2(unpack(pack(byteEn) << (offset)), data << {(offset), 3'b0});
    end
endfunction
