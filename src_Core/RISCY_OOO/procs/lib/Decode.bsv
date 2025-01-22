
// Copyright (c) 2017 Massachusetts Institute of Technology
//
//-
// RVFI_DII + CHERI modifications:
//     Copyright (c) 2020 Alexandre Joannou
//     Copyright (c) 2020 Peter Rugg
//     Copyright (c) 2020 Jonathan Woodruff
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
import MemoryTypes::*;
import Vector::*;
import DefaultValue::*;
import ISA_Decls_CHERI::*;

Bit#(3) memWU   = 3'b110;

// Smaller decode functions
function Maybe#(MemInst) decodeMemInst(Instruction inst, Bool cap_mode, RiscVISASubset isa);
    Bool illegalInst = False;
    Opcode opcode = unpackOpcode(inst[6:0]);
    let funct5 = inst[31:27];
    let funct3 = inst[14:12];

    // mem_func + amo_func
    MemFunc mem_func = Ld;
    AmoFunc amo_func = None;
    if (opcode == opcLoad || opcode == opcLoadFp || opcode == opcMiscMem) begin
        mem_func = Ld;
    end else if (opcode == opcStore || opcode == opcStoreFp) begin
        mem_func = St;
    end else if (opcode == opcAmo) begin
        case (funct5)
            fnLR       : mem_func = Lr;
            fnSC       : mem_func = Sc;
            fnAMOSWAP,
            fnAMOADD,
            fnAMOXOR,
            fnAMOAND,
            fnAMOOR,
            fnAMOMIN,
            fnAMOMAX,
            fnAMOMINU,
            fnAMOMAXU  : mem_func = Amo;
            default    : illegalInst = True;
        endcase
        // now for amo_func
        case (funct5)
            fnAMOSWAP : amo_func = Swap;
            fnAMOADD  : amo_func = Add;
            fnAMOXOR  : amo_func = Xor;
            fnAMOAND  : amo_func = And;
            fnAMOOR   : amo_func = Or;
            fnAMOMIN  : amo_func = Min;
            fnAMOMAX  : amo_func = Max;
            fnAMOMINU : amo_func = Minu;
            fnAMOMAXU : amo_func = Maxu;
        endcase
    end else begin
        illegalInst = True;
    end

    Bool capWidth = (mem_func != Ld && funct3 == f3_SQ)
                 || (opcode   == opcMiscMem && funct3 == f3_LQ);

    Bool illegalFP =    (opcode == opcStoreFp || opcode == opcLoadFp)
                     && !(   (funct3 == memW && isa.f)
                          || (funct3 == memD && isa.d));

    if (illegalFP) begin
        illegalInst = True;
    end

    if (capWidth && amo_func != None && amo_func != Swap) begin
        illegalInst = True; // Don't support atomic cap arithmetic
    end

    // unsignedLd
    // it doesn't matter if this is set to True for stores
    Bool unsignedLd = False;
    case (funct3)
        memB, memH, memW, memD:
            unsignedLd = False;
        memBU, memHU, memWU:
            unsignedLd = True;
        default:
            illegalInst = True;
    endcase
    // This is a minor fix to make our processor's results match spike since
    // they don't sign extend when loading single precision values from memory
    if (opcode == opcLoadFp) begin
        unsignedLd = True;
    end

    // byteEn
    // TODO: Some combinations of operations and byteEn's are illegal.
    // They should be detected here.
    MemDataByteEn byteEn = (capWidth) ? replicate(True):replicate(False);
    if (!capWidth) begin
        case (funct3)
            memB, memBU : byteEn[0] = True;
            memH, memHU : begin
                              byteEn[0] = True;
                              byteEn[1] = True;
                          end
            memW, memWU : begin
                              byteEn[0] = True;
                              byteEn[1] = True;
                              byteEn[2] = True;
                              byteEn[3] = True;
                          end
            memD        : begin
                              byteEn[0] = True;
                              byteEn[1] = True;
                              byteEn[2] = True;
                              byteEn[3] = True;
                              byteEn[4] = True;
                              byteEn[5] = True;
                              byteEn[6] = True;
                              byteEn[7] = True;
                          end
            default     : illegalInst = True;
        endcase
    end

    // aq + rl
    Bool aq = False;
    Bool rl = False;
    if (opcode == opcAmo) begin
        // aq and rl are only defined for Amo operations
        aq = unpack(inst[ 26 ]);
        rl = unpack(inst[ 25 ]);
    end

    if (illegalInst) begin
        return tagged Invalid;
    end else begin
        return tagged Valid ( MemInst{
                                mem_func: mem_func,
                                amo_func: amo_func,
                                unsignedLd: unsignedLd,
                                byteOrTagEn: DataMemAccess(byteEn),
                                aq: aq,
                                rl: rl,
                                reg_bounds: cap_mode } );
    end
endfunction

function Maybe#(MemInst) decodeExplicitBoundsMemInst(Instruction inst);
    // This function trusts that its result will only be used by
    // explicit capability instructions as identified by the primary
    // decode case, and therefore does not attempt to return sensible
    // defaults when the instruction is not a capability memory operation.
    Bool illegalInst = False;
    Bit#(7) funct7 = inst[31:25];
    Bit#(5) mem_code = (funct7==f7_cap_Loads) ? inst[24:20]:inst[11:7];
    Bool amo = unpack(mem_code[4]);
    Bool bounds_from_register = unpack(mem_code[3]);
    // unsignedLd
    // it doesn't matter if this is set to True for stores
    Bool unsignedLd = unpack(mem_code[2]);
    Bit#(2) width = mem_code[1:0];

    Bool capWidth = False;
    if (funct7 == f7_cap_Stores && unsignedLd) begin
        capWidth = True;
        if (width != 0) illegalInst = True;
    end
    if (funct7 == f7_cap_Loads && amo && unsignedLd) begin
        unsignedLd = False;
        capWidth = True;
        case (width)
            0 : amo = amo; // Don't do anything in this case.
            3 : amo = False;
            default : illegalInst = True;
        endcase
    end

    // mem_func + amo_func
    MemFunc mem_func = Ld;
    AmoFunc amo_func = None;
    if (funct7 == f7_cap_Loads) begin
        mem_func = (amo) ? Lr:Ld;
    end else if (funct7 == f7_cap_Stores) begin
        mem_func = (amo) ? Sc:St;
    end

    // byteEn
    MemDataByteEn byteEn = (capWidth) ? replicate(True):replicate(False);
    if (!capWidth) begin
        case (width)
            0 : byteEn[0] = True;
            1 :   begin
                      byteEn[0] = True;
                      byteEn[1] = True;
                  end
            2 :   begin
                      byteEn[0] = True;
                      byteEn[1] = True;
                      byteEn[2] = True;
                      byteEn[3] = True;
                  end
            3 :   begin
                      byteEn[0] = True;
                      byteEn[1] = True;
                      byteEn[2] = True;
                      byteEn[3] = True;
                      byteEn[4] = True;
                      byteEn[5] = True;
                      byteEn[6] = True;
                      byteEn[7] = True;
                      // In RV64 we don't allow unsigned double operations!
                      if (unsignedLd) illegalInst = True;
                  end
        endcase
    end

    if (illegalInst) begin
        return tagged Invalid;
    end else begin
        return tagged Valid ( MemInst{
                                mem_func: mem_func,
                                amo_func: amo_func,
                                unsignedLd: unsignedLd,
                                byteOrTagEn: DataMemAccess(byteEn),
                                aq: amo,
                                rl: amo,
                                reg_bounds: bounds_from_register} );
    end
endfunction

function CapChecks memCapChecks(Bool cap_mode);
    CapChecks capChecks = unpack(0);
    capChecks.check_enable = True;
    capChecks.check_low_src = Vaddr;
    capChecks.check_high_src = VaddrPlusSize; // Should add the access size somehow...
    capChecks.check_inclusive = True;
    if (cap_mode) begin
        capChecks.check_authority_src = Src1;
    end else begin
        capChecks.check_authority_src = Ddc;
    end
    return capChecks;
endfunction

(* noinline *)
function DecodeResult decode(Instruction inst, Bool cap_mode);
    RiscVISASubset isa = defaultValue;

    // initialize dInst with default values
    DecodedInst dInst = DecodedInst {
        iType: Unsupported,
        execFunc: tagged Other,
        capFunc: tagged Other,
        csr: tagged Invalid,
        scr: tagged Invalid,
        imm: tagged Invalid,
        capChecks: unpack(0)
    };
    ArchRegs regs = ArchRegs {
        src1: tagged Invalid,
        src2: tagged Invalid,
        src3: tagged Invalid,
        dst: tagged Invalid
    };
    Bool legalInst = False;

    Opcode opcode = unpackOpcode(inst[  6 :  0 ]);
    let rd        =              inst[ 11 :  7 ];
    let funct3    =              inst[ 14 : 12 ];
    let rs1       =              inst[ 19 : 15 ];
    let rs2       =              inst[ 24 : 20 ];
    let funct7    =              inst[ 31 : 25 ];
    // For "F" and "D" ISA extensions
    let funct5    =              inst[ 31 : 27 ];
    let fmt       =              inst[ 26 : 25 ];
    let rs3       =              inst[ 31 : 27 ];
    let funct2    =              inst[ 26 : 25 ];
    // For "A" ISA extension
    Bool aq       =       unpack(inst[ 26 ]);
    Bool rl       =       unpack(inst[ 25 ]);
    // For "xCHERI" ISA extension
    let funct5rs2 =              inst[ 24 : 20 ];

    // For floating point instructions: is the fmt field in the current isa
    Bool fpFmtInISA = (isa.f && fmt == fmtS) || (isa.d && fmt == fmtD);

    ImmData immI  = signExtend(inst[31:20]);
    ImmData immS  = signExtend({ inst[31:25], inst[11:7] });
    ImmData immB  = signExtend({ inst[31], inst[7], inst[30:25], inst[11:8], 1'b0});
    ImmData immU  = signExtend({ inst[31:12], 12'b0 });
    ImmData immJ  = signExtend({ inst[31], inst[19:12], inst[20], inst[30:21], 1'b0});
    ImmData immIunsigned = zeroExtend(inst[31:20]);

    // Results of mini-decoders
    Maybe#(MemInst) mem_inst = decodeMemInst(inst, cap_mode, isa);
    Maybe#(MemInst) exp_bnds_mem_inst = decodeExplicitBoundsMemInst(inst);

    case (opcode)
        opcOpImm: begin
            dInst.iType = Alu;
            Maybe#(AluFunc) mAluFunc = case (funct3)
                fnADD: Valid(Add);
                fnSLT: Valid(Slt);
                fnSLTU: Valid(Sltu);
                fnAND: Valid(And);
                fnOR: Valid(Or);
                fnXOR: Valid(Xor);
                fnSLL: Valid(Sll);
                fnSR: Valid(immI[10] == 0 ? Srl : Sra);
                default: Invalid;
            endcase;
            legalInst = isValid(mAluFunc);
            dInst.execFunc = tagged Alu mAluFunc.Valid;
            regs.dst  = Valid(tagged Gpr rd);
            regs.src1 = Valid(tagged Gpr rs1);
            regs.src2 = Invalid;
            dInst.imm = Valid(immI);
            dInst.csr = tagged Invalid;
        end

        opcOpImm32: begin
            dInst.iType = Alu;
            Maybe#(AluFunc) mAluFunc = case (funct3)
                fnADD: Valid(Addw);
                fnSLL: Valid(Sllw);
                fnSR: Valid(immI[10] == 0 ? Srlw : Sraw);
                default: Invalid;
            endcase;
            legalInst = isValid(mAluFunc);
            dInst.execFunc = tagged Alu mAluFunc.Valid;
            regs.dst  = Valid(tagged Gpr rd);
            regs.src1 = Valid(tagged Gpr rs1);
            regs.src2 = Invalid;
            dInst.imm = Valid(immI);
            dInst.csr = tagged Invalid;
        end

        opcOp: begin
            dInst.iType = Alu;
            regs.dst  = Valid(tagged Gpr rd);
            regs.src1 = Valid(tagged Gpr rs1);
            regs.src2 = Valid(tagged Gpr rs2);
            dInst.imm = Invalid;
            dInst.csr = tagged Invalid;
            case (funct7)
                opALU1: begin
                    Maybe#(AluFunc) mAluFunc = case(funct3)
                        fnADD: Valid(Add);
                        fnSLT: Valid(Slt);
                        fnSLTU: Valid(Sltu);
                        fnAND: Valid(And);
                        fnOR: Valid(Or);
                        fnXOR: Valid(Xor);
                        fnSLL: Valid(Sll);
                        fnSR: Valid(Srl);
                        default: Invalid;
                    endcase;
                    legalInst = isValid(mAluFunc);
                    dInst.execFunc = tagged Alu mAluFunc.Valid;
                end
                opALU2: begin
                    Maybe#(AluFunc) mAluFunc = case (funct3)
                        fnADD: Valid(Sub);
                        fnSR: Valid(Sra);
                        default: Invalid;
                    endcase;
                    legalInst = isValid(mAluFunc);
                    dInst.execFunc = tagged Alu mAluFunc.Valid;
                end
                opMULDIV: begin
                    if (isa.m) begin
                        // Processor includes "M" extension
                        Maybe#(MulDivFunc) mFunc = case(funct3)
                            fnMUL    : Valid(Mul);
                            fnMULH   : Valid(Mulh);
                            fnMULHSU : Valid(Mulh);
                            fnMULHU  : Valid(Mulh);
                            fnDIV    : Valid(Div);
                            fnDIVU   : Valid(Div);
                            fnREM    : Valid(Rem);
                            fnREMU   : Valid(Rem);
                            default  : Invalid;
                        endcase;
                        Bool w = False;
                        MulDivSign sign = case(funct3)
                            fnMUL    : Signed;
                            fnMULH   : Signed;
                            fnMULHSU : SignedUnsigned;
                            fnMULHU  : Unsigned;
                            fnDIV    : Signed;
                            fnDIVU   : Unsigned;
                            fnREM    : Signed;
                            fnREMU   : Unsigned;
                        endcase;
                        legalInst = isValid(mFunc);
                        dInst.execFunc = tagged MulDiv (MulDivInst {
                            func: mFunc.Valid, w: w, sign: sign
                        });
                    end
                end
            endcase
        end

        opcOp32: begin
            dInst.iType = Alu;
            case (funct7)
                opALU1: begin
                    Maybe#(AluFunc) mAluFunc = case(funct3)
                        fnADD: Valid(Addw);
                        fnSLL: Valid(Sllw);
                        fnSR: Valid(Srlw);
                        default: Invalid;
                    endcase;
                    legalInst = isValid(mAluFunc);
                    dInst.execFunc = tagged Alu mAluFunc.Valid;
                end
                opALU2: begin
                    Maybe#(AluFunc) mAluFunc = case (funct3)
                        fnADD: Valid(Subw);
                        fnSR: Valid(Sraw);
                        default: Invalid;
                    endcase;
                    legalInst = isValid(mAluFunc);
                    dInst.execFunc = tagged Alu mAluFunc.Valid;
                end
                opMULDIV: begin
                    if (isa.m) begin
                        // Processor includes "M" extension
                        // TODO mark MULH as illegal inst
                        Maybe#(MulDivFunc) mFunc = case(funct3)
                            fnMUL    : Valid(Mul);
                            fnMULH   : Invalid;
                            fnMULHSU : Invalid;
                            fnMULHU  : Invalid;
                            fnDIV    : Valid(Div);
                            fnDIVU   : Valid(Div);
                            fnREM    : Valid(Rem);
                            fnREMU   : Valid(Rem);
                            default  : Invalid;
                        endcase;
                        Bool w = True;
                        MulDivSign sign = case(funct3)
                            fnMUL    : Signed;
                            fnMULH   : Signed; // illegal
                            fnMULHSU : SignedUnsigned; // illegal
                            fnMULHU  : Unsigned; // illegal
                            fnDIV    : Signed;
                            fnDIVU   : Unsigned;
                            fnREM    : Signed;
                            fnREMU   : Unsigned;
                        endcase;
                        legalInst = isValid(mFunc);
                        dInst.execFunc = tagged MulDiv (MulDivInst{
                            func: mFunc.Valid, w: w, sign: sign
                        });
                    end
                end
            endcase
            regs.dst  = Valid(tagged Gpr rd);
            regs.src1 = Valid(tagged Gpr rs1);
            regs.src2 = Valid(tagged Gpr rs2);
            dInst.imm = Invalid;
            dInst.csr = tagged Invalid;
        end

        opcLui: begin // treated as an x0 + immU
            legalInst = True;
            dInst.iType = Alu;
            dInst.execFunc = tagged Alu Add;
            regs.dst = Valid(tagged Gpr rd);
            regs.src1 = Valid(tagged Gpr 0);
            regs.src2 = Invalid;
            dInst.imm = Valid(immU);
            dInst.csr = tagged Invalid;
        end

        opcAuipc: begin
            legalInst = True;
            dInst.iType = cap_mode ? Auipcc : Auipc;
            dInst.execFunc = tagged Alu Add;
            regs.dst  = Valid(tagged Gpr rd);
            regs.src1 = Invalid;
            regs.src2 = Invalid;
            dInst.imm = Valid(immU);
            dInst.csr = tagged Invalid;
        end

        opcJal: begin
            if (cap_mode) begin
                dInst.iType = CJAL;
            end
            else begin
                dInst.iType = J;
            end

            legalInst = True;
            regs.dst  = Valid(tagged Gpr rd);
            regs.src1 = Invalid;
            regs.src2 = Invalid;
            dInst.imm = Valid(immJ);
            dInst.csr = tagged Invalid;
            dInst.execFunc = tagged Br AT;
            dInst.capChecks.check_enable = True;
            dInst.capChecks.check_authority_src = Pcc;
            dInst.capChecks.check_low_src = Src1Addr;
            dInst.capChecks.check_high_src = Src1AddrPlus2;
            dInst.capChecks.check_inclusive = True;
        end

        opcJalr: begin
            regs.dst  = Valid(tagged Gpr rd);
            regs.src1 = Valid(tagged Gpr rs1);
            regs.src2 = Invalid;
            dInst.imm = Valid(immI);
            dInst.csr = tagged Invalid;
            dInst.execFunc = tagged Br AT;

            if (funct3 == 0) legalInst = True;

            dInst.capChecks.check_enable = True;
            dInst.capChecks.check_low_src = Src1Addr;
            dInst.capChecks.check_high_src = Src1AddrPlus2;
            dInst.capChecks.check_inclusive = True;
            if (cap_mode) begin
                dInst.iType = CJALR;

                dInst.capChecks.src1_tag = True;
                dInst.capChecks.src1_permit_x = True;
                dInst.capChecks.src1_unsealed_or_sentry = True;
                dInst.capChecks.src1_unsealed_or_imm_zero = True;

                dInst.capChecks.check_authority_src = Src1;
            end
            else begin
                dInst.iType = Jr;

                dInst.capChecks.check_authority_src = Pcc;
            end
        end

        opcBranch: begin
            dInst.iType = Br;
            Maybe#(BrFunc) mBrFunc = case(funct3)
                fnBEQ:   Valid(Eq);
                fnBNE:   Valid(Neq);
                fnBLT:   Valid(Lt);
                fnBLTU:  Valid(Ltu);
                fnBGE:   Valid(Ge);
                fnBGEU:  Valid(Geu);
                default: Invalid;
            endcase;
            legalInst = isValid(mBrFunc);
            dInst.execFunc = tagged Br mBrFunc.Valid;

            regs.dst  = Invalid;
            regs.src1 = Valid(tagged Gpr rs1);
            regs.src2 = Valid(tagged Gpr rs2);
            dInst.imm = Valid(immB);
            dInst.csr = tagged Invalid;
            dInst.capChecks.check_enable = True;
            dInst.capChecks.check_authority_src = Pcc;
            dInst.capChecks.check_low_src = Src1Addr;
            dInst.capChecks.check_high_src = Src1AddrPlus2;
            dInst.capChecks.check_inclusive = True;
        end

        opcLoad: begin
            dInst.iType = Ld;
            legalInst = isValid(mem_inst);
            dInst.execFunc = tagged Mem mem_inst.Valid;
            regs.dst  = Valid(tagged Gpr rd);
            regs.src1 = Valid(tagged Gpr rs1);
            regs.src2 = Invalid;
            dInst.imm = Valid(immI);
            dInst.csr = tagged Invalid;
            dInst.capChecks = memCapChecks(cap_mode);
        end

        opcStore: begin
            dInst.iType = St;
            legalInst = isValid(mem_inst);
            dInst.execFunc = tagged Mem mem_inst.Valid;
            regs.dst  = Invalid;
            regs.src1 = Valid(tagged Gpr rs1);
            regs.src2 = Valid(tagged Gpr rs2);
            dInst.imm = Valid(immS);
            dInst.csr = tagged Invalid;
            dInst.capChecks = memCapChecks(cap_mode);
        end

        opcAmo: begin
            if (isa.a) begin
                // AMO defaults
                dInst.iType = Amo;
                regs.dst  = Valid(tagged Gpr rd);
                regs.src1 = Valid(tagged Gpr rs1);
                regs.src2 = Valid(tagged Gpr rs2);
                dInst.imm = Valid(0);
                dInst.csr = Invalid;

                case (funct5)
                    fnLR: begin
                        dInst.iType = Lr;
                        legalInst = isValid(mem_inst);
                        dInst.execFunc = tagged Mem mem_inst.Valid;
                        regs.dst  = Valid(tagged Gpr rd);
                        regs.src1 = Valid(tagged Gpr rs1);
                        regs.src2 = Invalid;
                        dInst.imm = Valid(0);
                        dInst.csr = Invalid;
                    end

                    fnSC: begin
                        dInst.iType = Sc;
                        legalInst = isValid(mem_inst);
                        dInst.execFunc = tagged Mem mem_inst.Valid;
                        regs.dst  = Valid(tagged Gpr rd);
                        regs.src1 = Valid(tagged Gpr rs1);
                        regs.src2 = Valid(tagged Gpr rs2);
                        dInst.imm  = Valid(0);
                        dInst.csr  = Invalid;
                    end

                    fnAMOSWAP,
                    fnAMOADD,
                    fnAMOXOR,
                    fnAMOAND,
                    fnAMOOR,
                    fnAMOMIN,
                    fnAMOMAX,
                    fnAMOMINU,
                    fnAMOMAXU: begin
                        legalInst = isValid(mem_inst);
                        dInst.execFunc = tagged Mem mem_inst.Valid;
                    end
                endcase
            end
        end

        // Instructions for "F" and "D" ISA extensions - FPU
        opcOpFp: begin
            if (fpFmtInISA) begin
                // Instruction is supported
                dInst.iType = Fpu;
                regs.dst  = Valid(tagged Fpu rd);
                regs.src1 = Valid(tagged Fpu rs1);
                regs.src2 = Valid(tagged Fpu rs2);
                dInst.imm  = Invalid;
                dInst.csr = tagged Invalid;
                Maybe#(FpuFunc) mFunc = case (funct5)
                    opFADD:     Valid(FAdd);
                    opFSUB:     Valid(FSub);
                    opFMUL:     Valid(FMul);
                    opFDIV:     Valid(FDiv);
                    opFSQRT:    Valid(FSqrt);
                    opFSGNJ:    Valid((funct3 == 0) ? FSgnj : ((funct3 == 1) ? FSgnjn : FSgnjx));
                    opFMINMAX:  Valid((funct3 == 0) ? FMin : FMax);
                    opFCMP:     Valid((funct3 == 0) ? FLe : ((funct3 == 1) ? FLt : FEq));
                    opFMV_XF:   Valid((funct3 == 0) ? FMv_XF : FClass); // also CLASS
                    opFMV_FX:   Valid(FMv_FX);
                    opFCVT_FF:  Valid(FCvt_FF);
                    opFCVT_WF:  Valid((rs2 == 0) ? FCvt_WF : ((rs2 == 1) ? FCvt_WUF : ((rs2 == 2) ? FCvt_LF : FCvt_LUF)));
                    opFCVT_FW:  Valid((rs2 == 0) ? FCvt_FW : ((rs2 == 1) ? FCvt_FWU : ((rs2 == 2) ? FCvt_FL : FCvt_FLU)));
                    default:    Invalid;
                endcase;
                FpuPrecision precision = (fmt == fmtS) ? Single : Double;
                legalInst = isValid(mFunc);
                dInst.execFunc = tagged Fpu(FpuInst{func: mFunc.Valid, rm: unpack(funct3), precision: precision});
                // Special cases
                case (funct5)
                    opFSQRT: begin
                        regs.dst  = Valid(tagged Fpu rd);
                        regs.src1 = Valid(tagged Fpu rs1);
                        regs.src2 = Invalid;
                    end
                    opFCMP: begin
                        regs.dst  = Valid(tagged Gpr rd);
                        regs.src1 = Valid(tagged Fpu rs1);
                        regs.src2 = Valid(tagged Fpu rs2);
                    end
                    opFMV_XF: begin
                        regs.dst  = Valid(tagged Gpr rd);
                        regs.src1 = Valid(tagged Fpu rs1);
                        regs.src2 = Invalid;
                    end
                    opFMV_FX: begin
                        regs.dst  = Valid(tagged Fpu rd);
                        regs.src1 = Valid(tagged Gpr rs1);
                        regs.src2 = Invalid;
                    end
                    opFCVT_FF: begin
                        regs.dst  = Valid(tagged Fpu rd);
                        regs.src1 = Valid(tagged Fpu rs1);
                        regs.src2 = Invalid;
                    end
                    opFCVT_WF: begin
                        regs.dst  = Valid(tagged Gpr rd);
                        regs.src1 = Valid(tagged Fpu rs1);
                        regs.src2 = Invalid;
                    end
                    opFCVT_FW: begin
                        regs.dst  = Valid(tagged Fpu rd);
                        regs.src1 = Valid(tagged Gpr rs1);
                        regs.src2 = Invalid;
                    end
                endcase
            end
        end
        opcLoadFp: begin
            // check if instruction is supported
            if (isa.f || isa.d) begin
                // Same decode logic as Int Ld
                dInst.iType = Ld;
                legalInst = isValid(mem_inst);
                dInst.execFunc = tagged Mem mem_inst.Valid;
                regs.dst  = Valid(tagged Fpu rd);
                regs.src1 = Valid(tagged Gpr rs1);
                regs.src2 = Invalid;
                dInst.imm = Valid(immI);
                dInst.csr = tagged Invalid;
                dInst.capChecks = memCapChecks(cap_mode);
            end
        end
        opcStoreFp: begin
            // check if instruction is supported
            if (isa.f || isa.d) begin
                // Same decode logic as Int St
                dInst.iType = St;
                legalInst = isValid(mem_inst);
                dInst.execFunc = tagged Mem mem_inst.Valid;
                regs.dst  = Invalid;
                regs.src1 = Valid(tagged Gpr rs1);
                regs.src2 = Valid(tagged Fpu rs2);
                dInst.imm = Valid(immS);
                dInst.csr = tagged Invalid;
                dInst.capChecks = memCapChecks(cap_mode);
            end
        end
        opcFmadd, opcFmsub, opcFnmsub, opcFnmadd: begin
            if (fpFmtInISA) begin
                dInst.iType = Fpu;
                Maybe#(FpuFunc) mFunc = case (opcode)
                    opcFmadd:  Valid(FMAdd);
                    opcFmsub:  Valid(FMSub);
                    opcFnmsub: Valid(FNMSub);
                    opcFnmadd: Valid(FNMAdd);
                    default: Invalid;
                endcase;
                legalInst = isValid(mFunc);
                dInst.execFunc = tagged Fpu (FpuInst {
                    func: mFunc.Valid,
                    rm: unpack(funct3),
                    precision: fmt == fmtS ? Single : Double
                });
                regs.src1 = Valid(tagged Fpu rs1);
                regs.src2 = Valid(tagged Fpu rs2);
                regs.src3 = Valid(rs3);
                regs.dst = Valid(tagged Fpu rd);
                dInst.csr = Invalid;
                dInst.imm = Invalid;
            end
        end

        opcMiscMem: begin
            regs.dst  = Invalid;
            regs.src1 = Invalid;
            regs.src2 = Invalid;
            dInst.imm  = Invalid;
            dInst.csr  = Invalid;
            case (funct3)
                fnFENCEI: begin
                    legalInst = True;
                    dInst.iType = FenceI;
                    dInst.execFunc = tagged Other;
                end
                fnFENCE: begin
                    legalInst = True;
                    // extract bits for P/S IORW
                    Bool old_st = unpack(inst[26] | inst[24]); // PO, PW
                    Bool young_ld = unpack(inst[23] | inst[21]); // SI, SR
                    // get acq/reconcile and rel/commit needed to enforce
                    // different orderings
`ifdef TSO_MM
                    // Orderings enfored by fence in TSO:
                    // St -> Ld: commit
                    // Others: N/A
                    Bool reconcile = False;
                    Bool commit = old_st && young_ld;
`else
                    // Orderings enforced by fence in WMM
                    // St -> St: commit
                    // St -> Ld: commit + reconcile
                    // Ld -> Ld: reconcile
                    // Ld -> St: N/A
                    Bool reconcile = young_ld; // reconcile when younger load is in ordering
                    Bool commit = old_st; // commit when older store is in ordering
`endif
                    // set up fence inst
                    if (reconcile || commit) begin
                        dInst.iType = Fence;
                        dInst.execFunc = tagged Mem (MemInst {
                            mem_func: Fence,
                            amo_func: None,
                            unsignedLd: False,
                            byteOrTagEn: DataMemAccess(replicate(False)),
                            aq: reconcile,
                            rl: commit,
                            reg_bounds: False // unused
                        });
                    end
                    else begin
                        dInst.iType = Nop;
                        dInst.execFunc = tagged Other;
                    end
                end
                fnLC: begin
                    dInst.iType = Ld;
                    legalInst = isValid(mem_inst);
                    dInst.execFunc = tagged Mem mem_inst.Valid;
                    regs.dst  = Valid(tagged Gpr rd);
                    regs.src1 = Valid(tagged Gpr rs1);
                    regs.src2 = Invalid;
                    dInst.imm = Valid(immI);
                    dInst.csr = tagged Invalid;
                    dInst.capChecks = memCapChecks(cap_mode);
                end
            endcase
        end

        opcSystem: begin
            if (funct3 == fnPRIV) begin
                if (funct7 == privSFENCEVMA) begin
                    dInst.iType = SFence;
                    legalInst = True;
                    // FIXME SFENCE.VMA is implemented in coarse grain,
                    // ignoring rs1 and rs2
                end
                else begin
                    Maybe#(IType) mIType = case (truncate(immI))
                        privSRET: Valid(Sret);
                        privMRET: Valid(Mret);
                        privECALL: Valid(Ecall);
                        privEBREAK: Valid(Ebreak);
                        privWFI: Valid(Nop); // treat as NOP
                        default: Invalid;
                    endcase;
                    legalInst = isValid(mIType);
                    dInst.iType = mIType.Valid;
                end
                regs.dst  = Invalid;
                regs.src1 = Invalid;
                regs.src2 = Invalid;
                dInst.csr = Invalid;
                dInst.imm = Invalid;
            end
            else begin // fnCSRRWI, fnCSRRW, fnCSRRSI, fnCSRRS, fnCSRRCI, fnCSRRC
                if (truncate(immI) == pack(csrAddrMTVEC) || truncate(immI) == pack(csrAddrMEPC) || truncate(immI) == pack(csrAddrSTVEC) || truncate(immI) == pack(csrAddrSEPC)) begin
                    Bool shouldWrite = (funct3 == fnCSRRWI || funct3 == fnCSRRW) || rs1 != 0;
                    dInst.iType = shouldWrite ? Scr : Cap;
                    regs.dst = Valid(tagged Gpr rd);
                    regs.src1 = (funct3[2] == 0 ? Valid(tagged Gpr rs1) : Invalid);
                    dInst.imm = (funct3[2] == 0 ? Invalid : Valid(zeroExtend(rs1)));
                    regs.src2 = Invalid;

                    Maybe#(CSRAccessFunc) mAccessFunc = case (funct3)
                        fnCSRRWI, fnCSRRW: Valid(Write);
                        fnCSRRSI, fnCSRRS: Valid(Set);
                        fnCSRRCI, fnCSRRC: Valid(Clear);
                        default          : Invalid;
                    endcase;

                    legalInst = isValid(mAccessFunc); // Non-existent CSRs are checked for later

                    let scrType = ?;
                    case (truncate(immI))
                        pack(csrAddrMEPC): begin
                            scrType = EPC (mAccessFunc.Valid);
                            dInst.scr = Valid (scrAddrMEPCC);
                        end
                        pack(csrAddrMTVEC): begin
                            scrType = TVEC (mAccessFunc.Valid);
                            dInst.scr = Valid (scrAddrMTCC);
                        end
                        pack(csrAddrSEPC): begin
                            scrType = EPC (mAccessFunc.Valid);
                            dInst.scr = Valid (scrAddrSEPCC);
                        end
                        pack(csrAddrSTVEC): begin
                            scrType = TVEC (mAccessFunc.Valid);
                            dInst.scr = Valid (scrAddrSTCC);
                        end
                    endcase

                    dInst.capFunc = CapModify (SpecialRW (scrType));
                end else begin
                    dInst.iType = Csr;
                    Maybe#(AluFunc) mAluFunc = case (funct3)
                        fnCSRRWI, fnCSRRW: Valid(Csrw);
                        fnCSRRSI, fnCSRRS: Valid(Csrs);
                        fnCSRRCI, fnCSRRC: Valid(Csrc);
                        default:           Invalid;
                    endcase;

                    legalInst = isValid(mAluFunc); // Non-existent CSRs are checked for later
                    dInst.execFunc = tagged Alu mAluFunc.Valid;
                    regs.dst = Valid(tagged Gpr rd);
                    regs.src1 = Invalid; // going to be CSR Reg
                    regs.src2 = (funct3[2] == 0 ? Valid(tagged Gpr rs1) : Invalid);
                    dInst.imm = (funct3[2] == 0 ? Invalid : Valid(zeroExtend(rs1)));
                    dInst.csr = Valid(unpackCSR(truncate(immI)));
                end
            end
        end

        opcOpCHERI: begin
            case (funct3)
                f3_cap_CIncOffsetImmediate: begin
                    legalInst = True;
                    dInst.iType = Cap;
                    regs.dst = Valid(tagged Gpr rd);
                    regs.src1 = Valid(tagged Gpr rs1);
                    dInst.imm = Valid(immI);
                    dInst.capFunc = CapModify (ModifyOffset (IncOffset));
                end
                f3_cap_CSetBoundsImmediate: begin
                    legalInst = True;
                    dInst.iType = Cap;
                    regs.dst = Valid(tagged Gpr rd);
                    regs.src1 = Valid(tagged Gpr rs1);
                    dInst.imm = Valid (immIunsigned);
                    dInst.capFunc = CapModify (SetBounds (SetBoundsRounding));
                end
                f3_cap_ThreeOp: begin
                    case (funct7)
                        f7_cap_CSpecialRW: begin
                            legalInst = True; // Non-existent SCRs are checked for later
                            dInst.iType = rs1 == 0 ? Cap : Scr;
                            regs.dst = Valid(tagged Gpr rd);
                            regs.src1 = Valid(tagged Gpr rs1);

                            let scr = unpackSCR(rs2);

                            let scrType = case (rs2[1:0])
                                              0: TCC;
                                              3: EPCC;
                                              default: Normal;
                                          endcase;

                            // Decode SCR read to PCC as AUIPCC 0
                            if (scr == scrAddrPCC) begin
                                dInst.iType = Auipcc;
                                dInst.execFunc = tagged Alu Add;
                                dInst.csr = tagged Invalid;
                            end

                            dInst.scr = Valid (scr);
                            dInst.capFunc = CapModify (SpecialRW (scrType));
                        end
                        f7_cap_CSetBounds: begin
                            legalInst = True;
                            dInst.iType = Cap;
                            regs.dst = Valid(tagged Gpr rd);
                            regs.src1 = Valid(tagged Gpr rs1);
                            regs.src2 = Valid(tagged Gpr rs2);
                            dInst.capFunc = CapModify (SetBounds (SetBoundsRounding));
                        end
                        f7_cap_CSetBoundsExact: begin
                            legalInst = True;
                            dInst.iType = Cap;
                            regs.dst = Valid(tagged Gpr rd);
                            regs.src1 = Valid(tagged Gpr rs1);
                            regs.src2 = Valid(tagged Gpr rs2);
                            dInst.capFunc = CapModify (SetBounds (SetBoundsExact));
                        end
                        f7_cap_CSetOffset: begin
                            legalInst = True;
                            dInst.iType = Cap;
                            regs.dst = Valid(tagged Gpr rd);
                            regs.src1 = Valid(tagged Gpr rs1);
                            regs.src2 = Valid(tagged Gpr rs2);
                            dInst.capFunc = CapModify (ModifyOffset (SetOffset));
                        end
                        f7_cap_CSetAddr: begin
                            legalInst = True;
                            dInst.iType = Cap;
                            regs.dst = Valid(tagged Gpr rd);
                            regs.src1 = Valid(tagged Gpr rs2);
                            regs.src2 = Valid(tagged Gpr rs1);
                            dInst.capFunc = CapModify (SetAddr (Src1Addr));
                        end
                        f7_cap_CIncOffset: begin
                            legalInst = True;
                            dInst.iType = Cap;
                            regs.dst = Valid(tagged Gpr rd);
                            regs.src1 = Valid(tagged Gpr rs1);
                            regs.src2 = Valid(tagged Gpr rs2);
                            dInst.capFunc = CapModify (ModifyOffset (IncOffset));
                        end
                        f7_cap_CSeal: begin
                            legalInst = True;
                            dInst.iType = Cap;
                            regs.dst = Valid(tagged Gpr rd);
                            regs.src1 = Valid(tagged Gpr rs1);
                            regs.src2 = Valid(tagged Gpr rs2);
                            dInst.capFunc = CapModify (Seal);
                        end
                        f7_cap_CCSeal: begin
                            legalInst = True;
                            dInst.iType = Cap;
                            regs.dst = Valid(tagged Gpr rd);
                            regs.src1 = Valid(tagged Gpr rs1);
                            regs.src2 = Valid(tagged Gpr rs2);
                            dInst.capFunc = CapModify (CSeal);
                        end
                        f7_cap_TwoSrc: begin
                            case (rd)
                                rd_cap_CCall: begin
                                    legalInst = True;
                                    dInst.capChecks.src1_tag = True;
                                    dInst.capChecks.src2_tag = True;
                                    dInst.capChecks.src1_sealed_with_type = True;
                                    dInst.capChecks.src2_sealed_with_type = True;
                                    dInst.capChecks.src1_src2_types_match = True;
                                    dInst.capChecks.src1_type_not_reserved = True;
                                    dInst.capChecks.src1_permit_x = True;
                                    dInst.capChecks.src2_no_permit_x = True;
                                    dInst.capChecks.src1_permit_ccall = True;
                                    dInst.capChecks.src2_permit_ccall = True;

                                    dInst.capChecks.check_enable = True;
                                    dInst.capChecks.check_authority_src = Src1;
                                    dInst.capChecks.check_low_src = Src1Addr;
                                    dInst.capChecks.check_high_src = Src1AddrPlus2;
                                    dInst.capChecks.check_inclusive = True;

                                    dInst.iType = CCall;
                                    dInst.capFunc = CapModify (Unseal (Src2));
                                    dInst.execFunc = tagged Br AT;
                                    regs.dst = Valid(tagged Gpr 31);
                                    regs.src1 = Valid(tagged Gpr rs1);
                                    regs.src2 = Valid(tagged Gpr rs2);
                                end
                            endcase
                        end
                        f7_cap_CUnseal: begin
                            legalInst = True;
                            dInst.iType = Cap;
                            regs.dst = Valid(tagged Gpr rd);
                            regs.src1 = Valid(tagged Gpr rs1);
                            regs.src2 = Valid(tagged Gpr rs2);
                            dInst.capFunc = CapModify (Unseal (Src1));
                        end
                        f7_cap_CTestSubset: begin
                            legalInst = True;
                            dInst.iType = Cap;
                            regs.dst = Valid(tagged Gpr rd);
                            regs.src1 = Valid(tagged Gpr rs2);
                            regs.src2 = rs1 == 0 ? Invalid : Valid(tagged Gpr rs1);
                            dInst.scr = rs1 == 0 ? Valid (scrAddrDDC) : Invalid;
                            dInst.capFunc = CapInspect (TestSubset);
                        end
                        f7_cap_CSetEqualExact: begin
                            legalInst = True;
                            dInst.iType = Cap;
                            regs.dst = Valid(tagged Gpr rd);
                            regs.src1 = Valid(tagged Gpr rs1);
                            regs.src2 = Valid(tagged Gpr rs2);
                            dInst.capFunc = CapInspect (SetEqualExact);
                        end
                        f7_cap_CCopyType: begin
                            legalInst = True;
                            dInst.iType = Cap;
                            regs.dst = Valid(tagged Gpr rd);
                            regs.src1 = Valid(tagged Gpr rs2);
                            regs.src2 = Valid(tagged Gpr rs1);
                            dInst.capFunc = CapModify (SetAddr (Src1Type));
                        end
                        f7_cap_CAndPerm: begin
                            legalInst = True;
                            dInst.iType = Cap;
                            regs.dst = Valid(tagged Gpr rd);
                            regs.src1 = Valid(tagged Gpr rs1);
                            regs.src2 = Valid(tagged Gpr rs2);
                            dInst.capFunc = CapModify (AndPerm);
                        end
                        f7_cap_CSetFlags: begin
                            legalInst = True;
                            dInst.iType = Cap;
                            regs.dst = Valid(tagged Gpr rd);
                            regs.src1 = Valid(tagged Gpr rs1);
                            regs.src2 = Valid(tagged Gpr rs2);
                            dInst.capFunc = CapModify (SetFlags);
                        end
                        f7_cap_CToPtr: begin
                            legalInst = True;
                            dInst.iType = Cap;
                            regs.dst = Valid(tagged Gpr rd);
                            regs.src1 = Valid(tagged Gpr rs1);
                            if (rs2 == 0) begin
                                regs.src2 = Invalid;
                                dInst.scr = Valid (scrAddrDDC);
                            end else begin
                                regs.src2 = Valid (tagged Gpr rs2);
                                dInst.scr = Invalid;
                            end
                            dInst.capFunc = CapInspect (ToPtr);
                        end
                        f7_cap_CFromPtr: begin
                            legalInst = True;
                            dInst.iType = Cap;
                            regs.dst = Valid(tagged Gpr rd);
                            regs.src1 = Valid(tagged Gpr rs2);
                            regs.src2 = rs1 == 0 ? Invalid : Valid (tagged Gpr rs1);
                            dInst.scr = rs1 == 0 ? Valid(scrAddrDDC) : Invalid;
                            dInst.capFunc = CapModify (FromPtr);
                        end
                        f7_cap_CSub: begin
                            // CSub is just a riscv subtract
                            legalInst = True;
                            dInst.iType = Alu;
                            regs.dst  = Valid(tagged Gpr rd);
                            regs.src1 = Valid(tagged Gpr rs1);
                            regs.src2 = Valid(tagged Gpr rs2);
                            dInst.execFunc = Alu (Sub);
                        end
                        f7_cap_CSetHigh: begin
                            legalInst = True;
                            dInst.iType = Cap;
                            regs.dst = Valid(tagged Gpr rd);
                            regs.src1 = Valid(tagged Gpr rs1);
                            regs.src2 = Valid(tagged Gpr rs2);
                            dInst.capFunc = CapModify (SetHigh);
                        end
                        f7_cap_CBuildCap: begin
                            legalInst = True;
                            // Swap arguments so SCR possibly goes in RS2
                            dInst.iType = Cap;
                            regs.dst = Valid(tagged Gpr rd);
                            regs.src1 = Valid(tagged Gpr rs2);
                            if (rs1 == 0) begin
                                dInst.scr = Valid(scrAddrDDC);
                            end else begin
                                regs.src2 = Valid(tagged Gpr rs1);
                            end
                            dInst.capFunc = CapModify (BuildCap);
                        end
                        f7_cap_Loads: begin
                            dInst.iType = Ld;
                            legalInst = isValid(exp_bnds_mem_inst);
                            MemInst mi = exp_bnds_mem_inst.Valid;
                            dInst.execFunc = tagged Mem mi;
                            if (mi.mem_func == Lr)
                                dInst.iType = Lr;
                            regs.dst  = Valid(tagged Gpr rd);
                            regs.src1 = Valid(tagged Gpr rs1);
                            dInst.imm = Valid (0);
                            dInst.capChecks = memCapChecks(mi.reg_bounds);
                        end
                        f7_cap_Stores: begin
                            dInst.iType = St;
                            legalInst = isValid(exp_bnds_mem_inst);
                            MemInst mi = exp_bnds_mem_inst.Valid;
                            dInst.execFunc = tagged Mem mi;
                            if (mi.mem_func == Sc) begin
                                dInst.iType = Sc;
                                regs.dst = Valid(tagged Gpr rs2);
                            end
                            regs.src1 = Valid(tagged Gpr rs1);
                            regs.src2 = Valid(tagged Gpr rs2);
                            dInst.imm = Valid (0);
                            dInst.capChecks = memCapChecks(mi.reg_bounds);
                        end
                        f7_cap_TwoOp: begin
                            case (funct5rs2)
                                f5rs2_cap_CGetLen: begin
                                    legalInst = True;
                                    dInst.iType = Cap;
                                    regs.dst = Valid(tagged Gpr rd);
                                    regs.src1 = Valid(tagged Gpr rs1);
                                    dInst.capFunc = CapInspect (GetLen);
                                end
                                f5rs2_cap_CGetBase: begin
                                    legalInst = True;
                                    dInst.iType = Cap;
                                    regs.dst = Valid(tagged Gpr rd);
                                    regs.src1 = Valid(tagged Gpr rs1);
                                    dInst.capFunc = CapInspect (GetBase);
                                end
                                f5rs2_cap_CGetTag: begin
                                    legalInst = True;
                                    dInst.iType = Cap;
                                    regs.dst = Valid(tagged Gpr rd);
                                    regs.src1 = Valid(tagged Gpr rs1);
                                    dInst.capFunc = CapInspect (GetTag);
                                end
                                f5rs2_cap_CGetSealed: begin
                                    legalInst = True;
                                    dInst.iType = Cap;
                                    regs.dst = Valid(tagged Gpr rd);
                                    regs.src1 = Valid(tagged Gpr rs1);
                                    dInst.capFunc = CapInspect (GetSealed);
                                end
                                f5rs2_cap_CRRL: begin
                                    legalInst = True;
                                    dInst.iType = Cap;
                                    regs.dst = Valid(tagged Gpr rd);
                                    regs.src1 = Valid(tagged Gpr 0); // Operate on nullcap
                                    regs.src2 = Valid(tagged Gpr rs1);
                                    dInst.capFunc = CapModify (SetBounds (CRRL));
                                end
                                f5rs2_cap_CRAM: begin
                                    legalInst = True;
                                    dInst.iType = Cap;
                                    regs.dst = Valid(tagged Gpr rd);
                                    regs.src1 = Valid(tagged Gpr 0); // Operate on nullcap
                                    regs.src2 = Valid(tagged Gpr rs1);
                                    dInst.capFunc = CapModify (SetBounds (CRAM));
                                end
                                f5rs2_cap_CMove: begin
                                    legalInst = True;
                                    dInst.iType = Cap;
                                    regs.dst = Valid(tagged Gpr rd);
                                    regs.src1 = Valid(tagged Gpr rs1);
                                    dInst.capFunc = CapModify (Move);
                                end
                                f5rs2_cap_CClearTag: begin
                                    legalInst = True;
                                    dInst.iType = Cap;
                                    regs.dst = Valid(tagged Gpr rd);
                                    regs.src1 = Valid(tagged Gpr rs1);
                                    dInst.capFunc = CapModify (ClearTag);
                                end
                                f5rs2_cap_CGetAddr: begin
                                    legalInst = True;
                                    dInst.iType = Cap;
                                    regs.dst = Valid(tagged Gpr rd);
                                    regs.src1 = Valid(tagged Gpr rs1);
                                    dInst.capFunc = CapInspect (GetAddr);
                                end
                                f5rs2_cap_CSealEntry: begin
                                    legalInst = True;
                                    dInst.iType = Cap;
                                    regs.dst = Valid(tagged Gpr rd);
                                    regs.src1 = Valid(tagged Gpr rs1);
                                    dInst.capFunc = CapModify (SealEntry);
                                end
                                f5rs2_cap_CGetOffset: begin
                                    legalInst = True;
                                    dInst.iType = Cap;
                                    regs.dst = Valid(tagged Gpr rd);
                                    regs.src1 = Valid(tagged Gpr rs1);
                                    dInst.capFunc = CapInspect (GetOffset);
                                end
                                f5rs2_cap_CGetFlags: begin
                                    legalInst = True;
                                    dInst.iType = Cap;
                                    regs.dst = Valid(tagged Gpr rd);
                                    regs.src1 = Valid(tagged Gpr rs1);
                                    dInst.capFunc = CapInspect (GetFlags);
                                end
                                f5rs2_cap_CGetPerm: begin
                                    legalInst = True;
                                    dInst.iType = Cap;
                                    regs.dst = Valid(tagged Gpr rd);
                                    regs.src1 = Valid(tagged Gpr rs1);
                                    dInst.capFunc = CapInspect (GetPerm);
                                end
                                f5rs2_cap_JALR_CAP: begin
                                    legalInst = True;
                                    dInst.capChecks.src1_tag = True;
                                    dInst.capChecks.src1_permit_x = True;
                                    dInst.capChecks.src1_unsealed_or_sentry = True;

                                    dInst.capChecks.check_enable = True;
                                    dInst.capChecks.check_authority_src = Src1;
                                    dInst.capChecks.check_low_src = Src1Addr;
                                    dInst.capChecks.check_high_src = Src1AddrPlus2;
                                    dInst.capChecks.check_inclusive = True;

                                    dInst.iType = CJALR;
                                    dInst.execFunc = tagged Br AT;
                                    regs.dst  = Valid(tagged Gpr rd);
                                    regs.src1 = Valid(tagged Gpr rs1);
                                end
                                f5rs2_cap_JALR_PCC: begin
                                    legalInst = True;
                                    dInst.capChecks.check_enable = True;
                                    dInst.capChecks.check_authority_src = Pcc;
                                    dInst.capChecks.check_low_src = Src1Addr;
                                    dInst.capChecks.check_high_src = Src1AddrPlus2;
                                    dInst.capChecks.check_inclusive = True;

                                    dInst.iType = Jr;
                                    dInst.execFunc = tagged Br AT;
                                    regs.dst  = Valid(tagged Gpr rd);
                                    regs.src1 = Valid(tagged Gpr rs1);
                                end
                                f5rs2_cap_CGetType: begin
                                    legalInst = True;
                                    dInst.iType = Cap;
                                    regs.dst = Valid(tagged Gpr rd);
                                    regs.src1 = Valid(tagged Gpr rs1);
                                    dInst.capFunc = CapInspect (GetType);
                                end
                                f5rs2_cap_CGetHigh: begin
                                    legalInst = True;
                                    dInst.iType = Cap;
                                    regs.dst = Valid(tagged Gpr rd);
                                    regs.src1 = Valid(tagged Gpr rs1);
                                    dInst.capFunc = CapInspect (GetHigh);
                                end
                                f5rs2_cap_CLoadTags: begin
                                    legalInst = True;
                                    dInst.iType = Ld;
                                    dInst.imm = Valid(0);
                                    dInst.execFunc = tagged Mem MemInst{
                                        mem_func: Ld,
                                        amo_func: None,
                                        unsignedLd: False,
                                        byteOrTagEn: TagMemAccess,
                                        aq: False,
                                        rl: False,
                                        reg_bounds: True };
                                    regs.dst  = Valid(tagged Gpr rd);
                                    regs.src1 = Valid(tagged Gpr rs1);
                                    dInst.capChecks = memCapChecks(True);
                                end
                            endcase
                        end
                    endcase
                end
            endcase
        end
    endcase

    dInst.capChecks.rn1 = {1'b0, regs.src1.Valid.Gpr};
    dInst.capChecks.rn2 = {1'b0, regs.src2.Valid.Gpr};

    // XXX to ensure renaming + phy regs works correctly, must remove any write
    // to x0
    if(regs.dst matches tagged Valid .dst &&& dst == tagged Gpr 0) begin
        regs.dst = tagged Invalid;
    end

    return DecodeResult{dInst: dInst, regs: regs, illegalInst: !legalInst};
endfunction

// All this does is add the CSR state to the decoding
function FpuInst updateRoundingMode(FpuInst fpu_f, CsrDecodeInfo csrState);
    let new_fpu_f = fpu_f;
    new_fpu_f.rm = (fpu_f.rm == rmRDyn) ? unpack(csrState.frm) : fpu_f.rm;
    return new_fpu_f;
endfunction
