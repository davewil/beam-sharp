#!/usr/bin/env bash
# p08 -- Gleam (no deps): does the compiler emit any parameter check on pub vs private functions?
# No Gleam compiler source is installed; evidence is the generated Erlang and a run.
# REFUTED (that Gleam emits nothing at either scope) if scope@... generated .erl contains is_integer/is_tuple/
# is_map/guard tests on a function head or if the forged call below raises function_clause.
. "$(dirname "$0")/lib.sh"; cd "$HERE"
O="$OUT/p08"; rm -rf "$O"; mkdir -p "$O"; cp -r src/gleam "$O/proj"; cd "$O/proj"
gleam --version | tee ../version.txt
gleam build 2>&1 | tee ../build.log
E=$(ls build/dev/erlang/scope/_gleam_artefacts/scope.erl); cp "$E" ../scope.erl
grep -vE "^%%|^-compile|^$" ../scope.erl | sed -n '1,200p' | tee ../scope_body.txt
cd "$HERE"
# forge: a map handed to pub_amount/total_of, an atom and a float handed to pub_double (Gleam is untyped at runtime)
erl -noshell -pa "$O/proj/build/dev/erlang/scope/ebin" -eval '
  P = fun(F) -> try {ok, F()} catch C:R:S -> {C, R, hd(S)} end end,
  io:format("pub_amount(#{total=>5})        => ~p~n",   [P(fun() -> scope:pub_amount(#{total=>5}) end)]),
  io:format("pub_amount(not_a_record)       => ~p~n",   [P(fun() -> scope:pub_amount(not_a_record) end)]),
  io:format("pub_double(1.5)                => ~p~n",   [P(fun() -> scope:pub_double(1.5) end)]),
  io:format("use_double(1.5) [-> private]   => ~p~n",   [P(fun() -> scope:use_double(1.5) end)]),
  io:format("total_of([{order,1,2},{wrong,9,9}]) => ~p~n", [P(fun() -> scope:total_of([{order,1,2},{wrong,9,9}]) end)]),
  io:format("doc_total({bogus,1,2}) [priv_doc] => ~p~n", [P(fun() -> scope:doc_total({bogus,1,2}) end)]),
  halt().' 2>&1 | tee "$O/forged.txt"
absent "no is_integer/is_float guard in any generated Gleam function"  "$O/scope_body.txt" "is_integer|is_float"
expect "pub_amount applies no check of its own: a non-record dies only in the body's BIF (badarg from erlang:element/2)" "$O/forged.txt" "pub_amount\(not_a_record\) *=> *\{error,badarg"
expect "forged 3-tuple {wrong,9,9} is accepted silently through private priv_amount (total_of => {ok,11})" "$O/forged.txt" "total_of.*=> \{ok,11\}"
expect "float accepted silently by pub_double AND via private" "$O/forged.txt" "use_double.*=> \{ok,3.0\}"
expect "pub_double(1.5) also silent (no scope difference: nothing is checked at either)" "$O/forged.txt" "pub_double\(1.5\) *=> \{ok,3.0\}"
echo "p08 FAILS=$FAILS"; exit $FAILS
