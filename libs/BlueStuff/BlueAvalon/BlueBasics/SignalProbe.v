module SignalProbe (clk, sig, RST);
  parameter N = 1;
  input sig;
  input clk;
  input RST;
  (* preserve, noprune *) reg [N-1:0] sig_reg;
  always @(posedge clk) sig_reg <= sig;
endmodule
