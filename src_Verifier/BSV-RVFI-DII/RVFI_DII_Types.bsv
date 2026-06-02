/*-
 * Copyright (c) 2018 Jack Deely
 * Copyright (c) 2018 Jonathan Woodruff
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory (Department of Computer Science and
 * Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
 * DARPA SSITH research programme.
 *
 * @BERI_LICENSE_HEADER_START@
 *
 * Licensed to BERI Open Systems C.I.C. (BERI) under one or more contributor
 * license agreements.  See the NOTICE file distributed with this work for
 * additional information regarding copyright ownership.  BERI licenses this
 * file to you under the BERI Hardware-Software License, Version 1.0 (the
 * "License"); you may not use this file except in compliance with the
 * License.  You may obtain a copy of the License at:
 *
 *   http://www.beri-open-systems.org/legal/license-1-0.txt
 *
 * Unless required by applicable law or agreed to in writing, Work distributed
 * under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * @BERI_LICENSE_HEADER_END@
 */

import DefaultValue :: *;
//import ISA_Decls :: *;

typedef 'h80000000 RVFI_DII_Mem_Start;
typedef 'h00800000 RVFI_DII_Mem_Size; //8MiB
typedef TAdd#(RVFI_DII_Mem_Start, RVFI_DII_Mem_Size) RVFI_DII_Mem_End;

// Define instruction and register sizes

// Clifford Wolf RISC-V Formal Interface
// (http://www.clifford.at/papers/2017/riscv-formal/slides.pdf)
typedef struct {

    //Bit#(64)      rvfi_valid;     // Valid signal:                        Instruction was committed properly.
    Bit#(64)      rvfi_order;     // [000 - 063] Instruction number:      INSTRET value after completion.
    Bool          rvfi_trap;      // [064 - 064] Trap indicator:          Invalid decode, misaligned access or
                                  //                                      jump command to misaligned address.

    Bool          rvfi_halt;      // [065 - 065] Halt indicator:          Marks the last instruction retired
                                  //                                      before halting execution.

    Bool          rvfi_intr;      // [066 - 066] Trap handler:            Set for first instruction in trap handler.

    Bit#(32)      rvfi_insn;      // [067 - 098] Instruction word:        32-bit command value.
    Bit#(5)       rvfi_rs1_addr;  // [099 - 103] Read register addresses: Can be arbitrary when not used,
    Bit#(5)       rvfi_rs2_addr;  // [104 - 108]                          otherwise set as decoded.
    Bit#(xlen)    rvfi_rs1_data;  // [109 - 172] Read register values:    Values as read from registers named
    Bit#(xlen)    rvfi_rs2_data;  // [173 - 236]                          above. Must be 0 if register ID is 0.
    Bit#(xlen)    rvfi_pc_rdata;  // [237 - 300] PC before instr:         PC for current instruction
    Bit#(xlen)    rvfi_pc_wdata;  // [301 - 364] PC after instr:          Following PC - either PC + 4 or jump target.

    // PROBLEM: LR/SC, if SC fails then value is not written. Indicate as wmask = 0.
    Bit#(memwidth)    rvfi_mem_wdata; // [365 - 428] Write data:              Data written to memory by this command.

    // Found in ALU if used, not 0'd if not used. Check opcode/op_stage2.
    // PROBLEM: LD/AMO - then found in stage 2.
    Bit#(5)       rvfi_rd_addr;   // [429 - 433] Write register address:  MUST be 0 if not used.
    Bit#(xlen)    rvfi_rd_wdata;  // [434 - 497] Write register value:    MUST be 0 if rd_ is 0.

    // Found in ALU, conflicts with jump/branch target or CSR for CSRRX
    Bit#(xlen)    rvfi_mem_addr;  // [498 - 561] Memory access addr:      Points to byte address (aligned if define
                                  //                                      is set). *Should* be straightforward.

    // Not explicitly given, but calculable from opcode/funct3 from ISA_Decls.
    Bit#(TDiv#(memwidth,8)) rvfi_mem_rmask; // [562 - 569] Read mask:               Indicates valid bytes read. 0 if unused.
    Bit#(TDiv#(memwidth,8)) rvfi_mem_wmask; // [570 - 577] Write mask:              Indicates valid bytes written. 0 if unused.

    // XXX: SC writes something other than read value, but the value that would be read is unimportant.
    // Unsure what the point of this is, it's only relevant when the value is going to be in rd anyway.
    Bit#(xlen)    rvfi_mem_rdata; // [578 - 641] Read data:               Data read from mem_addr (i.e. before write)
} RVFI_DII_Execution#(numeric type xlen, numeric type memwidth) deriving (Bits, Eq);

instance FShow#(RVFI_DII_Execution#(a, b));
    function Fmt fshow (RVFI_DII_Execution#(a, b) x);
        Fmt acc = $format("Order: %04d, PC: 0x%016h, I: 0x%08h, PCWD: 0x%016h, Trap: %b, RD: %02d, "
                       , x.rvfi_order
                       , x.rvfi_pc_rdata
                       , x.rvfi_insn
                       , x.rvfi_pc_wdata
                       , x.rvfi_trap
                       , x.rvfi_rd_addr
                      );
        if (x.rvfi_rd_addr != 0) acc = acc + $format("RWD: 0x%016h, ", x.rvfi_rd_wdata);
        if (x.rvfi_mem_wmask != 0) begin
          acc = acc + $format("MA: 0x%016h, MWD: 0x%016h, ", x.rvfi_mem_addr, x.rvfi_mem_wdata);
          acc = acc + $format("MWM: 0b%08b", x.rvfi_mem_wmask);
        end
        if (x.rvfi_mem_rmask != 0) begin
          acc = acc + $format("MA: 0x%016h ", x.rvfi_mem_addr);
          acc = acc + $format("MRM: 0b%08b", x.rvfi_mem_rmask);
        end
        return acc;
    endfunction
endinstance

typedef struct {
    Bit#(8)  rvfi_intr;      // [066 - 066] Trap handler:            Set for first instruction in trap handler.
    Bit#(8)  rvfi_halt;      // [065 - 065] Halt indicator:          Marks the last instruction retired
                             //                                      before halting execution.
    Bit#(8)  rvfi_trap;      // [064 - 064] Trap indicator:          Invalid decode, misaligned access or
                             //                                      jump command to misaligned address.
    // Found in ALU if used, not 0'd if not used. Check opcode/op_stage2.
    // PROBLEM: LD/AMO - then found in stage 2.
    Bit#(8)  rvfi_rd_addr;   // [429 - 433] Write register address:  MUST be 0 if not used.
    Bit#(8)  rvfi_rs2_addr;  // [104 - 108]                          otherwise set as decoded.
    Bit#(8)  rvfi_rs1_addr;  // [099 - 103] Read register addresses: Can be arbitrary when not used,
    Bit#(8)  rvfi_mem_wmask; // [570 - 577] Write mask:              Indicates valid bytes written. 0 if unused.
    // Not explicitly given, but calculable from opcode/funct3 from ISA_Decls.
    Bit#(8)  rvfi_mem_rmask; // [562 - 569] Read mask:               Indicates valid bytes read. 0 if unused.
    // PROBLEM: LR/SC, if SC fails then value is not written. Indicate as wmask = 0.
    Bit#(64) rvfi_mem_wdata; // [365 - 428] Write data:              Data written to memory by this command.
    // XXX: SC writes something other than read value, but the value that would be read is unimportant.
    // Unsure what the point of this is, it's only relevant when the value is going to be in rd anyway.
    Bit#(64) rvfi_mem_rdata; // [578 - 641] Read data:               Data read from mem_addr (i.e. before write)
    Bit#(64) rvfi_mem_addr;  // [498 - 561] Memory access addr:      Points to byte address (aligned if define
                             //                                      is set). *Should* be straightforward.
    Bit#(64) rvfi_rd_wdata;  // [434 - 497] Write register value:    MUST be 0 if rd_ is 0.
    Bit#(64) rvfi_rs2_data;  // [173 - 236]                          above. Must be 0 if register ID is 0.
    Bit#(64) rvfi_rs1_data;  // [109 - 172] Read register values:    Values as read from registers named
    Bit#(64) rvfi_insn;      // [067 - 098] Instruction word:        32-bit command value.
    Bit#(64) rvfi_pc_wdata;  // [301 - 364] PC after instr:          Following PC - either PC + 4 or jump target.
    Bit#(64) rvfi_pc_rdata;  // [237 - 300] PC before instr:         PC for current instruction
    Bit#(64) rvfi_order;     // [000 - 063] Instruction number:      INSTRET value after completion.
    //Bit#(64) rvfi_valid;     // Valid signal:                        Instruction was committed properly.
} RVFI_DII_Execution_ByteStream deriving (Bits, Eq, FShow); // 88 Bytes

function RVFI_DII_Execution#(xlen,memwidth) byteStream2rvfi(RVFI_DII_Execution_ByteStream b)
  provisos (Add#(a__, TDiv#(xlen,8), 8), Add#(b__, xlen, 64), Add#(c__, TDiv#(memwidth,8), 8), Add#(d__, memwidth, 64));
  RVFI_DII_Execution#(xlen,memwidth) r = RVFI_DII_Execution{
    rvfi_order:     b.rvfi_order,
    rvfi_trap:      b.rvfi_trap==1,
    rvfi_halt:      b.rvfi_halt==1,
    rvfi_intr:      b.rvfi_intr==1,
    rvfi_insn:      truncate(b.rvfi_insn),
    rvfi_rs1_addr:  truncate(b.rvfi_rs1_addr),
    rvfi_rs2_addr:  truncate(b.rvfi_rs2_addr),
    rvfi_rs1_data:  truncate(b.rvfi_rs1_data),
    rvfi_rs2_data:  truncate(b.rvfi_rs2_data),
    rvfi_pc_rdata:  truncate(b.rvfi_pc_rdata),
    rvfi_pc_wdata:  truncate(b.rvfi_pc_wdata),
    rvfi_mem_wdata: truncate(b.rvfi_mem_wdata),
    rvfi_rd_addr:   truncate(b.rvfi_rd_addr),
    rvfi_rd_wdata:  truncate(b.rvfi_rd_wdata),
    rvfi_mem_addr:  truncate(b.rvfi_mem_addr),
    rvfi_mem_rmask: truncate(b.rvfi_mem_rmask),
    rvfi_mem_wmask: truncate(b.rvfi_mem_wmask),
    rvfi_mem_rdata: truncate(b.rvfi_mem_rdata)
  };
  return r;
endfunction

function RVFI_DII_Execution_ByteStream rvfi2byteStream(RVFI_DII_Execution#(xlen,memwidth) r)
  provisos (Add#(a__, TDiv#(xlen,8), 8), Add#(b__, xlen, 64), Add#(c__, TDiv#(memwidth,8), 8), Add#(d__, memwidth, 64));
  RVFI_DII_Execution_ByteStream b = RVFI_DII_Execution_ByteStream{
    rvfi_order:     r.rvfi_order,
    rvfi_trap:      r.rvfi_trap?1:0,
    rvfi_halt:      r.rvfi_halt?1:0,
    rvfi_intr:      r.rvfi_intr?1:0,
    rvfi_insn:      zeroExtend(r.rvfi_insn),
    rvfi_rs1_addr:  zeroExtend(r.rvfi_rs1_addr),
    rvfi_rs2_addr:  zeroExtend(r.rvfi_rs2_addr),
    rvfi_rs1_data:  zeroExtend(r.rvfi_rs1_data),
    rvfi_rs2_data:  zeroExtend(r.rvfi_rs2_data),
    rvfi_pc_rdata:  zeroExtend(r.rvfi_pc_rdata),
    rvfi_pc_wdata:  zeroExtend(r.rvfi_pc_wdata),
    rvfi_mem_wdata: zeroExtend(r.rvfi_mem_wdata),
    rvfi_rd_addr:   zeroExtend(r.rvfi_rd_addr),
    rvfi_rd_wdata:  zeroExtend(r.rvfi_rd_wdata),
    rvfi_mem_addr:  zeroExtend(r.rvfi_mem_addr),
    rvfi_mem_rmask: zeroExtend(r.rvfi_mem_rmask),
    rvfi_mem_wmask: zeroExtend(r.rvfi_mem_wmask),
    rvfi_mem_rdata: zeroExtend(r.rvfi_mem_rdata)
  };
  return b;
endfunction

typedef struct {
    Bool     rvfi_cmd;  // [63] This token is a trace command.  For example, reset device under test.
    Bit#(10) rvfi_time; // [62 - 53] Time to inject token.  The difference between this and the previous
                        // instruction time gives a delay before injecting this instruction.
                        // This can be ignored for models but gives repeatability for implementations
                        // while shortening counterexamples.
    Bit#(32) rvfi_insn; // [0 - 31] Instruction word: 32-bit instruction or command. The lower 16-bits
                        // may decode to a 16-bit compressed instruction.
} RVFI_DII_Instruction deriving (Bits, Eq, FShow);

typedef struct {
    Bit#(8)  padding;
    Bit#(8)  rvfi_cmd;  // [63] This token is a trace command.  For example, reset device under test.
    Bit#(16) rvfi_time; // [62 - 53] Time to inject token.  The difference between this and the previous
                        // instruction time gives a delay before injecting this instruction.
                        // This can be ignored for models but gives repeatability for implementations
                        // while shortening counterexamples.
    Bit#(32) rvfi_insn; // [0 - 31] Instruction word: 32-bit instruction or command. The lower 16-bits
                        // may decode to a 16-bit compressed instruction.
} RVFI_DII_Instruction_ByteStream deriving (Bits, Eq, FShow); // 8 bytes

function RVFI_DII_Instruction byteStream2rvfiInst(RVFI_DII_Instruction_ByteStream b);
  RVFI_DII_Instruction r = RVFI_DII_Instruction{
    rvfi_cmd:  b.rvfi_cmd==1,
    rvfi_time: truncate(b.rvfi_time),
    rvfi_insn: b.rvfi_insn
  };
  return r;
endfunction

// Convenience types for implementations.
typedef 8388608 MaxDepth;
typedef Bit#(TLog#(MaxDepth)) Dii_Id;
typedef Bit#(TAdd#(TLog#(MaxDepth), 1)) Dii_Parcel_Id;
Bit#(32) dii_nop = 'h01FFF033;

typedef union tagged {
    Bit#(16) DIIParcel;
    Bool     DIINoParcel;
} RVFI_DII_Parcel_Resp deriving (Bits, Eq, FShow);
