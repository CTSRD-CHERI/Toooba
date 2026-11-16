# CHERID evaluation: Picasso

Source: https://github.com/coloredcapabilities/colored-toooba, branch `colored_artifact`, original revision `912bd0a98eb09150b1cee72fbff15732102c09dd`.

The source history was imported using git-filter-repo. Author names, messages,
and source evolution are retained; hashes change because generated files were
removed from history. Generated RTL, Bluesim objects/executables, Vivado output,
logs, memory images, and compiled ISA test images are excluded. Required source
and library RTL remain. The original-to-imported mapping is in
`comparison/import-commit-map.txt`.

The original private capability-library revision `75870abd` was unavailable.
The local `cheri-cap-lib` branch `CHERID_eval_Picasso` now imports the authors'
[published library patch](https://github.com/coloredcapabilities/colored-artifact/blob/fb467f5b0b3137b997f4415fa55fdaa59b6d2213/patches/cheri-cap-lib_colored.patch)
on public base `7d9fdce`. Its source files match that patch application.
It uses 21 type/color bits and two software-permission bits. Tests cover the
published zero behavior, strict threshold boundary and SW1 permission gate.
See `libs/cheri-cap-lib/PICASSO_RECONSTRUCTION.md` for provenance. The earlier
reconstructions are superseded. Validation below uses the published implementation, superseding results from
the initial 20-bit reconstruction.

The library and matching Toooba pin have been verified on GitHub. See the local
comparison-results report for exact tested revisions and outcomes. Binary ISA fixtures can be supplied
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

The published-library API test and RVFI-DII Bluesim build pass. Tests run on
2026-11-16 with library ee3710bb pass 100 cases each for arith, mem, control,
arith64, mem64, muldiv, muldiv64, compressed and cloadtags. capinspect, caparith,
capmisc, capcontrol, capdecode and caprandom show mismatches against stock Sail.
The first capinspect mismatch is CGetPerm returning 0x78fff in Sail and 0x18fff
in Picasso, consistent with Picasso retaining only two software-permission bits.
Capability atomics and capability-cache groups were excluded from this isolated
run; ordinary atomic/floating-point groups were not tested on Picasso. These
observations do not establish that each mismatch is an RTL defect.
