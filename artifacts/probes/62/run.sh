#!/usr/bin/env bash
# run.sh: re-executes every probe from scratch (sources env.sh through lib.sh), raw output into out/.
# The experimental alias compiler is rebuilt from compiler-alias.patch into the session scratchpad; the repo's compiler is never modified.
# Takes roughly 8-10 minutes (p10 and p11 are timing runs on a shared host; expect run-to-run variation in absolute ns/us, not in ordering).
cd "$(dirname "$0")" || exit 1
HERE="$PWD"
. ./lib.sh
mkdir -p out
rm -f "$SCRATCH/compiler-alias/_build/default/bin/bsc"   # force a rebuild from the patch
build_alias_compiler || { echo "FATAL: alias compiler did not build from compiler-alias.patch"; exit 1; }
for p in p01_rerun_62a p02_elixir_quoted_call p03_elixir_tokenizer p04_elixir_compile_format p05_gleam \
         p06_alias_derivation p07_elixir_calls_alias p08_size p08b_corpus_size p09_disasm p10_call_cost p11_load_time \
         p12_spec_and_tooling p13_stacktrace p14_corpus_names p15_elixir_facade p16_blast_radius p17_callback_precedent; do
  short=${p%%_*}
  echo ">>> $p"
  ./$p.sh > "out/$short.out" 2>&1; echo "    exit=$? -> out/$short.out"
done
echo; echo "================ verdict.sh"; ./verdict.sh | tee out/verdict.out
