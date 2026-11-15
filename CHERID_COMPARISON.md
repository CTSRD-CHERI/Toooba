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
