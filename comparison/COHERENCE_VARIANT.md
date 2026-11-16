# Reloaded bloom coherence variant

Derived from original `CHERID_eval_Reloaded` at `2fee08115`, independently of
the `CHERID_eval_Reloaded_objid_lsoq` experiment. This branch retains the original
payload queues, BRAM-backed ObjID buffer, cache geometry and pipeline changes.

Coherence is enabled using a **256-bit single-hash Bloom filter**. A relevant D-cache
eviction triggers a whole-ObjID-buffer flush on a tracked physical-line match.
The original mode-3/1K and mode-4K gating and same-cycle fill checks are retained.

The production hardware is identical to the original Reloaded baseline. Bloom collisions may cause extra flushes.

The focused Bloom regression passes (`python3 Tests/test_objid_bloom.py`). Neither branch has been pushed by the agent.
