#!/usr/bin/env bash
# 00 -- build every variant from a fresh COPY of the repo's compiler/.
#   base : unpatched copy (so the matrix compares like with like)
#   g1   : parser -- `negate/2` folds an int literal, as it already folds a float one
#   g1b  : parser -- the fold applies under the `refinement` rule ONLY
#   c1   : checker -- comparison/1 folds constant ints (literal, -, + - *) first
#   c2   : c1 plus type_of({e_neg, int literal}) is the singleton, not `int`
# REFUTES nothing; a build or patch failure aborts the run.
. "$(dirname "$0")/lib.sh"
rm -f "$OUT"/build-*.log
build_variant base
build_variant g1  "$HERE/patches/g1-parser-negate-int.patch"
build_variant g1b "$HERE/patches/g1b-parser-refinement-only.patch"
build_variant c1  "$HERE/patches/c1-checker-comparison-fold.patch"
build_variant c2  "$HERE/patches/c2-checker-fold-plus-type_of.patch"
for v in base g1 g1b c1 c2; do
    printf '%-5s %s  | %s\n' $v "$(ls -la "$(bsc_of $v)" | awk '{print $5" bytes"}')" "$(grep -h 'conflicts' "$OUT/build-$v.log" | head -1 | sed 's/.*Warning: //')"
done
echo "# patch sizes (added/removed non-header lines):"
for p in "$HERE"/patches/*.patch; do printf '%-40s +%s -%s\n' "$(basename $p)" "$(grep -c '^+[^+]' $p)" "$(grep -c '^-[^-]' $p)"; done
