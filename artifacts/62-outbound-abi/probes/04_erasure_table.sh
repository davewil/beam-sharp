#!/usr/bin/env bash
# One command: ./04_erasure_table.sh -> probes/04_erasure_table.out
# Re-measures LANGUAGE.md sec.12's erasure table against the -spec bsc actually emits, and the runtime values.
HERE="$(cd "$(dirname "$0")" && pwd)"; source "$HERE/lib.sh"
E=$WORK/e; rm -rf $E; mkdir -p $E; bsc --src-root $HERE/bs -o $E $HERE/bs/Abi || exit 1
echo "=== the module as B# sees it (bsc --api)"; bsc --api --src-root $HERE/bs $HERE/bs/Abi
echo; echo "=== the -spec / -type attributes in the emitted Abi.beam (erl_pp)"
escript $HERE/spec_beam.escript $E/Abi.beam
echo; echo "=== runtime values of the same functions, from plain Erlang"
erl -noshell -pa $E -eval '
P = fun(L, V) -> io:format("~-34s ~p~n", [L, V]) end,
P("MaybeInt(true)",   '"'Abi'"':'"'MaybeInt'"'(true)),
P("MaybeInt(false)",  '"'Abi'"':'"'MaybeInt'"'(false)),
P("Res(true)",        '"'Abi'"':'"'Res'"'(true)),
P("Res(false)",       '"'Abi'"':'"'Res'"'(false)),
P("Pair(2)",          '"'Abi'"':'"'Pair'"'(2)),
P("Nums(4)",          '"'Abi'"':'"'Nums'"'(4)),
P("IsBig(10)",        '"'Abi'"':'"'IsBig'"'(10)),
P("Half(5.0)",        '"'Abi'"':'"'Half'"'(5.0)),
P("Pick(true)",       '"'Abi'"':'"'Pick'"'(true)),
P("Nest(true)",       '"'Abi'"':'"'Nest'"'(true)),
P("Nest(false)",      '"'Abi'"':'"'Nest'"'(false)),
P("MakePoint(3)",     '"'Abi'"':'"'MakePoint'"'(3)),
P("{ok,_} would-match Res(true)?", case '"'Abi'"':'"'Res'"'(true) of {ok,_} -> yes; _ -> no end),
P("NEGATIVE: Res(false) is {error,_}?", case '"'Abi'"':'"'Res'"'(false) of {error,_} -> yes; _ -> no end),
halt(0).'
