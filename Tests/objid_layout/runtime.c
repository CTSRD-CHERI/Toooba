#include "objid.h"
#include <cheri_init_globals.h>
volatile unsigned long long tohost __attribute__((aligned(64)));
volatile unsigned long *layout_raw;
volatile unsigned long layout_phase;
volatile unsigned long layout_expected;
void _start_purecap(void) {
    cheri_init_globals_3(__builtin_cheri_global_data_get(),
        __builtin_cheri_program_counter_get(), __builtin_cheri_global_data_get());
}
void _exit(int status) { for (;;) tohost = ((unsigned long long)(unsigned)status << 1) | 1; }
void fail(unsigned code) { _exit(0x40000000 | code); }
void handle_trap(unsigned long cause, unsigned long epc) {
    (void)epc;
    // An in-line failed store must return normally, without a trap.
#ifndef SILENT_INLINE_STORE
    if (cause == 28 && layout_phase == 3 && *layout_raw == layout_expected) _exit(0);
#endif
    fail(0x100 + (unsigned)cause);
}
int main(void);
void _init(int cid, int nc) { (void)cid; (void)nc; _exit(main()); }
