//
// Generated by Bluespec Compiler (build e7facc6)
//
// On Wed Mar 25 12:39:23 GMT 2020
//
//
// Ports:
// Name                         I/O  size props
// RDY_enq                        O     1
// RDY_deq                        O     1 reg
// first                          O    78
// RDY_first                      O     1 reg
// RDY_specUpdate_incorrectSpeculation  O     1 const
// RDY_specUpdate_correctSpeculation  O     1 const
// CLK                            I     1 clock
// RST_N                          I     1 reset
// enq_x                          I    78
// specUpdate_incorrectSpeculation_kill_all  I     1
// specUpdate_incorrectSpeculation_kill_tag  I     4
// specUpdate_correctSpeculation_mask  I    12
// EN_enq                         I     1
// EN_deq                         I     1
// EN_specUpdate_incorrectSpeculation  I     1
// EN_specUpdate_correctSpeculation  I     1
//
// Combinational paths from inputs to outputs:
//   (specUpdate_incorrectSpeculation_kill_all,
//    specUpdate_incorrectSpeculation_kill_tag,
//    EN_deq,
//    EN_specUpdate_incorrectSpeculation) -> RDY_enq
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

module mkFpuMulDivDispToRegFifo(CLK,
				RST_N,

				enq_x,
				EN_enq,
				RDY_enq,

				EN_deq,
				RDY_deq,

				first,
				RDY_first,

				specUpdate_incorrectSpeculation_kill_all,
				specUpdate_incorrectSpeculation_kill_tag,
				EN_specUpdate_incorrectSpeculation,
				RDY_specUpdate_incorrectSpeculation,

				specUpdate_correctSpeculation_mask,
				EN_specUpdate_correctSpeculation,
				RDY_specUpdate_correctSpeculation);
  input  CLK;
  input  RST_N;

  // action method enq
  input  [77 : 0] enq_x;
  input  EN_enq;
  output RDY_enq;

  // action method deq
  input  EN_deq;
  output RDY_deq;

  // value method first
  output [77 : 0] first;
  output RDY_first;

  // action method specUpdate_incorrectSpeculation
  input  specUpdate_incorrectSpeculation_kill_all;
  input  [3 : 0] specUpdate_incorrectSpeculation_kill_tag;
  input  EN_specUpdate_incorrectSpeculation;
  output RDY_specUpdate_incorrectSpeculation;

  // action method specUpdate_correctSpeculation
  input  [11 : 0] specUpdate_correctSpeculation_mask;
  input  EN_specUpdate_correctSpeculation;
  output RDY_specUpdate_correctSpeculation;

  // signals for module outputs
  wire [77 : 0] first;
  wire RDY_deq,
       RDY_enq,
       RDY_first,
       RDY_specUpdate_correctSpeculation,
       RDY_specUpdate_incorrectSpeculation;

  // inlined wires
  wire [11 : 0] m_m_specBits_0_lat_1$wget;
  wire m_m_valid_0_lat_0$whas;

  // register m_m_row_0
  reg [65 : 0] m_m_row_0;
  wire [65 : 0] m_m_row_0$D_IN;
  wire m_m_row_0$EN;

  // register m_m_specBits_0_rl
  reg [11 : 0] m_m_specBits_0_rl;
  wire [11 : 0] m_m_specBits_0_rl$D_IN;
  wire m_m_specBits_0_rl$EN;

  // register m_m_valid_0_rl
  reg m_m_valid_0_rl;
  wire m_m_valid_0_rl$D_IN, m_m_valid_0_rl$EN;

  // rule scheduling signals
  wire CAN_FIRE_RL_m_m_specBits_0_canon,
       CAN_FIRE_RL_m_m_valid_0_canon,
       CAN_FIRE_deq,
       CAN_FIRE_enq,
       CAN_FIRE_specUpdate_correctSpeculation,
       CAN_FIRE_specUpdate_incorrectSpeculation,
       WILL_FIRE_RL_m_m_specBits_0_canon,
       WILL_FIRE_RL_m_m_valid_0_canon,
       WILL_FIRE_deq,
       WILL_FIRE_enq,
       WILL_FIRE_specUpdate_correctSpeculation,
       WILL_FIRE_specUpdate_incorrectSpeculation;

  // inputs to muxes for submodule ports
  wire MUX_m_m_valid_0_lat_0$wset_1__SEL_1;

  // remaining internal signals
  reg [20 : 0] CASE_enq_x_BITS_77_TO_75_0_enq_x_BITS_77_TO_57_ETC__q4,
	       CASE_m_m_row_0_BITS_65_TO_63_0_m_m_row_0_BITS__ETC__q2;
  reg [2 : 0] CASE_enq_x_BITS_60_TO_58_0_enq_x_BITS_60_TO_58_ETC__q3,
	      CASE_m_m_row_0_BITS_48_TO_46_0_m_m_row_0_BITS__ETC__q1;
  wire [11 : 0] sb__h6699, upd__h1152;
  wire IF_m_m_valid_0_lat_0_whas_THEN_m_m_valid_0_lat_ETC___d6;

  // action method enq
  assign RDY_enq = m_m_valid_0_lat_0$whas ? !1'd0 : !m_m_valid_0_rl ;
  assign CAN_FIRE_enq = RDY_enq ;
  assign WILL_FIRE_enq = EN_enq ;

  // action method deq
  assign RDY_deq = m_m_valid_0_rl ;
  assign CAN_FIRE_deq = m_m_valid_0_rl ;
  assign WILL_FIRE_deq = EN_deq ;

  // value method first
  assign first =
	     { CASE_m_m_row_0_BITS_65_TO_63_0_m_m_row_0_BITS__ETC__q2,
	       m_m_row_0[44:0],
	       m_m_specBits_0_rl } ;
  assign RDY_first = m_m_valid_0_rl ;

  // action method specUpdate_incorrectSpeculation
  assign RDY_specUpdate_incorrectSpeculation = 1'd1 ;
  assign CAN_FIRE_specUpdate_incorrectSpeculation = 1'd1 ;
  assign WILL_FIRE_specUpdate_incorrectSpeculation =
	     EN_specUpdate_incorrectSpeculation ;

  // action method specUpdate_correctSpeculation
  assign RDY_specUpdate_correctSpeculation = 1'd1 ;
  assign CAN_FIRE_specUpdate_correctSpeculation = 1'd1 ;
  assign WILL_FIRE_specUpdate_correctSpeculation =
	     EN_specUpdate_correctSpeculation ;

  // rule RL_m_m_valid_0_canon
  assign CAN_FIRE_RL_m_m_valid_0_canon = 1'd1 ;
  assign WILL_FIRE_RL_m_m_valid_0_canon = 1'd1 ;

  // rule RL_m_m_specBits_0_canon
  assign CAN_FIRE_RL_m_m_specBits_0_canon = 1'd1 ;
  assign WILL_FIRE_RL_m_m_specBits_0_canon = 1'd1 ;

  // inputs to muxes for submodule ports
  assign MUX_m_m_valid_0_lat_0$wset_1__SEL_1 =
	     EN_specUpdate_incorrectSpeculation &&
	     (specUpdate_incorrectSpeculation_kill_all ||
	      m_m_specBits_0_rl[specUpdate_incorrectSpeculation_kill_tag]) ;

  // inlined wires
  assign m_m_valid_0_lat_0$whas =
	     MUX_m_m_valid_0_lat_0$wset_1__SEL_1 || EN_deq ;
  assign m_m_specBits_0_lat_1$wget =
	     sb__h6699 & specUpdate_correctSpeculation_mask ;

  // register m_m_row_0
  assign m_m_row_0$D_IN =
	     { CASE_enq_x_BITS_77_TO_75_0_enq_x_BITS_77_TO_57_ETC__q4,
	       enq_x[56:12] } ;
  assign m_m_row_0$EN = EN_enq ;

  // register m_m_specBits_0_rl
  assign m_m_specBits_0_rl$D_IN =
	     EN_specUpdate_correctSpeculation ? upd__h1152 : sb__h6699 ;
  assign m_m_specBits_0_rl$EN = 1'd1 ;

  // register m_m_valid_0_rl
  assign m_m_valid_0_rl$D_IN =
	     EN_enq ||
	     IF_m_m_valid_0_lat_0_whas_THEN_m_m_valid_0_lat_ETC___d6 ;
  assign m_m_valid_0_rl$EN = 1'd1 ;

  // remaining internal signals
  assign IF_m_m_valid_0_lat_0_whas_THEN_m_m_valid_0_lat_ETC___d6 =
	     m_m_valid_0_lat_0$whas ? 1'd0 : m_m_valid_0_rl ;
  assign sb__h6699 = EN_enq ? enq_x[11:0] : m_m_specBits_0_rl ;
  assign upd__h1152 = m_m_specBits_0_lat_1$wget ;
  always@(m_m_row_0)
  begin
    case (m_m_row_0[48:46])
      3'd0, 3'd1, 3'd2, 3'd3, 3'd4:
	  CASE_m_m_row_0_BITS_48_TO_46_0_m_m_row_0_BITS__ETC__q1 =
	      m_m_row_0[48:46];
      default: CASE_m_m_row_0_BITS_48_TO_46_0_m_m_row_0_BITS__ETC__q1 = 3'd7;
    endcase
  end
  always@(m_m_row_0 or CASE_m_m_row_0_BITS_48_TO_46_0_m_m_row_0_BITS__ETC__q1)
  begin
    case (m_m_row_0[65:63])
      3'd0, 3'd1, 3'd2, 3'd3:
	  CASE_m_m_row_0_BITS_65_TO_63_0_m_m_row_0_BITS__ETC__q2 =
	      m_m_row_0[65:45];
      3'd4:
	  CASE_m_m_row_0_BITS_65_TO_63_0_m_m_row_0_BITS__ETC__q2 =
	      { m_m_row_0[65:63],
		9'h0AA,
		m_m_row_0[53:49],
		CASE_m_m_row_0_BITS_48_TO_46_0_m_m_row_0_BITS__ETC__q1,
		m_m_row_0[45] };
      default: CASE_m_m_row_0_BITS_65_TO_63_0_m_m_row_0_BITS__ETC__q2 =
		   21'd1485482;
    endcase
  end
  always@(enq_x)
  begin
    case (enq_x[60:58])
      3'd0, 3'd1, 3'd2, 3'd3, 3'd4:
	  CASE_enq_x_BITS_60_TO_58_0_enq_x_BITS_60_TO_58_ETC__q3 =
	      enq_x[60:58];
      default: CASE_enq_x_BITS_60_TO_58_0_enq_x_BITS_60_TO_58_ETC__q3 = 3'd7;
    endcase
  end
  always@(enq_x or CASE_enq_x_BITS_60_TO_58_0_enq_x_BITS_60_TO_58_ETC__q3)
  begin
    case (enq_x[77:75])
      3'd0, 3'd1, 3'd2, 3'd3:
	  CASE_enq_x_BITS_77_TO_75_0_enq_x_BITS_77_TO_57_ETC__q4 =
	      enq_x[77:57];
      3'd4:
	  CASE_enq_x_BITS_77_TO_75_0_enq_x_BITS_77_TO_57_ETC__q4 =
	      { enq_x[77:75],
		9'h0AA,
		enq_x[65:61],
		CASE_enq_x_BITS_60_TO_58_0_enq_x_BITS_60_TO_58_ETC__q3,
		enq_x[57] };
      default: CASE_enq_x_BITS_77_TO_75_0_enq_x_BITS_77_TO_57_ETC__q4 =
		   21'd1485482;
    endcase
  end

  // handling of inlined registers

  always@(posedge CLK)
  begin
    if (RST_N == `BSV_RESET_VALUE)
      begin
        m_m_specBits_0_rl <= `BSV_ASSIGNMENT_DELAY 12'hAAA;
	m_m_valid_0_rl <= `BSV_ASSIGNMENT_DELAY 1'd0;
      end
    else
      begin
        if (m_m_specBits_0_rl$EN)
	  m_m_specBits_0_rl <= `BSV_ASSIGNMENT_DELAY m_m_specBits_0_rl$D_IN;
	if (m_m_valid_0_rl$EN)
	  m_m_valid_0_rl <= `BSV_ASSIGNMENT_DELAY m_m_valid_0_rl$D_IN;
      end
    if (m_m_row_0$EN) m_m_row_0 <= `BSV_ASSIGNMENT_DELAY m_m_row_0$D_IN;
  end

  // synopsys translate_off
  `ifdef BSV_NO_INITIAL_BLOCKS
  `else // not BSV_NO_INITIAL_BLOCKS
  initial
  begin
    m_m_row_0 = 66'h2AAAAAAAAAAAAAAAA;
    m_m_specBits_0_rl = 12'hAAA;
    m_m_valid_0_rl = 1'h0;
  end
  `endif // BSV_NO_INITIAL_BLOCKS
  // synopsys translate_on

  // handling of system tasks

  // synopsys translate_off
  always@(negedge CLK)
  begin
    #0;
    if (RST_N != `BSV_RESET_VALUE)
      if (EN_enq && IF_m_m_valid_0_lat_0_whas_THEN_m_m_valid_0_lat_ETC___d6)
	$fdisplay(32'h80000002, "\n%m: ASSERT FAIL!!");
    if (RST_N != `BSV_RESET_VALUE)
      if (EN_enq && !RDY_enq)
	$display("Dynamic assertion failed: \"../../src_Core/RISCY_OOO/procs/lib/SpecFifo.bsv\", line 147, column 34\nenq entry cannot be valid");
    if (RST_N != `BSV_RESET_VALUE) if (EN_enq && !RDY_enq) $finish(32'd0);
  end
  // synopsys translate_on
endmodule  // mkFpuMulDivDispToRegFifo

