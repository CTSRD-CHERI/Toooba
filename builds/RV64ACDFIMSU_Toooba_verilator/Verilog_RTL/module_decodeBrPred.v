//
// Generated by Bluespec Compiler (build e7facc6)
//
// On Wed Mar 25 12:33:26 GMT 2020
//
//
// Ports:
// Name                         I/O  size props
// decodeBrPred                   O    65
// decodeBrPred_pc                I    64
// decodeBrPred_dInst             I    72
// decodeBrPred_histTaken         I     1
// decodeBrPred_is_32b_inst       I     1
//
// Combinational paths from inputs to outputs:
//   (decodeBrPred_pc,
//    decodeBrPred_dInst,
//    decodeBrPred_histTaken,
//    decodeBrPred_is_32b_inst) -> decodeBrPred
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

module module_decodeBrPred(decodeBrPred_pc,
			   decodeBrPred_dInst,
			   decodeBrPred_histTaken,
			   decodeBrPred_is_32b_inst,
			   decodeBrPred);
  // value method decodeBrPred
  input  [63 : 0] decodeBrPred_pc;
  input  [71 : 0] decodeBrPred_dInst;
  input  decodeBrPred_histTaken;
  input  decodeBrPred_is_32b_inst;
  output [64 : 0] decodeBrPred;

  // signals for module outputs
  wire [64 : 0] decodeBrPred;

  // remaining internal signals
  reg [63 : 0] CASE_decodeBrPred_dInst_BITS_71_TO_67_8_jTarge_ETC__q2;
  wire [63 : 0] imm_val__h25, jTarget__h45, pcPlusN__h24;
  wire [31 : 0] decodeBrPred_dInst_BITS_31_TO_0__q1;

  // value method decodeBrPred
  assign decodeBrPred =
	     { decodeBrPred_dInst[71:67] != 5'd9,
	       CASE_decodeBrPred_dInst_BITS_71_TO_67_8_jTarge_ETC__q2 } ;

  // remaining internal signals
  assign decodeBrPred_dInst_BITS_31_TO_0__q1 = decodeBrPred_dInst[31:0] ;
  assign imm_val__h25 =
	     { {32{decodeBrPred_dInst_BITS_31_TO_0__q1[31]}},
	       decodeBrPred_dInst_BITS_31_TO_0__q1 } ;
  assign jTarget__h45 = decodeBrPred_pc + imm_val__h25 ;
  assign pcPlusN__h24 =
	     decodeBrPred_pc + (decodeBrPred_is_32b_inst ? 64'd4 : 64'd2) ;
  always@(decodeBrPred_dInst or
	  pcPlusN__h24 or jTarget__h45 or decodeBrPred_histTaken)
  begin
    case (decodeBrPred_dInst[71:67])
      5'd8:
	  CASE_decodeBrPred_dInst_BITS_71_TO_67_8_jTarge_ETC__q2 =
	      jTarget__h45;
      5'd10:
	  CASE_decodeBrPred_dInst_BITS_71_TO_67_8_jTarge_ETC__q2 =
	      decodeBrPred_histTaken ? jTarget__h45 : pcPlusN__h24;
      default: CASE_decodeBrPred_dInst_BITS_71_TO_67_8_jTarge_ETC__q2 =
		   pcPlusN__h24;
    endcase
  end
endmodule  // module_decodeBrPred

