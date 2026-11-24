# ObjID layout ISA tests

These bare-metal purecap tests exercise loads and stores using every implemented
metadata mode. Startup/linker conventions and the custom instruction encodings
come from the CHERI-D Olden benchmark runtime; the test body and trap checks are
specific to this suite.

| Mode | Metadata layout |
| --- | --- |
| 0, 7 | Same-cache-line 16-byte slot; invalid encodings wrap within that line |
| 1 | 4 KiB page footer |
| 2 | 16 KiB region footer |
| 3 | 1 KiB top-relative layout |
| 4 | 8 KiB top-relative layout |
| 5 | 64 KiB top-relative layout |
| 6 | 512 KiB top-relative layout |

Legacy modes 1–6 use **fence + establishing-access consistency**. Software
writes the ID with uncoloured authority, executes `fence rw,rw`, and completes
an access carrying the new nonzero ID before relying on rejection of the old ID. The
establishing access follows the memory path if the cached ID differs. These
tests fence after it as well, ordering the following checks after completion.
An ID store and fence alone need not revoke a matching cached old ID.

ObjID memory misses wait for older fences, but do not search ordinary store
addresses or the store buffer. Unfenced lookups may therefore read an older ID
from L1 even if a newer ID is waiting in SQ/SB; they neither forward from those
stores nor wait for their addresses. The first full fence must drain the ID
write before establishment. Normal payload load/store ordering is unchanged.

Each normal test starts with ID 1, performs an initial access and repeated reuse,
updates the metadata byte to ID 2, fences, establishes ID 2, and finally requires
the old authority to be rejected. Legacy `stale-first` variants now establish
with a read before checking rejection, including in store tests. Modes 0/7
retain immediate L1 checking: their `stale-first` variants still require reads
to trap or failed stores to return normally without changing payload, before
any new-ID access. Successful stores write distinct values checked using
uncoloured authority. Fault handlers check `mcause == 28`, phase, and payload.

Modes 0/7 wrap invalid cross-line or underflowed locations within the current
64-byte cache line. A conflicting ID at the old address must be ignored; extra
cases access a capability's second line. Modes 1–6 retain their independent
metadata layouts. Invalidation may discard a metadata fill, but completion of
an establishing access must then invalidate its old cached value instead.
The protocol applies per changed nonzero ID, virtual alias, and core; retaining L1
coherence does not replace software synchronisation between cores.

Normal cases include a 512-NOP spacing interval and trace `OBJID_LAYOUT hit`,
`miss`, and `fill` with `+trace_objid_layout`. Twelve `fast` cases cover modes
1/3/6 with establishing reads/stores and plain/AMO ID writes, removing that NOP
gap to exercise the fence and refresh-completion ordering directly. Inline
modes use L1 checking rather than the separate buffer. Check trace markers to
verify actual hit coverage; repeated accesses alone do not prove hits.

Locations cover both metadata-byte positions for inline/top-relative layouts,
and each 32-bit quarter plus byte endpoints in the page-footer layouts. The
suite builds 240 independent ELFs so an expected terminal trap needs no trap
resume machinery. A pass returns zero through tohost; fail codes have bit 30
set, and the runner rejects timeouts and simulator assertion failures.

Build and run from the repository root:

```sh
python3 Tests/objid_layout/build.py --output /tmp/objid-layout-binaries
python3 Tests/test_objid_layout.py --sim /absolute/exe_HW_sim \
  --binaries /tmp/objid-layout-binaries --output /tmp/objid-layout-results \
  --converter /absolute/elf_to_hex
```

Use `--sdk` to choose a CHERI bare-metal SDK. The `.4byte` setters support an
ordinary CHERI assembler without requiring private CHERI-D compiler changes.
The base cases change ID 1 -> 2. Additional cases change ID 1 to each of
3, 5, 9, 17, 33, 65 and 129: each changes one upper bit while preserving bit 0,
so a parity-only comparison fails. Both normal and immediate-stale cases also
update metadata using AMOADD.W in representative layouts. All checked IDs must
use full eight-bit equality; ID0 remains the uncoloured bypass authority. Tests that fail on both
baseline and candidate must remain reported as failures, not treated as passes.
