#!/usr/bin/env bash
# run.sh — reproduce everything in artifacts/57-negative-literals-in-refinements.md.
# Needs: erl/elixir/gleam on PATH (gleam, elm in /tmp/bin here); builds variants into $WORK.
set -uo pipefail
cd "$(dirname "$0")"; export WORK=${WORK:-/tmp/p57work}; export PATH=/tmp/bin:$PATH
./build-variant.sh base
./build-variant.sh optA1 "$PWD/optA-a1.patch"
./build-variant.sh optA2 "$PWD/optA-a2.patch"
./build-variant.sh optB  "$PWD/optB-parser-negate.patch"
./build-variant.sh optC  "$PWD/optC-narrow-grammar.patch"
mkdir -p out
for v in base optA1 optA2 optB optC; do ./probe-table.sh "$WORK/$v/bsc" > out/$v.txt 2>&1; done
for v in optA1 optA2 optB optC; do echo "##### $v vs base (lines that changed)"; diff out/base.txt out/$v.txt | grep '^>' ; done
echo; echo "##### WRONG markers (must be 0 everywhere):"; grep -c WRONG out/*.txt
echo; ./ast-shape.sh
echo; for v in base optA1 optB; do echo "##### residual round trip: $v"; ./residual.sh "$WORK/$v/bsc"; done
echo; ./expr-equivalence.sh
echo; ./cost.sh
echo; echo "##### repo eunit suite, delta vs base (slow, ~30s per variant)"
for v in base optA1 optA2 optB optC; do ./regress.sh $v; done
for v in optA1 optA2 optB optC; do echo "new failures in $v vs base:"; comm -13 "$WORK/base/failing.txt" "$WORK/$v/failing.txt"; done
echo; echo "##### survey"; escript survey/erlang.escript; elixir survey/elixir.exs 2>&1 | grep -v '^warning'
echo; echo "##### emitted body form of F() -> -5"; ./emitted-form.sh
