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

Each normal test starts with ID 1, performs an initial access and repeated reuse,
updates the metadata byte to ID 2 using uncoloured authority, checks accesses
with ID 2, and finally requires the old authority to be rejected: reads trap, while
failed in-line stores must return normally with the payload unchanged. Separate
`stale-first` tests apply the same rejection policy immediately after the ID write, before
any new-ID lookup can refresh the buffer. Successful stores write distinct
values and are checked through uncoloured authority. For trapping cases, fault handlers check
`mcause == 28`, the test phase and unchanged payload. In-line store cases reject
any trap and check that stale writes leave the payload unchanged. Modes 0/7
wrap an otherwise cross-line or underflowed encoding within the data access
line (64 bytes in this test configuration). A conflicting ID at the old
cross-line address must be ignored. Additional cases access the second line
of a capability. Modes 1–6 retain their separate metadata layouts and trapping
expectations; no same-line assumption is made for those modes.

Repeated reuse allows an initial fill to be discarded by a concurrent invalidation.
An instruction-only delay between accesses allows the next lookup to fill
before reuse with the study's 50-cycle added DRAM latency. BSIM builds emit
`OBJID_LAYOUT hit`, `miss` and `fill` with `+trace_objid_layout`. Check these
markers to establish hit coverage; repeated accesses alone do not prove hits.
Inline modes use their L1 checking path, not the separate ID buffer.

Locations cover both metadata-byte positions for inline/top-relative layouts,
and each 32-bit quarter plus byte endpoints in the page-footer layouts. The
suite builds 228 independent ELFs so an expected terminal trap needs no trap
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
