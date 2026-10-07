#!/usr/bin/env bash
# Re-run every probe for ticket 57. Output of each goes to <probe>.out next to it. ~2 minutes (variants build + timings).
# The eunit comparison (A/B/baseline, ~4 min each) is separate:  bash run.sh --eunit
export PATH=$HOME/.nix-profile/bin:$PATH
H="$(cd "$(dirname "$0")" && pwd)"; cd "$H"
bash build_variants.sh > build_variants.out 2>&1
bash run_compare.sh > run_compare.out 2>&1       # table (current vs A parser-fold vs B checker-fold) + guard probe
bash run_table.sh > table_cur.out 2>&1
bash run_corpus.sh > run_corpus.out 2>&1         # which constant shapes the corpus uses
bash run_eq.sh > run_eq.out 2>&1                 # side finding: `value == 3` crashes
bash run_runtime.sh > run_runtime.out 2>&1       # negative bounds at the exported boundary (variant A)
BSC=$H/work/B/_build/default/bin/bsc bash run_runtime.sh > run_runtime_B.out 2>&1   # same under variant B
bash run_literal_value.sh > run_literal_value.out 2>&1   # can a Delta be constructed from `-3`?
escript ast.escript > ast.out 2>&1               # B# AST for -5, 0-5, -(-5), 2+3
escript neighbours.escript > neighbours_erlang.out 2>&1
elixir neighbours.exs > neighbours_elixir.out 2>&1
bash run_gleam.sh > run_gleam.out 2>&1
bash run_elm.sh > run_elm.out 2>&1               # fails offline (no elm/core cache); recorded as unmeasured
bash run_cost.sh > run_cost.out 2>&1
if [ "$1" = --eunit ]; then
  C=/home/user/beam-sharp/compiler
  for v in A B C; do (cd work/$v && rebar3 eunit > ../eunit_$v.out 2>&1); done
  for v in A B C; do grep -E '\*failed\*' work/eunit_$v.out | sed 's/\.\.\..*//' | sort > work/f_$v.txt; done
  diff work/f_C.txt work/f_A.txt && diff work/f_C.txt work/f_B.txt && echo "A and B fail exactly the baseline's tests"
fi
