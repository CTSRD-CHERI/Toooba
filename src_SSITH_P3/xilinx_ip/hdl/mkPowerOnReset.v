//
// Generated by Bluespec Compiler, version 2019.05.beta2 (build a88bf40db, 2019-05-24)
//
// On Wed Jun 24 20:23:22 BST 2020
//
//
// Ports:
// Name                         I/O  size props
// RST_N_gen_rst                  O     1 reset
// CLK                            I     1 clock
// RST_N                          I     1 unused
//
// No combinational paths from inputs to outputs
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

module mkPowerOnReset(CLK,
		      RST_N,

		      RST_N_gen_rst);
  input  CLK;
  input  RST_N;

  // output resets
  output RST_N_gen_rst;

  // signals for module outputs
  wire RST_N_gen_rst;

  // ports of submodule ctr
  wire [7 : 0] ctr$D_IN, ctr$Q_OUT;
  wire ctr$EN;

  // ports of submodule isInPowerOnReset
  wire isInPowerOnReset$D_IN, isInPowerOnReset$EN, isInPowerOnReset$Q_OUT;

  // ports of submodule rst_ifc
  wire rst_ifc$OUT;

  // rule scheduling signals
  wire CAN_FIRE_RL_countDown, WILL_FIRE_RL_countDown;

  // remaining internal signals
  wire NOT_isInPowerOnReset__read___d5;

  // output resets
  assign RST_N_gen_rst = rst_ifc$OUT ;

  // submodule ctr
  RegUNInit #(.width(32'd8), .init(8'd10)) ctr(.CLK(CLK),
					       .D_IN(ctr$D_IN),
					       .EN(ctr$EN),
					       .Q_OUT(ctr$Q_OUT));

  // submodule isInPowerOnReset
  RegUNInit #(.width(32'd1), .init(1'd1)) isInPowerOnReset(.CLK(CLK),
							   .D_IN(isInPowerOnReset$D_IN),
							   .EN(isInPowerOnReset$EN),
							   .Q_OUT(isInPowerOnReset$Q_OUT));

  // submodule rst_ifc
  ASSIGN1 rst_ifc(.IN(NOT_isInPowerOnReset__read___d5), .OUT(rst_ifc$OUT));

  // rule RL_countDown
  assign CAN_FIRE_RL_countDown = isInPowerOnReset$Q_OUT ;
  assign WILL_FIRE_RL_countDown = isInPowerOnReset$Q_OUT ;

  // submodule ctr
  assign ctr$D_IN = ctr$Q_OUT - 8'd1 ;
  assign ctr$EN = isInPowerOnReset$Q_OUT ;

  // submodule isInPowerOnReset
  assign isInPowerOnReset$D_IN = 1'd0 ;
  assign isInPowerOnReset$EN = isInPowerOnReset$Q_OUT && ctr$Q_OUT == 8'd1 ;

  // remaining internal signals
  assign NOT_isInPowerOnReset__read___d5 = !isInPowerOnReset$Q_OUT ;
endmodule  // mkPowerOnReset

