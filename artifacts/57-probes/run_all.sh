#!/usr/bin/env bash
# 57 -- runs every probe for the negative-literals-in-refinements brief and
# captures real output. Run from anywhere; paths are absolute.
set -uo pipefail
root=/home/user/beam-sharp
bsc="$root/compiler/_build/default/bin/bsc"
probes="$root/artifacts/57-probes"

echo "######## bsc: refinement with -5 (module dir must match declared name) ########"
rm -rf /tmp/NegRefinement && mkdir -p /tmp/NegRefinement
cp "$probes/neg_refinement.bs" /tmp/NegRefinement/a.bs
"$bsc" /tmp/NegRefinement/a.bs; echo "exit=$?"

echo
echo "######## bsc: relational PATTERN with -1 (same literal, pattern position) ########"
rm -rf /tmp/NegPattern && mkdir -p /tmp/NegPattern
cp "$probes/neg_pattern.bs" /tmp/NegPattern/a.bs
"$bsc" /tmp/NegPattern/a.bs; echo "exit=$?"

echo
echo "######## bsc: GUARD with a negative-literal boundary (new finding: shares the bug) ########"
rm -rf /tmp/NegGuardExhaustive && mkdir -p /tmp/NegGuardExhaustive
cp "$probes/neg_guard_exhaustive.bs" /tmp/NegGuardExhaustive/a.bs
"$bsc" /tmp/NegGuardExhaustive/a.bs; echo "exit=$?"

echo
echo "######## bsc: control -- identical shape, POSITIVE boundary (5, not -5) ########"
rm -rf /tmp/PosGuardExhaustive && mkdir -p /tmp/PosGuardExhaustive
cp "$probes/pos_guard_exhaustive.bs" /tmp/PosGuardExhaustive/a.bs
"$bsc" /tmp/PosGuardExhaustive/a.bs; echo "exit=$?"

echo
echo "######## ticket 38's own probe 38b (independent re-run, unmodified) ########"
bash "$root/wayfinder/prototypes/38b_divisor_expressiveness.sh"

echo
echo "######## erlang: guard \`X >= -5\` runs correctly + real parse tree for it ########"
cd "$probes" && erlc erlang_guard.erl >/dev/null 2>&1 && erl -noshell -eval 'erlang_guard:test().'

echo
echo "######## erlang: pattern position folds ARBITRARY closed arithmetic (not just '-') ########"
cd "$probes" && erlc erlang_pattern_fold.erl >/dev/null 2>&1 && erl -noshell -eval 'erlang_pattern_fold:test().'

echo
echo "######## elixir: guard with -5, and REAL two-variable subtraction in a guard ########"
elixir "$probes/elixir_guard.exs"

echo
echo "######## elixir: pattern position REFUSES constant arithmetic other than a literal -N ########"
elixir "$probes/elixir_pattern_arith.exs"

echo
echo "######## elixir: whitespace between '-' and digit does not change acceptance ########"
elixir "$probes/elixir_pattern_space.exs"
elixir "$probes/elixir_pattern_space2.exs"

echo
echo "######## gleam: build output for guard \`x >=. -5.0\` and pattern \`-1\` ########"
cd "$root/artifacts/scratch/gleam_probe" && rm -rf build && gleam build 2>&1
echo "-- generated Erlang (gleam_probe.erl) --"
cat build/dev/erlang/gleam_probe/_gleam_artefacts/gleam_probe.erl

echo
echo "ALL PROBES RAN"
