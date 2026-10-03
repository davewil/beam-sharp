#!/usr/bin/env bash
# (1) selective vs blanket -compile(inline) on beam-sharp's emitted forms; (2) the compile options each
# neighbour actually ships; (3) what inlining does to a crash in a private function.
set -e
source "$(dirname "$0")/../common.sh"; cd "$(dirname "$0")"
B="$PWD/../01-rerun/build"; [ -f "$B/Day01.abstr" ] || bash ../01-rerun/run.sh >/dev/null 2>&1
rm -rf sbuild; erlc sel.erl crash.erl ../04-variants/bench3.erl
echo "== (1) build"; erl -noshell -pa . -eval 'sel:main(["'$B'","sbuild"])'
sed 's/-module(bench_erl)/-module(e0_erlang)/' "$BENCH/bench_erl.erl" > sbuild/e0_erlang.erl && erlc -o sbuild sbuild/e0_erlang.erl && rm sbuild/e0_erlang.erl
for i in 1 2 3; do echo "--- invocation $i"; erl -noshell -pa . -eval 'bench3:main(["sbuild","'$INPUT'","40"])'; done
echo; echo "== (2) compile options recorded in each shipped .beam (module_info(compile))"
erl -noshell -pa "$B" -eval '[io:format("~-16s ~p~n",[M, proplists:get_value(options, M:module_info(compile))]) || M <- [bench_erl, bench_gleam, '"'Elixir.BenchEx'"', '"'Day01'"']], halt().'
echo; echo "== (3) crash shape with and without inline"
erl -noshell -pa . -eval 'crash:run()'
