//
// Generated by Bluespec Compiler, version 2019.05.beta2 (build a88bf40db, 2019-05-24)
//
// On Mon Jun 29 23:54:34 BST 2020
//
//
// Ports:
// Name                         I/O  size props
// RDY_enq                        O     1
// RDY_deq                        O     1 reg
// first                          O   231
// RDY_first                      O     1 reg
// RDY_specUpdate_incorrectSpeculation  O     1 const
// RDY_specUpdate_correctSpeculation  O     1 const
// CLK                            I     1 clock
// RST_N                          I     1 reset
// enq_x                          I   231
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

module mkAluDispToRegFifo(CLK,
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
  input  [230 : 0] enq_x;
  input  EN_enq;
  output RDY_enq;

  // action method deq
  input  EN_deq;
  output RDY_deq;

  // value method first
  output [230 : 0] first;
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
  wire [230 : 0] first;
  wire RDY_deq,
       RDY_enq,
       RDY_first,
       RDY_specUpdate_correctSpeculation,
       RDY_specUpdate_incorrectSpeculation;

  // inlined wires
  wire [11 : 0] m_m_specBits_0_lat_1$wget;
  wire m_m_valid_0_lat_0$whas;

  // register m_m_row_0
  reg [218 : 0] m_m_row_0;
  wire [218 : 0] m_m_row_0$D_IN;
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
  reg [29 : 0] CASE_enq_x_BITS_225_TO_223_0_enq_x_BITS_225_TO_ETC__q4,
	       CASE_m_m_row_0_BITS_213_TO_211_0_m_m_row_0_BIT_ETC__q11;
  reg [11 : 0] CASE_enq_x_BITS_136_TO_125_1_enq_x_BITS_136_TO_ETC__q6,
	       CASE_m_m_row_0_BITS_124_TO_113_1_m_m_row_0_BIT_ETC__q13;
  reg [10 : 0] CASE_enq_x_BITS_195_TO_194_0_enq_x_BITS_195_TO_ETC__q5,
	       CASE_m_m_row_0_BITS_183_TO_182_0_m_m_row_0_BIT_ETC__q12;
  reg [4 : 0] CASE_enq_x_BITS_123_TO_119_0_enq_x_BITS_123_TO_ETC__q7,
	      CASE_m_m_row_0_BITS_111_TO_107_0_m_m_row_0_BIT_ETC__q14;
  reg [3 : 0] CASE_IF_enq_x_BITS_193_TO_190_8_EQ_7_2_OR_enq__ETC__q2,
	      CASE_IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_7_5_ETC__q9,
	      IF_enq_x_BITS_193_TO_190_8_EQ_7_2_OR_enq_x_BIT_ETC___d71,
	      IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_7_57_OR__ETC___d366;
  reg [2 : 0] CASE_IF_enq_x_BITS_189_TO_187_6_EQ_2_00_OR_enq_ETC__q1,
	      CASE_IF_m_m_row_0_10_BITS_177_TO_175_91_EQ_2_9_ETC__q8,
	      CASE_enq_x_BITS_199_TO_197_0_enq_x_BITS_199_TO_ETC__q3,
	      CASE_m_m_row_0_BITS_187_TO_185_0_m_m_row_0_BIT_ETC__q10,
	      IF_enq_x_BITS_189_TO_187_6_EQ_2_00_OR_enq_x_BI_ETC___d103,
	      IF_m_m_row_0_10_BITS_177_TO_175_91_EQ_2_95_OR__ETC___d398;
  wire [11 : 0] sb__h11948, upd__h1154;
  wire [8 : 0] IF_enq_x_BITS_193_TO_190_8_EQ_0_9_OR_NOT_enq_x_ETC___d155,
	       IF_enq_x_BITS_193_TO_190_8_EQ_1_0_OR_NOT_enq_x_ETC___d154,
	       IF_enq_x_BITS_193_TO_190_8_EQ_2_2_OR_NOT_enq_x_ETC___d153,
	       IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_0_44_OR__ETC___d448,
	       IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_1_45_OR__ETC___d447,
	       IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_2_47_OR__ETC___d446;

  // action method enq
  assign RDY_enq = m_m_valid_0_lat_0$whas ? !1'd0 : !m_m_valid_0_rl ;
  assign CAN_FIRE_enq = m_m_valid_0_lat_0$whas ? !1'd0 : !m_m_valid_0_rl ;
  assign WILL_FIRE_enq = EN_enq ;

  // action method deq
  assign RDY_deq = m_m_valid_0_rl ;
  assign CAN_FIRE_deq = m_m_valid_0_rl ;
  assign WILL_FIRE_deq = EN_deq ;

  // value method first
  assign first =
	     { m_m_row_0[218:214],
	       CASE_m_m_row_0_BITS_213_TO_211_0_m_m_row_0_BIT_ETC__q11,
	       CASE_m_m_row_0_BITS_183_TO_182_0_m_m_row_0_BIT_ETC__q12,
	       m_m_row_0[172:125],
	       CASE_m_m_row_0_BITS_124_TO_113_1_m_m_row_0_BIT_ETC__q13,
	       m_m_row_0[112],
	       CASE_m_m_row_0_BITS_111_TO_107_0_m_m_row_0_BIT_ETC__q14,
	       m_m_row_0[106:0],
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
	     sb__h11948 & specUpdate_correctSpeculation_mask ;

  // register m_m_row_0
  assign m_m_row_0$D_IN =
	     { enq_x[230:226],
	       CASE_enq_x_BITS_225_TO_223_0_enq_x_BITS_225_TO_ETC__q4,
	       CASE_enq_x_BITS_195_TO_194_0_enq_x_BITS_195_TO_ETC__q5,
	       enq_x[184:137],
	       CASE_enq_x_BITS_136_TO_125_1_enq_x_BITS_136_TO_ETC__q6,
	       enq_x[124],
	       CASE_enq_x_BITS_123_TO_119_0_enq_x_BITS_123_TO_ETC__q7,
	       enq_x[118:12] } ;
  assign m_m_row_0$EN = EN_enq ;

  // register m_m_specBits_0_rl
  assign m_m_specBits_0_rl$D_IN =
	     EN_specUpdate_correctSpeculation ? upd__h1154 : sb__h11948 ;
  assign m_m_specBits_0_rl$EN = 1'd1 ;

  // register m_m_valid_0_rl
  assign m_m_valid_0_rl$D_IN =
	     EN_enq || (m_m_valid_0_lat_0$whas ? 1'd0 : m_m_valid_0_rl) ;
  assign m_m_valid_0_rl$EN = 1'd1 ;

  // remaining internal signals
  assign IF_enq_x_BITS_193_TO_190_8_EQ_0_9_OR_NOT_enq_x_ETC___d155 =
	     (enq_x[193:190] == 4'd0 ||
	      enq_x[193:190] != 4'd1 && enq_x[193:190] != 4'd2 &&
	      enq_x[193:190] != 4'd3 &&
	      enq_x[193:190] != 4'd4 &&
	      enq_x[193:190] != 4'd5 &&
	      enq_x[193:190] != 4'd6 &&
	      IF_enq_x_BITS_193_TO_190_8_EQ_7_2_OR_enq_x_BIT_ETC___d71 ==
	      4'd0) ?
	       { 4'd0, enq_x[189:185] } :
	       IF_enq_x_BITS_193_TO_190_8_EQ_1_0_OR_NOT_enq_x_ETC___d154 ;
  assign IF_enq_x_BITS_193_TO_190_8_EQ_1_0_OR_NOT_enq_x_ETC___d154 =
	     (enq_x[193:190] == 4'd1 ||
	      enq_x[193:190] != 4'd2 && enq_x[193:190] != 4'd3 &&
	      enq_x[193:190] != 4'd4 &&
	      enq_x[193:190] != 4'd5 &&
	      enq_x[193:190] != 4'd6 &&
	      IF_enq_x_BITS_193_TO_190_8_EQ_7_2_OR_enq_x_BIT_ETC___d71 ==
	      4'd1) ?
	       { 4'd1, enq_x[189:185] } :
	       IF_enq_x_BITS_193_TO_190_8_EQ_2_2_OR_NOT_enq_x_ETC___d153 ;
  assign IF_enq_x_BITS_193_TO_190_8_EQ_2_2_OR_NOT_enq_x_ETC___d153 =
	     (enq_x[193:190] == 4'd2 ||
	      enq_x[193:190] != 4'd3 && enq_x[193:190] != 4'd4 &&
	      enq_x[193:190] != 4'd5 &&
	      enq_x[193:190] != 4'd6 &&
	      IF_enq_x_BITS_193_TO_190_8_EQ_7_2_OR_enq_x_BIT_ETC___d71 ==
	      4'd2) ?
	       { 4'd2,
		 (enq_x[189:187] == 3'd0 ||
		  enq_x[189:187] != 3'd1 &&
		  IF_enq_x_BITS_189_TO_187_6_EQ_2_00_OR_enq_x_BI_ETC___d103 ==
		  3'd0) ?
		   { 3'd0, enq_x[186:185] } :
		   ((enq_x[189:187] == 3'd1 ||
		     IF_enq_x_BITS_189_TO_187_6_EQ_2_00_OR_enq_x_BI_ETC___d103 ==
		     3'd1) ?
		      { 3'd1, enq_x[186:185] } :
		      { CASE_IF_enq_x_BITS_189_TO_187_6_EQ_2_00_OR_enq_ETC__q1,
			2'h2 }) } :
	       ((enq_x[193:190] == 4'd3 ||
		 enq_x[193:190] != 4'd4 && enq_x[193:190] != 4'd5 &&
		 enq_x[193:190] != 4'd6 &&
		 IF_enq_x_BITS_193_TO_190_8_EQ_7_2_OR_enq_x_BIT_ETC___d71 ==
		 4'd3) ?
		  { 4'd3, enq_x[189:185] } :
		  ((enq_x[193:190] == 4'd4 ||
		    enq_x[193:190] != 4'd5 && enq_x[193:190] != 4'd6 &&
		    IF_enq_x_BITS_193_TO_190_8_EQ_7_2_OR_enq_x_BIT_ETC___d71 ==
		    4'd4) ?
		     9'd138 :
		     ((enq_x[193:190] == 4'd5 ||
		       enq_x[193:190] != 4'd6 &&
		       IF_enq_x_BITS_193_TO_190_8_EQ_7_2_OR_enq_x_BIT_ETC___d71 ==
		       4'd5) ?
			9'd170 :
			((enq_x[193:190] == 4'd6 ||
			  IF_enq_x_BITS_193_TO_190_8_EQ_7_2_OR_enq_x_BIT_ETC___d71 ==
			  4'd6) ?
			   { 4'd6, enq_x[189:185] } :
			   { CASE_IF_enq_x_BITS_193_TO_190_8_EQ_7_2_OR_enq__ETC__q2,
			     5'h0A })))) ;
  assign IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_0_44_OR__ETC___d448 =
	     (m_m_row_0[181:178] == 4'd0 ||
	      m_m_row_0[181:178] != 4'd1 && m_m_row_0[181:178] != 4'd2 &&
	      m_m_row_0[181:178] != 4'd3 &&
	      m_m_row_0[181:178] != 4'd4 &&
	      m_m_row_0[181:178] != 4'd5 &&
	      m_m_row_0[181:178] != 4'd6 &&
	      IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_7_57_OR__ETC___d366 ==
	      4'd0) ?
	       { 4'd0, m_m_row_0[177:173] } :
	       IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_1_45_OR__ETC___d447 ;
  assign IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_1_45_OR__ETC___d447 =
	     (m_m_row_0[181:178] == 4'd1 ||
	      m_m_row_0[181:178] != 4'd2 && m_m_row_0[181:178] != 4'd3 &&
	      m_m_row_0[181:178] != 4'd4 &&
	      m_m_row_0[181:178] != 4'd5 &&
	      m_m_row_0[181:178] != 4'd6 &&
	      IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_7_57_OR__ETC___d366 ==
	      4'd1) ?
	       { 4'd1, m_m_row_0[177:173] } :
	       IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_2_47_OR__ETC___d446 ;
  assign IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_2_47_OR__ETC___d446 =
	     (m_m_row_0[181:178] == 4'd2 ||
	      m_m_row_0[181:178] != 4'd3 && m_m_row_0[181:178] != 4'd4 &&
	      m_m_row_0[181:178] != 4'd5 &&
	      m_m_row_0[181:178] != 4'd6 &&
	      IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_7_57_OR__ETC___d366 ==
	      4'd2) ?
	       { 4'd2,
		 (m_m_row_0[177:175] == 3'd0 ||
		  m_m_row_0[177:175] != 3'd1 &&
		  IF_m_m_row_0_10_BITS_177_TO_175_91_EQ_2_95_OR__ETC___d398 ==
		  3'd0) ?
		   { 3'd0, m_m_row_0[174:173] } :
		   ((m_m_row_0[177:175] == 3'd1 ||
		     IF_m_m_row_0_10_BITS_177_TO_175_91_EQ_2_95_OR__ETC___d398 ==
		     3'd1) ?
		      { 3'd1, m_m_row_0[174:173] } :
		      { CASE_IF_m_m_row_0_10_BITS_177_TO_175_91_EQ_2_9_ETC__q8,
			2'h2 }) } :
	       ((m_m_row_0[181:178] == 4'd3 ||
		 m_m_row_0[181:178] != 4'd4 && m_m_row_0[181:178] != 4'd5 &&
		 m_m_row_0[181:178] != 4'd6 &&
		 IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_7_57_OR__ETC___d366 ==
		 4'd3) ?
		  { 4'd3, m_m_row_0[177:173] } :
		  ((m_m_row_0[181:178] == 4'd4 ||
		    m_m_row_0[181:178] != 4'd5 &&
		    m_m_row_0[181:178] != 4'd6 &&
		    IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_7_57_OR__ETC___d366 ==
		    4'd4) ?
		     9'd138 :
		     ((m_m_row_0[181:178] == 4'd5 ||
		       m_m_row_0[181:178] != 4'd6 &&
		       IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_7_57_OR__ETC___d366 ==
		       4'd5) ?
			9'd170 :
			((m_m_row_0[181:178] == 4'd6 ||
			  IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_7_57_OR__ETC___d366 ==
			  4'd6) ?
			   { 4'd6, m_m_row_0[177:173] } :
			   { CASE_IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_7_5_ETC__q9,
			     5'h0A })))) ;
  assign sb__h11948 = EN_enq ? enq_x[11:0] : m_m_specBits_0_rl ;
  assign upd__h1154 = m_m_specBits_0_lat_1$wget ;
  always@(enq_x)
  begin
    case (enq_x[193:190])
      4'd7, 4'd8, 4'd9, 4'd10, 4'd11:
	  IF_enq_x_BITS_193_TO_190_8_EQ_7_2_OR_enq_x_BIT_ETC___d71 =
	      enq_x[193:190];
      default: IF_enq_x_BITS_193_TO_190_8_EQ_7_2_OR_enq_x_BIT_ETC___d71 =
		   4'd12;
    endcase
  end
  always@(enq_x)
  begin
    case (enq_x[189:187])
      3'd2, 3'd3:
	  IF_enq_x_BITS_189_TO_187_6_EQ_2_00_OR_enq_x_BI_ETC___d103 =
	      enq_x[189:187];
      default: IF_enq_x_BITS_189_TO_187_6_EQ_2_00_OR_enq_x_BI_ETC___d103 =
		   3'd4;
    endcase
  end
  always@(m_m_row_0)
  begin
    case (m_m_row_0[181:178])
      4'd7, 4'd8, 4'd9, 4'd10, 4'd11:
	  IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_7_57_OR__ETC___d366 =
	      m_m_row_0[181:178];
      default: IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_7_57_OR__ETC___d366 =
		   4'd12;
    endcase
  end
  always@(m_m_row_0)
  begin
    case (m_m_row_0[177:175])
      3'd2, 3'd3:
	  IF_m_m_row_0_10_BITS_177_TO_175_91_EQ_2_95_OR__ETC___d398 =
	      m_m_row_0[177:175];
      default: IF_m_m_row_0_10_BITS_177_TO_175_91_EQ_2_95_OR__ETC___d398 =
		   3'd4;
    endcase
  end
  always@(IF_enq_x_BITS_189_TO_187_6_EQ_2_00_OR_enq_x_BI_ETC___d103)
  begin
    case (IF_enq_x_BITS_189_TO_187_6_EQ_2_00_OR_enq_x_BI_ETC___d103)
      3'd2, 3'd3:
	  CASE_IF_enq_x_BITS_189_TO_187_6_EQ_2_00_OR_enq_ETC__q1 =
	      IF_enq_x_BITS_189_TO_187_6_EQ_2_00_OR_enq_x_BI_ETC___d103;
      default: CASE_IF_enq_x_BITS_189_TO_187_6_EQ_2_00_OR_enq_ETC__q1 = 3'd4;
    endcase
  end
  always@(IF_enq_x_BITS_193_TO_190_8_EQ_7_2_OR_enq_x_BIT_ETC___d71)
  begin
    case (IF_enq_x_BITS_193_TO_190_8_EQ_7_2_OR_enq_x_BIT_ETC___d71)
      4'd7, 4'd8, 4'd9, 4'd10, 4'd11:
	  CASE_IF_enq_x_BITS_193_TO_190_8_EQ_7_2_OR_enq__ETC__q2 =
	      IF_enq_x_BITS_193_TO_190_8_EQ_7_2_OR_enq_x_BIT_ETC___d71;
      default: CASE_IF_enq_x_BITS_193_TO_190_8_EQ_7_2_OR_enq__ETC__q2 = 4'd12;
    endcase
  end
  always@(enq_x)
  begin
    case (enq_x[199:197])
      3'd0, 3'd1, 3'd2, 3'd3, 3'd4:
	  CASE_enq_x_BITS_199_TO_197_0_enq_x_BITS_199_TO_ETC__q3 =
	      enq_x[199:197];
      default: CASE_enq_x_BITS_199_TO_197_0_enq_x_BITS_199_TO_ETC__q3 = 3'd7;
    endcase
  end
  always@(enq_x or CASE_enq_x_BITS_199_TO_197_0_enq_x_BITS_199_TO_ETC__q3)
  begin
    case (enq_x[225:223])
      3'd0, 3'd1, 3'd2, 3'd3:
	  CASE_enq_x_BITS_225_TO_223_0_enq_x_BITS_225_TO_ETC__q4 =
	      enq_x[225:196];
      3'd4:
	  CASE_enq_x_BITS_225_TO_223_0_enq_x_BITS_225_TO_ETC__q4 =
	      { enq_x[225:223],
		18'h2AAAA,
		enq_x[204:200],
		CASE_enq_x_BITS_199_TO_197_0_enq_x_BITS_199_TO_ETC__q3,
		enq_x[196] };
      default: CASE_enq_x_BITS_225_TO_223_0_enq_x_BITS_225_TO_ETC__q4 =
		   30'd715827882;
    endcase
  end
  always@(enq_x or IF_enq_x_BITS_193_TO_190_8_EQ_0_9_OR_NOT_enq_x_ETC___d155)
  begin
    case (enq_x[195:194])
      2'd0:
	  CASE_enq_x_BITS_195_TO_194_0_enq_x_BITS_195_TO_ETC__q5 =
	      enq_x[195:185];
      2'd1:
	  CASE_enq_x_BITS_195_TO_194_0_enq_x_BITS_195_TO_ETC__q5 =
	      { enq_x[195:194],
		IF_enq_x_BITS_193_TO_190_8_EQ_0_9_OR_NOT_enq_x_ETC___d155 };
      default: CASE_enq_x_BITS_195_TO_194_0_enq_x_BITS_195_TO_ETC__q5 =
		   11'd1194;
    endcase
  end
  always@(enq_x)
  begin
    case (enq_x[136:125])
      12'd1,
      12'd2,
      12'd3,
      12'd256,
      12'd260,
      12'd261,
      12'd262,
      12'd320,
      12'd321,
      12'd322,
      12'd323,
      12'd324,
      12'd384,
      12'd768,
      12'd769,
      12'd770,
      12'd771,
      12'd772,
      12'd773,
      12'd774,
      12'd832,
      12'd833,
      12'd834,
      12'd835,
      12'd836,
      12'd1952,
      12'd1953,
      12'd1954,
      12'd1955,
      12'd1968,
      12'd1969,
      12'd1970,
      12'd1971,
      12'd2048,
      12'd2049,
      12'd2496,
      12'd2816,
      12'd2818,
      12'd3008,
      12'd3072,
      12'd3073,
      12'd3074,
      12'd3857,
      12'd3858,
      12'd3859,
      12'd3860:
	  CASE_enq_x_BITS_136_TO_125_1_enq_x_BITS_136_TO_ETC__q6 =
	      enq_x[136:125];
      default: CASE_enq_x_BITS_136_TO_125_1_enq_x_BITS_136_TO_ETC__q6 =
		   12'd2303;
    endcase
  end
  always@(enq_x)
  begin
    case (enq_x[123:119])
      5'd0, 5'd1, 5'd12, 5'd13, 5'd14, 5'd15, 5'd28, 5'd29, 5'd30, 5'd31:
	  CASE_enq_x_BITS_123_TO_119_0_enq_x_BITS_123_TO_ETC__q7 =
	      enq_x[123:119];
      default: CASE_enq_x_BITS_123_TO_119_0_enq_x_BITS_123_TO_ETC__q7 = 5'd10;
    endcase
  end
  always@(IF_m_m_row_0_10_BITS_177_TO_175_91_EQ_2_95_OR__ETC___d398)
  begin
    case (IF_m_m_row_0_10_BITS_177_TO_175_91_EQ_2_95_OR__ETC___d398)
      3'd2, 3'd3:
	  CASE_IF_m_m_row_0_10_BITS_177_TO_175_91_EQ_2_9_ETC__q8 =
	      IF_m_m_row_0_10_BITS_177_TO_175_91_EQ_2_95_OR__ETC___d398;
      default: CASE_IF_m_m_row_0_10_BITS_177_TO_175_91_EQ_2_9_ETC__q8 = 3'd4;
    endcase
  end
  always@(IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_7_57_OR__ETC___d366)
  begin
    case (IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_7_57_OR__ETC___d366)
      4'd7, 4'd8, 4'd9, 4'd10, 4'd11:
	  CASE_IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_7_5_ETC__q9 =
	      IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_7_57_OR__ETC___d366;
      default: CASE_IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_7_5_ETC__q9 = 4'd12;
    endcase
  end
  always@(m_m_row_0)
  begin
    case (m_m_row_0[187:185])
      3'd0, 3'd1, 3'd2, 3'd3, 3'd4:
	  CASE_m_m_row_0_BITS_187_TO_185_0_m_m_row_0_BIT_ETC__q10 =
	      m_m_row_0[187:185];
      default: CASE_m_m_row_0_BITS_187_TO_185_0_m_m_row_0_BIT_ETC__q10 = 3'd7;
    endcase
  end
  always@(m_m_row_0 or
	  CASE_m_m_row_0_BITS_187_TO_185_0_m_m_row_0_BIT_ETC__q10)
  begin
    case (m_m_row_0[213:211])
      3'd0, 3'd1, 3'd2, 3'd3:
	  CASE_m_m_row_0_BITS_213_TO_211_0_m_m_row_0_BIT_ETC__q11 =
	      m_m_row_0[213:184];
      3'd4:
	  CASE_m_m_row_0_BITS_213_TO_211_0_m_m_row_0_BIT_ETC__q11 =
	      { m_m_row_0[213:211],
		18'h2AAAA,
		m_m_row_0[192:188],
		CASE_m_m_row_0_BITS_187_TO_185_0_m_m_row_0_BIT_ETC__q10,
		m_m_row_0[184] };
      default: CASE_m_m_row_0_BITS_213_TO_211_0_m_m_row_0_BIT_ETC__q11 =
		   30'd715827882;
    endcase
  end
  always@(m_m_row_0 or
	  IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_0_44_OR__ETC___d448)
  begin
    case (m_m_row_0[183:182])
      2'd0:
	  CASE_m_m_row_0_BITS_183_TO_182_0_m_m_row_0_BIT_ETC__q12 =
	      m_m_row_0[183:173];
      2'd1:
	  CASE_m_m_row_0_BITS_183_TO_182_0_m_m_row_0_BIT_ETC__q12 =
	      { m_m_row_0[183:182],
		IF_m_m_row_0_10_BITS_181_TO_178_43_EQ_0_44_OR__ETC___d448 };
      default: CASE_m_m_row_0_BITS_183_TO_182_0_m_m_row_0_BIT_ETC__q12 =
		   11'd1194;
    endcase
  end
  always@(m_m_row_0)
  begin
    case (m_m_row_0[124:113])
      12'd1,
      12'd2,
      12'd3,
      12'd256,
      12'd260,
      12'd261,
      12'd262,
      12'd320,
      12'd321,
      12'd322,
      12'd323,
      12'd324,
      12'd384,
      12'd768,
      12'd769,
      12'd770,
      12'd771,
      12'd772,
      12'd773,
      12'd774,
      12'd832,
      12'd833,
      12'd834,
      12'd835,
      12'd836,
      12'd1952,
      12'd1953,
      12'd1954,
      12'd1955,
      12'd1968,
      12'd1969,
      12'd1970,
      12'd1971,
      12'd2048,
      12'd2049,
      12'd2496,
      12'd2816,
      12'd2818,
      12'd3008,
      12'd3072,
      12'd3073,
      12'd3074,
      12'd3857,
      12'd3858,
      12'd3859,
      12'd3860:
	  CASE_m_m_row_0_BITS_124_TO_113_1_m_m_row_0_BIT_ETC__q13 =
	      m_m_row_0[124:113];
      default: CASE_m_m_row_0_BITS_124_TO_113_1_m_m_row_0_BIT_ETC__q13 =
		   12'd2303;
    endcase
  end
  always@(m_m_row_0)
  begin
    case (m_m_row_0[111:107])
      5'd0, 5'd1, 5'd12, 5'd13, 5'd14, 5'd15, 5'd28, 5'd29, 5'd30, 5'd31:
	  CASE_m_m_row_0_BITS_111_TO_107_0_m_m_row_0_BIT_ETC__q14 =
	      m_m_row_0[111:107];
      default: CASE_m_m_row_0_BITS_111_TO_107_0_m_m_row_0_BIT_ETC__q14 =
		   5'd10;
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
    m_m_row_0 = 219'h2AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA;
    m_m_specBits_0_rl = 12'hAAA;
    m_m_valid_0_rl = 1'h0;
  end
  `endif // BSV_NO_INITIAL_BLOCKS
  // synopsys translate_on
endmodule  // mkAluDispToRegFifo

