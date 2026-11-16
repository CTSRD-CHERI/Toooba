# Reloaded reversemap coherence variant

Derived from original `CHERID_eval_Reloaded` at `2fee08115`, independently of
the `CHERID_eval_Reloaded_objid_lsoq` experiment. This branch retains the original
payload queues, BRAM-backed ObjID buffer, cache geometry and pipeline changes.

Coherence is enabled using a **64-entry, four-way physical-line reverse presence map**. A relevant D-cache
eviction triggers a whole-ObjID-buffer flush on a tracked physical-line match.
The original mode-3/1K and mode-4K gating and same-cycle fill checks are retained.

The reverse presence map follows the late historical reverse-map design's
physical-line-to-presence interpretation (a VA value is unnecessary because a
match flushes the whole forward buffer). It has 16 sets and four ways, using
full physical-line tags, indexed by the low four physical-line bits. Unlike a silently replacing lossy map, a fifth distinct
line in a set makes the map conservatively report all lines present until the
next whole-buffer flush. This prevents reverse-map collisions/replacement from
losing coherence coverage. Both forward and reverse state clear together.
Stale presence entries can cause harmless extra flushes.

The map is inlined into the existing core synthesis boundary, so it adds no new
standalone generated RTL file to component.xml. Existing RegFile primitives are
already packaged. This branch has no Bloom-filter state or Bloom hash logic.

The focused reverse-map regression passes (`python3 Tests/test_objid_reversemap.py`), including full-tag collisions, same-cycle load/store fills, aliases, mode gating, conservative saturation and paired clearing. The Bloom-only regression explicitly skips on this branch. Full RVFI-DII Bluesim BSV compilation (through `mkTop_HW_Side`) passes. Simulator linking, new differential smoke runs and FPGA implementation have not been run for this variant. Neither branch has been pushed by the agent.
