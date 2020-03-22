//
// Generated by Bluespec Compiler (build e7facc6)
//
// On Wed Mar 25 12:29:45 GMT 2020
//
//
// Ports:
// Name                         I/O  size props
// brAddrCalc                     O    64
// brAddrCalc_pc                  I    64
// brAddrCalc_val                 I    64
// brAddrCalc_iType               I     5
// brAddrCalc_imm                 I    64
// brAddrCalc_taken               I     1
// brAddrCalc_orig_inst           I    32
//
// Combinational paths from inputs to outputs:
//   (brAddrCalc_pc,
//    brAddrCalc_val,
//    brAddrCalc_iType,
//    brAddrCalc_imm,
//    brAddrCalc_taken,
//    brAddrCalc_orig_inst) -> brAddrCalc
//
//

`ifdef BSV_ASSIGNMENT_DELAY
`else
  `define BSV_ASSIGNMENT_DELAY
`endif

`ifdef BSV_POSITIVE_RESET
  `define BSV_RESET_VALUE 1'b1
  `define BSV_RESET_EDGE posedge
`else
  `define BSV_RESET_VALUE 1'b0
  `define BSV_RESET_EDGE negedge
`endif

module module_brAddrCalc(brAddrCalc_pc,
			 brAddrCalc_val,
			 brAddrCalc_iType,
			 brAddrCalc_imm,
			 brAddrCalc_taken,
			 brAddrCalc_orig_inst,
			 brAddrCalc);
  // value method brAddrCalc
  input  [63 : 0] brAddrCalc_pc;
  input  [63 : 0] brAddrCalc_val;
  input  [4 : 0] brAddrCalc_iType;
  input  [63 : 0] brAddrCalc_imm;
  input  brAddrCalc_taken;
  input  [31 : 0] brAddrCalc_orig_inst;
  output [63 : 0] brAddrCalc;

  // signals for module outputs
  reg [63 : 0] brAddrCalc;

  // remaining internal signals
  wire [63 : 0] brAddrCalc_pc_PLUS_brAddrCalc_imm___d2,
		brAddrCalc_val_PLUS_brAddrCalc_imm__q1,
		fallthrough_incr__h28,
		pcPlusN__h29;

  // value method brAddrCalc
  always@(brAddrCalc_iType or
	  pcPlusN__h29 or
	  brAddrCalc_pc_PLUS_brAddrCalc_imm___d2 or
	  brAddrCalc_val_PLUS_brAddrCalc_imm__q1 or brAddrCalc_taken)
  begin
    case (brAddrCalc_iType)
      5'd8: brAddrCalc = brAddrCalc_pc_PLUS_brAddrCalc_imm___d2;
      5'd9:
	  brAddrCalc = { brAddrCalc_val_PLUS_brAddrCalc_imm__q1[63:1], 1'b0 };
      5'd10:
	  brAddrCalc =
	      brAddrCalc_taken ?
		brAddrCalc_pc_PLUS_brAddrCalc_imm___d2 :
		pcPlusN__h29;
      default: brAddrCalc = pcPlusN__h29;
    endcase
  end

  // remaining internal signals
  assign brAddrCalc_pc_PLUS_brAddrCalc_imm___d2 =
	     brAddrCalc_pc + brAddrCalc_imm ;
  assign brAddrCalc_val_PLUS_brAddrCalc_imm__q1 =
	     brAddrCalc_val + brAddrCalc_imm ;
  assign fallthrough_incr__h28 =
	     (brAddrCalc_orig_inst[1:0] == 2'b11) ? 64'd4 : 64'd2 ;
  assign pcPlusN__h29 = brAddrCalc_pc + fallthrough_incr__h28 ;
endmodule  // module_brAddrCalc

