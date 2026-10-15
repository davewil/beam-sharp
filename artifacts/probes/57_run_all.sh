#!/usr/bin/env bash
# 57_run_all -- reruns every probe of ticket 57 and rewrites each <probe>.out. (57_eunit.sh is excluded: ~4 min.)
# usage: ./57_run_all.sh   (builds the variants once into a fresh mktemp dir, exports V57 for the rest)
cd "$(dirname "$0")"; . ./env.sh
export V57; V57=$(./57_build_variants.sh | sed -n 's/^export V57=//p'); echo "V57=$V57"
./57_stock.sh                  > 57_stock.out 2>&1
./57_variants.sh               > 57_variants.out 2>&1
./57_ast.sh                    > 57_ast.out 2>&1
./57_residual.sh               > 57_residual.out 2>&1
./57_guard_runtime.sh          > 57_guard_runtime.out 2>&1
./57_boundary.sh               > 57_boundary.out 2>&1
./57_api.sh                    > 57_api.out 2>&1
./57_nonzero.sh                > 57_nonzero.out 2>&1
./57_emit.sh                   > 57_emit.out 2>&1
./57_timing.sh                 > 57_timing.out 2>&1
./57_erlang.escript            > 57_erlang.out 2>&1
elixir 57_elixir.exs 2>&1 | grep -v '^warning\|^  *[a-z_]*\.exs\|^$\|│\|└\|~' > 57_elixir.out
./57_gleam.sh                  > 57_gleam.out 2>&1
./57_elm.sh                    > 57_elm.out 2>&1
echo done
