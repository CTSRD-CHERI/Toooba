# CHERID evaluation: Picasso

Source: https://github.com/coloredcapabilities/colored-toooba, branch `colored_artifact`, original revision `912bd0a98eb09150b1cee72fbff15732102c09dd`.

The source history was imported using git-filter-repo. Author names, messages,
and source evolution are retained; hashes change because generated files were
removed from history. Generated RTL, Bluesim objects/executables, Vivado output,
logs, memory images, and compiled ISA test images are excluded. Required source
and library RTL remain. The original-to-imported mapping is in
`comparison/import-commit-map.txt`.

The original private capability-library revision `75870abd` was unavailable.
The public `cheri-cap-lib` branch `CHERID_eval_Picasso` reconstructs its API.
Following [the paper, section 6.1](https://arxiv.org/pdf/2602.09131), it uses
21 type/color bits by reclaiming one reserved bit and two software-permission
bits. Colors satisfy `0 < otype < CCPT`; equality remains sealed.
See `libs/cheri-cap-lib/PICASSO_RECONSTRUCTION.md` for the remaining packing
assumptions. The corrected encoding/API test passes; simulator results below
were obtained with the earlier 20-bit reconstruction and do not validate this pin.

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

The corrected reconstructed-library API test passes. The prior 20-bit
RVFI-DII Bluesim build passed; the corrected 21-bit simulator is being rebuilt. Diagnostic
runs pass 100 tests per group for arith, mem, control, arith64, mem64, muldiv,
muldiv64, compressed, capinspect and cloadtags. caparith, capmisc, capcontrol,
capdecode and caprandom show mismatches against the local Sail model. Capability
atomics and capability-cache groups were excluded in this isolated diagnostic run;
the ordinary atomic/floating-point groups were not tested on Picasso.
