#!/usr/bin/env bash
# Re-run every probe from a clean shell. Builds four compilers (base, A, B, C) into /tmp/bs59-build.
# Variant sources are variants/bs_emit.{A,B,C}.erl; variants/variant_*.patch are their diffs against
# compiler/src/bs_emit.erl at the commit this brief was written on.
set -u; cd "$(dirname "$0")"; source ./env.sh
build_compiler /tmp/bs59-build/ebin-base 2>/dev/null
for v in A B C; do build_compiler /tmp/bs59-build/ebin-$v "$PWD/variants/bs_emit.$v.erl" 2>/dev/null; done
for p in p1_private_guards p2_forged_projection p3_fn_value_escape; do
  ./$p.sh /tmp/bs59-build/ebin-base > $p.out 2>&1
  for v in A B C; do ./$p.sh /tmp/bs59-build/ebin-$v > $p.variant_$v.out 2>&1; done
done
for v in base A B C; do ./p4_corpus_measure.sh /tmp/bs59-build/ebin-$v $v > p4_corpus_measure.$v.out 2>&1; done
for v in base B; do echo -n "[$v] "; ./disasm_count.escript /tmp/bs59-build/corpus-$v; done > p5b_disasm_count.out
for v in base B; do echo "[$v]"; ./disasm_which.escript /tmp/bs59-build/corpus-$v; done > p5c_disasm_which.out 2>&1
./p5_erlc_local_types.sh > p5_erlc_local_types.out 2>&1
./p6_loop_bench.sh > p6_loop_bench.out 2>&1
./p7_survey_gleam.sh > p7_survey_gleam.out 2>&1
elixir p7_survey_elixir.exs > p7_survey_elixir.out 2>&1
./p8_escape_bench.sh > p8_escape_bench.out 2>&1
./p9_suite_delta.sh > p9_suite_delta.out 2>&1
