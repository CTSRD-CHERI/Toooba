//#include <stdio.h>
#include <stdint.h>

#include "encoding.h"

int benchmark();

extern void _exit(int);
extern void exit(int);

#ifndef RUNS
#define RUNS 1
#endif

// Capture the current 64-bit cycle count.
uint64_t get_cycle_count() {
  return read_csr(mcycle);
}

int main(void)
{
  int run;
  uint64_t t_start, t_end;
  uint64_t test_duration_cycles;

  t_start = get_cycle_count();
  for(run = 0; run < 1; ++run)
  {
    //puts("Trial\n\r");
    //printf("Run %d\n\r", run+1);
    if (benchmark() != 0) {
      _exit(1);
    }
  }
  t_end = get_cycle_count();

  // Calculate and report benchmark duration.
  test_duration_cycles = t_end - t_start;

  _exit(test_duration_cycles);

  return 0; // Not going to run.
}

//#define printf(...)
#define fprintf(...)
#define fflush(...)
#define main(...) benchmark(__VA_ARGS__)
