# CHERID evaluation: CHERID

Source: https://github.com/CTSRD-CHERI/Toooba_IPMT, branch `main`, original revision `9d02fbc`.

The source history was imported using git-filter-repo. Author names, messages,
and source evolution are retained; hashes change because generated files were
removed from history. Generated RTL, Bluesim objects/executables, Vivado output,
logs, memory images, and compiled ISA test images are excluded. Required source
and library RTL remain. The original-to-imported mapping is in
`comparison/import-commit-map.txt`.

The missing root .gitmodules entry for the already-pinned capability library has been restored. Other libraries are vendored source, matching the original repository.

No branch has been pushed. See the local comparison-results report for build
and TestRIG outcomes before publishing. Binary ISA fixtures can be supplied
externally when using make isa_tests; TestRIG generates its own instruction tests.

## Differential testing

Build: `make -C builds/RV64ACDFIMSUxCHERI_Toooba_RVFI_DII_bluesim compile simulator`.
Run `python3 comparison/run_testrig.py riscv` and `python3 comparison/run_testrig.py cheri`.
The runner uses the existing TestRIG engine and Sail model, with 100 tests and
64-instruction tests by default. Set TEST_RIG_ROOT if this checkout is elsewhere.
These are differential smoke tests, not a claim to pass the complete ISA suites.
