#!/usr/bin/env bash
# 59_gleam.sh -- Gleam survey. Claim: Gleam emits NO runtime guard on a typed parameter, exported or
# private, and an `opaque` type is a compile-time wall only. REFUTED if any emitted function below has a
# `when`-guard / is_integer / element(1) test on its parameter, or if a forged call raises where this
# says it returns. Prints the generated Erlang and calls it from plain Erlang with forged terms.
set -u; cd "$(dirname "$0")"; . ./env.sh
T=$(mktemp -d "${TMPDIR:-/tmp}/p59gl.XXXXXX"); cp -r 59_gleam "$T/proj"; cd "$T/proj"
gleam build 2>&1 | tail -3
echo "=== emitted BEAM code of the compiled module (beam_disasm): note: no is_integer / element(1) test in any prologue"
"$OLDPWD/59_disasm.escript" build/dev/erlang/g59/ebin/g59.beam priv/1 direct/1 pub_total/1 pub_case/1 add/2 priv_add/2
echo "=== forged calls from Erlang (wrong tag / wrong payload / float)"
erl -noshell -pa build/dev/erlang/g59/ebin -eval '
 P = fun(F) -> try {ok, F()} catch C:R -> {C, case R of T when is_tuple(T) -> element(1, T); A -> A end} end end,
 io:format("direct({invoice,1,5})         (Order expected)      -> ~w~n", [P(fun() -> g59:direct({invoice,1,5}) end)]),
 io:format("pub_total({invoice,1,5})      (Order, field access) -> ~w~n", [P(fun() -> g59:pub_total({invoice,1,5}) end)]),
 io:format("pub_case({invoice,1,5})       (Order, case)         -> ~w~n", [P(fun() -> g59:pub_case({invoice,1,5}) end)]),
 io:format("pub_total(42)                                       -> ~w~n", [P(fun() -> g59:pub_total(42) end)]),
 io:format("pub_total({order,1,<<\"x\">>})  (payload forged)      -> ~w~n", [P(fun() -> g59:pub_total({order,1,<<"x">>}) end)]),
 io:format("add(1.5, 2.5)                                       -> ~w~n", [P(fun() -> g59:add(1.5, 2.5) end)]),
 io:format("via_list([1.5]) (private priv_add)                  -> ~w~n", [P(fun() -> g59:via_list([1.5]) end)]),
 io:format("sealed_total({invoice,1,5}) (opaque)                -> ~w~n", [P(fun() -> g59:sealed_total({invoice,1,5}) end)]),
 halt().'
