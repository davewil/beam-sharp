#!/usr/bin/env bash
# Ticket 57 probes. Reruns everything from scratch; exits non-zero if an expected observation fails.
#   bash artifacts/probes/57/run.sh
# bsc is not buildable on OTP 25, but its lexer/parser/checker modules are, with two shims (build.sh).
# "base" = the repo's compiler/src untouched. grammar|neg|negt|arith = the candidate fixes, as the
# small patches in this directory, applied to a scratch copy only.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); w=$(mktemp -d); trap 'rm -rf "$w"' EXIT; fail=0
ok() { if [ "$1" = 0 ]; then echo "PASS  $2"; else echo "FAIL  $2"; fail=1; fi; }
for v in base grammar neg negt arith; do "$here/build.sh" "$w/b_$v" $v >/dev/null 2>&1 || { echo "build $v failed"; exit 2; }; done

echo "=== A. AST shapes (real bs_lexer + bs_parser, base) ==="
escript "$here/ast.escript" "$w/b_base"; ok $? "refinement -5 parses to {e_neg,_,{e_int,_,5}}, not {e_op,'-',{e_int,0},..}"

echo; echo "=== B. refinements and guards through the real bs_check, per variant ==="
for v in base grammar neg arith; do escript "$here/table.escript" "$w/b_$v" $v | sed 'N;s/\n *\(opaque\)/ \1/;P;D' | tr -s ' '; done > "$w/table.txt"
cat "$w/table.txt"
has() { grep -q -- "^$1 $2 *$" "$w/table.txt"; }
has base    "refinement value >= -5 {refused, opaque_refinement}";               ok $? "base refuses value >= -5 (ticket's repro)"
has base    "refinement value <= 3 or value >= 10 accepted";                      ok $? "base accepts the disjoint union (ticket's control)"
has base    "exhaustive guards n <= -1 / n >= 0 {diag,[inexhaustive]}";           ok $? "base: guard 'n <= -1' earns no coverage (NEW: not only refinements)"
has base    "exhaustive guards n < 0 / n >= 0 accepted";                          ok $? "base: the same guards spelled 'n < 0' are exhaustive"
has grammar "refinement value >= -5 and value <= 5 accepted";                     ok $? "grammar fold accepts -5..5"
has grammar "refinement value >= -(2 + 3) {refused, opaque_refinement}";          ok $? "grammar fold stops at -(2 + 3)"
has neg     "refinement value >= -5 and value <= 5 accepted";                     ok $? "checker fold (neg) accepts -5..5"
has neg     "refinement value >= 2 + 3 {refused, opaque_refinement}";             ok $? "checker fold (neg) stops at 2 + 3"
has arith   "refinement value >= 5 - 10 accepted";                                ok $? "checker fold (arith) folds 5 - 10"

echo; echo "=== C. does the accepted refinement mean it; what types the literal -1 (per variant) ==="
for v in base grammar neg negt; do escript "$here/sem.escript" "$w/b_$v" $v | tr -s ' ' | sed 'N;s/\n opaque/ opaque/;P;D'; done > "$w/sem.txt"; cat "$w/sem.txt"
hs() { grep -q -- "^$1 $2 *$" "$w/sem.txt"; }
hs grammar "Take(-100 ) over Delta accepted";                         ok $? "grammar: Take(-100) over -100..100 accepted"
hs grammar "Take(-101 ) over Delta {diag,[arg_not_accepted]}";        ok $? "grammar: Take(-101) refused (the bound is real)"
hs neg     "Take(-100 ) over Delta {diag,[arg_not_accepted]}";        ok $? "checker fold alone: Take(-100) over -100..100 is REFUSED"
hs negt    "Take(-100 ) over Delta accepted";                         ok $? "checker fold + type_of fold: accepted (two sites)"
hs base    "Take(-1) over (value <= 5) {diag,[arg_not_accepted]}";     ok $? "base: literal -1 is typed int, not -1..-1 (pre-existing)"
hs grammar "Take(-1) over (value <= 5) accepted";                     ok $? "grammar fold fixes that too"

echo; echo "=== D. repo eunit slice: failing set identical across variants (OTP 25: many fail at base) ==="
for v in base grammar neg negt arith; do "$here/suite.sh" "$w/b_$v" > "$w/suite_$v.txt"; done
head -1 "$w/suite_base.txt"
for v in grammar neg negt arith; do diff -q "$w/suite_base.txt" "$w/suite_$v.txt" >/dev/null; ok $? "$v: same failing set as base"; done

echo; echo "=== E. Erlang ===";  bash "$here/erl/run.sh";   ok $? "erlang probe"
echo; echo "=== F. Elixir ===";  bash "$here/ex/run.sh";    ok $? "elixir probe"
echo; echo "=== G. Gleam ===";   bash "$here/gleam/run.sh"; ok $? "gleam probe"
echo; echo "Elm 0.19.2: NOT RUN (package registry unreachable from this sandbox; see brief)."
exit $fail
