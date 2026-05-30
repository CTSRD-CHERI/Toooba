package SignalProbe;

export mkSignalProbe;

module mkSignalProbe #(t x) (Empty) provisos (Bits #(t, t_sz));
  if (genVerilog) vSignalProbe (x);
endmodule

import "BVI" SignalProbe =
  module vSignalProbe #(t x) (Empty) provisos (Bits #(t, n));
  parameter N = valueOf (n);
  port sig = pack (x);
  default_clock dClk (clk);
endmodule

endpackage
