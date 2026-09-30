#!/usr/bin/env bash
# Re-run everything from a clean shell. ~1 min for probes; the suites take ~4 min each.
# Needs: erl/erlc (OTP 25), python3, curl (first build fetches maint-26 leex.erl), elixir, /tmp/tools/gleam.
set -eu
cd "$(dirname "$0")"; export LANG=C.UTF-8 LC_ALL=C.UTF-8
./build_bsc.sh                                                        # baseline -> /tmp/bsc57
for v in A1:bs_parser.yrl A2:bs_parser.yrl B1:bs_check.erl B2:bs_check.erl B3:bs_check.erl; do
  name=${v%%:*}; file=${v##*:}
  rm -rf /tmp/src57-$name; cp -r /home/user/beam-sharp/compiler/src /tmp/src57-$name
  patch -s /tmp/src57-$name/$file $(ls variant_${name}_*.patch)
  B=/tmp/bsc57-$name SRC=/tmp/src57-$name ./build_bsc.sh
done
./57a_refinement_table.sh; ./57b_ast_shape.sh; ./57c_guards_and_literals.sh; ./57e_paste_the_residual.sh
./57f_signed_domain.sh; ./57g_neighbours_erlang_elixir.sh; ./57h_neighbours_gleam_elm.sh
B=/tmp/bsc57 ./57d_emit_and_runtime.sh; B=/tmp/bsc57-A2 ./57d_emit_and_runtime.sh
# variants: B=/tmp/bsc57-A2 ./57a_refinement_table.sh   (likewise c, e, f)
# suites:   ./run_suite.sh base ; ./run_suite.sh A2   (compare the FAIL lists)
