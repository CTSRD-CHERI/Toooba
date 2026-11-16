# Separate ObjID queue experiment

Branch `CHERID_eval_Reloaded_objid_lsoq` derives from Reloaded at `2fee08115`.
The ordinary load and store queues retain their original capacity and allocate
one entry per payload operation. Out-of-line ObjID lookups use a separate queue,
with independent allocation, issue-selection and reclamation pointers.

## Admission and lifetime

Each memory instruction reserves an ObjID queue credit at rename. The default
capacity is half of `LdQSize + StQSize`: **19 entries per core** for CORE_SMALL
(24 LQ + 14 SQ). Override it independently with a positive `OBJIDQ_SIZE`:

```sh
make -C src_SSITH_P3 compile_synth OBJIDQ_SIZE=12
```

This passes `-D OBJIDQ_SIZE=12` to BSC. Rebuild generated RTL/compiler objects
when changing the setting. Smaller sizes can stall rename while the payload
queues still have room; no-check/buffer-hit reservations return credit during
execute. Reserving before execute avoids a deadlock in
which younger lookups fill the queue while waiting for an older store that
cannot execute because no metadata credit remains.

Execute resolves the reservation into either an active lookup or an unused
entry (for example, an ObjID-buffer hit). Completed/unused entries reclaim at
the ObjID queue head, independently of payload completion and ROB commit.
An older outstanding lookup can hold up reclamation of younger completed slots;
this is a separate FIFO, not a free-list allocator.

Each active entry records its parent LQ/SQ tag and full instruction tag, plus
speculation bits. A result updates the parent verdict; it does not create a
separate architectural instruction or register write. A squashed issued entry
retains its ObjID tag until its response drains, even if the parent slot has
already been reused. Commit protection applies to the associated lookup too.

## Storage and issue

Wide descriptors, virtual addresses and owner records use indexed RegFiles.
Parent entries keep a small link and verdict instead of copies of out-of-line
metadata addresses. The old load/store ObjID request-buffer instances are
removed. Same-line checks retain the existing payload-cache path.

Ready lookups select independently of the payload queues, rotating past stalled
checks. Metadata requests still pass through a registered cache-request FIFO.
LR metadata checks complete before issuing the atomic payload operation.

## Validation

`Tests/test_objid_lsoq.py` exercises the real LSQ, including full LQ/SQ
admission, early unused-credit return, same-cycle translation/issue, independent
responses, parent reuse after squash, mismatch faults, commit protection and LR metadata gating and fence admission.
The registered cache-request and squash tests cover cache arbitration and
backpressure. Run these alongside the existing ObjID Bloom/buffer tests.

Passing checks:

The sizing update passes the real LSQ regression at the default 19 entries
and an explicit `OBJIDQ_SIZE=7`, including credit exhaustion and wraparound.
Run the override regression with `TOOOBA_OBJIDQ_SIZE=7 python3 Tests/test_objid_lsoq.py`.

- Real LSQ lifetime/capacity regression, including LR metadata gating and fence admission.
- Registered cache-request arbitration, ordering, backpressure and duplication.
- Stale responses with payload-first/branch squash and metadata-first/full squash.
- Existing Bloom eviction, collision, same-cycle fill and BRAM flush regression.
- FPGA-configuration Verilog generation of `mkObjIdLoadQueue`.
- Full RVFI-DII Bluesim compilation and simulator linking (initial 38-entry configuration).

Fences bypass address translation, so their parent verdict is initialized as
satisfied at rename. The focused regression and an exact TestRIG replay cover
this case. The `mem`, `mem64`, `capinspect` and `cloadtags` differential smoke groups
pass 100 tests each with up to 64 instructions per test, using the initial
38-entry configuration. These are selected
smoke groups, not full ISA-suite certification. Logs are kept
outside tracked history in the parent checkout's `comparison-results` directory,
with the `Reloaded-lsoq-` prefix. No FPGA area or timing improvement is claimed
until this experimental branch is synthesized and routed.
