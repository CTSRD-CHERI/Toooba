# CHERID evaluation: Reloaded

Source: https://github.com/CTSRD-CHERI/Toooba_IPMT, branch `jdw57-coherent`, original revision `b8cd650`.

The source history was imported using git-filter-repo. Author names, messages,
and source evolution are retained; hashes change because generated files were
removed from history. Generated RTL, Bluesim objects/executables, Vivado output,
logs, memory images, and compiled ISA test images are excluded. Required source
and library RTL remain. The original-to-imported mapping is in
`comparison/import-commit-map.txt`.

Reloaded includes the pre-existing uncommitted Map.bsv simplification and the three ObjID regression tests, as requested.

The missing root .gitmodules entry for the already-pinned capability library has been restored. Other libraries are vendored source, matching the original repository.

No branch has been pushed. See the local comparison-results report for build
and TestRIG outcomes before publishing. Binary ISA fixtures can be supplied
externally when using make isa_tests; TestRIG generates its own instruction tests.

## Differential testing

Build: `make -C builds/RV64ACDFIMSUxCHERI_Toooba_RVFI_DII_bluesim compile simulator`.
Run `python3 comparison/run_testrig.py riscv` and `python3 comparison/run_testrig.py cheri`.
The runner uses the existing TestRIG engine and Sail model, with 100 tests and
`--test-len 64` per eligible group by default. The RISC-V run selects
`rv64gc`; the CHERI run selects capability groups (`cap*`, `cloadtags`)
under `rv64gcxcheri`, including capability atomics. Set TEST_RIG_ROOT if this checkout is elsewhere.
These are differential smoke tests, not a claim to pass the complete ISA suites.

## Validation status

The imported designs are not certified as passing the complete ISA suites.
The local comparison-results report contains commands, logs and first failing
sequences. The TestRIG wrapper rejects dead-simulator results (some engine
versions otherwise print SUCCESS after an IO exception) and has a wall limit.
Use --include/--exclude to isolate a group; excluded groups do not count as passes.

The RVFI-DII Bluesim build passes. Diagnostic runs pass 100 tests per group for
arith, mem, control, arith64, mem64, muldiv, muldiv64, compressed, capinspect
and cloadtags. Atomic, floating-point and several CHERI groups show differential
mismatches against the local Sail model. The full RV64GC selection also hits
a TestRIG stc-generator exception (Prelude.!!: negative index). These results
are comparison evidence, not a claim that every mismatch is an RTL defect.

## Coherence comparison variant

This is `CHERID_eval_Reloaded_reversemap`. See [coherence variant](comparison/COHERENCE_VARIANT.md).
