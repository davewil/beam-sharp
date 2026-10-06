#!/usr/bin/env bash
# run.sh -- re-execute every probe for ticket 59 from scratch.  Sources env.sh (override: W59_ENV=...).
# Builds four bscs from the repo's compiler/ (never modifying it), then runs p01..p11.
# Raw outputs land in out/.  Exit status = number of failed assertions (0 = every claim behaved as predicted).
# SKIP_TESTS=1 skips p11 (the repo's eunit suite x4, several minutes). QUICK=1 shrinks the benchmark.
HERE=$(cd "$(dirname "$0")" && pwd); cd "$HERE"
mkdir -p out   # each probe clears its own out/<probe> directory
TOTAL=0
step() { echo; echo "################ $1"; shift; "$@" 2>&1 | tee "out/$STEP.txt"; rc=${PIPESTATUS[0]}; TOTAL=$((TOTAL+rc)); echo "(exit $rc)"; }
STEP=build;  step build  ./build.sh
STEP=p01;    step "p01 reproduce"                         ./p01_reproduce.sh
STEP=p02;    step "p02 forged values (base/a/b/c)"        ./p02_forged.sh
STEP=p03;    step "p03 erlc elision + entry label"        ./p03_elision.sh
STEP=p05;    step "p05 bytes per guard"                   ./p05_bytes.sh
if [ -n "$QUICK" ]; then export REPS=3 CALLS=2000; fi
STEP=p06;    step "p06 microbenchmark"                    ./p06_bench.sh
STEP=p07;    step "p07 Elixir def/defp"                   ./p07_elixir.sh
STEP=p08;    step "p08 Gleam pub/private"                 ./p08_gleam.sh
STEP=p09;    step "p09 Elm (expected: cannot run)"        ./p09_elm.sh
STEP=p10;    step "p10 corpus census"                     ./p10_corpus.sh
STEP=p10b;   step "p10b exemplar source census"           python3 exemplar_census.py ../../../compiler/examples/exemplars
STEP=p12; step "p12 narrowing site (F24 s6)" ./p12_narrow.sh
if [ -z "$SKIP_TESTS" ]; then STEP=p11; step "p11 repo test suite under each option" ./p11_tests.sh; fi
echo; echo "TOTAL failed assertions: $TOTAL"; exit $TOTAL
