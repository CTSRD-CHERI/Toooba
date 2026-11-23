#include "objid.h"
#ifndef MODE
#define MODE 3
#endif
#ifndef LOC
#define LOC 0
#endif
#ifndef DATA_OFFSET
#define DATA_OFFSET 0
#endif
#ifndef NEW_ID
#define NEW_ID 2
#endif
// Room for all layouts, including 512 KiB regions and same-line wrapping tests.
static unsigned char region[1024*1024] __attribute__((aligned(512*1024)));
extern volatile unsigned long *layout_raw;
extern volatile unsigned long layout_phase;
extern volatile unsigned long layout_expected;
static void sync_memory(void) { __asm__ volatile("fence rw,rw" ::: "memory"); }
static __attribute__((always_inline)) inline void access(volatile unsigned long *p, unsigned long value) {
#ifdef STORE
    *p = value;
#else
    if (*p != value) fail(10);
#endif
    sync_memory();
    // Leave enough execution distance for a 50-cycle backing-memory miss and
    // its metadata response to populate the lookup buffer before the next try.
#ifndef FAST_ESTABLISH
    __asm__ volatile(".rept 512; nop; .endr" ::: "memory");
#endif
#ifdef STORE
#ifdef SILENT_INLINE_STORE
    unsigned long expected = layout_phase == 3 ? layout_expected : value;
    if (*layout_raw != expected) fail(13);
#else
    if (*layout_raw != value) fail(13);
#endif
#endif
}
int main(void) {
    unsigned long size = MODE == 1 ? 4096 : MODE == 2 ? 16384 :
        MODE == 3 ? 1024 : MODE == 4 ? 8192 : MODE == 5 ? 65536 :
        MODE == 6 ? 524288 : 128;
    unsigned long pos = (MODE == 0 || MODE == 7) ?
        ((LOC & 31)*16 - 1 - (LOC >> 5)) :
        (MODE == 1 || MODE == 2) ? size - 64 + LOC : size - 1 - (LOC >> 5);
    unsigned long encoded_pos = pos;
    if (MODE == 0 || MODE == 7)
        pos = (DATA_OFFSET & ~63UL) | (pos & 63UL); // Current L1 line is 64 bytes.
    volatile unsigned char *id = &region[pos];
    volatile unsigned long *raw = (void *)(region + DATA_OFFSET);
    layout_raw = raw;
    layout_expected = 123;
    *raw = 123;
    // A different ID at the former cross-line address proves the access
    // uses the wrapped byte. Do not dereference an underflowed encoding.
    if ((MODE == 0 || MODE == 7) && encoded_pos != pos && encoded_pos < sizeof(region))
        region[encoded_pos] = 2;
    *id = 1;
    sync_memory();
    void *bounded = __builtin_cheri_bounds_set((void *)region, size);
    volatile unsigned long *p = objid_id(objid_loc(objid_mode((char *)bounded + DATA_OFFSET, MODE), LOC), 1);
    layout_phase = 1;
#ifdef STORE
    access(p, 321);                  // Prove successful stores actually change data.
    access(p, 654);
    access(p, 654);                  // Allow a discarded cold fill, then require reuse.
    layout_expected = 654;
#else
    access(p, 123);                  // Cold metadata access (or inline L1 check).
    access(p, 123);                  // Reuse; trace must demonstrate buffer hit where supported.
    access(p, 123);                  // Retry reuse after any concurrent initial invalidation.
#endif
#ifdef UPDATE_AMO
    unsigned long word_offset = pos & ~3UL;
    __atomic_fetch_add((unsigned int *)(region + word_offset),
        (unsigned int)(NEW_ID - 1) << (8 * (pos & 3)), __ATOMIC_SEQ_CST);
#else
    *id = NEW_ID;
#endif
    sync_memory();
#if defined(STALE_FIRST) && (MODE == 0 || MODE == 7)
    layout_phase = 3;
    access(p, 456);                  // Inline L1 checks retain immediate enforcement.
#ifdef SILENT_INLINE_STORE
    return 0;                       // Stale store returned normally and changed no bytes.
#else
    fail(12);
#endif
#endif
    p = objid_id((void *)p, NEW_ID);
    *raw = 789;
    sync_memory();
    layout_phase = 2;
#if defined(STALE_FIRST) && (MODE > 0 && MODE < 7)
    // Legacy cached IDs have fence + establishing-access semantics. A read
    // establishes the new ID even in this variant of the store test.
    if (*p != 789) fail(14);
    sync_memory();
#endif
#ifdef STORE
    access(p, 987);                  // A mismatching cached ID forces the establishing memory lookup.
#else
    access(p, 789);                  // Establish the new ID after the metadata-write fence.
#endif
    *raw = 789;
    sync_memory();
    access(p, 789);                  // Reuse the new ID.
    access(p, 789);                  // Confirm reuse after any discarded post-write fill.
    p = objid_id((void *)p, 1);
    layout_expected = 789;
    layout_phase = 3;
    access(p, 456);                  // Reads fault; in-line stale stores are dropped.
#ifdef SILENT_INLINE_STORE
    return 0;
#else
    fail(11);
#endif
    return 0;
}
