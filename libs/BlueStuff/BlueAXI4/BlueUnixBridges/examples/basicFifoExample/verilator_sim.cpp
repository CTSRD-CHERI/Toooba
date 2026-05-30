#include <verilated.h>

#include "VtestUnixFifo.h"
VtestUnixFifo *top;
vluint64_t main_time = 0;
// Called by $time in Verilog
double sc_time_stamp () {
  return main_time;
}
int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  top = new VtestUnixFifo;
  top->RST_N = 1;
  top->CLK = 0;
  // main simulation loop
  while (! Verilated::gotFinish ()) {
    if (main_time == 2) {
      top->RST_N = 0; // assert reset
    }
    else if (main_time == 7) {
      top->RST_N = 1; // Deassert reset
    }
    // Toggle clock
    if ((main_time % 10) == 5) {
      top->CLK = 1;
    }
    else if ((main_time % 10) == 0) {
      top->CLK = 0;
    }
    top->eval ();
    main_time++;
  }
  top->final(); delete top; return 0;
}
