# CHERID evaluation: Picasso

Source: https://github.com/coloredcapabilities/colored-toooba, branch `colored_artifact`, original revision `912bd0a98eb09150b1cee72fbff15732102c09dd`.

The source history was imported using git-filter-repo. Author names, messages,
and source evolution are retained; hashes change because generated files were
removed from history. Generated RTL, Bluesim objects/executables, Vivado output,
logs, memory images, and compiled ISA test images are excluded. Required source
and library RTL remain. The original-to-imported mapping is in
`comparison/import-commit-map.txt`.

The original private capability-library revision `75870abd` was unavailable.
The public `cheri-cap-lib` branch `CHERID_eval_Picasso` reconstructs its API
with a 20-bit type/color field by reclaiming two reserved bits. The core
retains its 21-bit API. See `libs/cheri-cap-lib/PICASSO_RECONSTRUCTION.md`
for encoding and threshold assumptions. This is not a recovered copy of
the private library. Its encoding/API unit test passes.

No branch has been pushed. See the local comparison-results report for build
and TestRIG outcomes before publishing. Binary ISA fixtures can be supplied
externally when using make isa_tests; TestRIG generates its own instruction tests.

## Differential testing

Build: `make -C builds/RV64ACDFIMSUxCHERI_Toooba_RVFI_DII_bluesim compile simulator`.
Run `python3 comparison/run_testrig.py riscv` and `python3 comparison/run_testrig.py cheri`.
The runner uses the existing TestRIG engine and Sail model, with 100 tests and
64-instruction tests per eligible group by default. The RISC-V run selects
`rv64gc`; the CHERI run selects `rv64xcheri` (including the engine's common
integer groups). Set TEST_RIG_ROOT if this checkout is elsewhere.
These are differential smoke tests, not a claim to pass the complete ISA suites.
