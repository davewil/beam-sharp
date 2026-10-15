#!/usr/bin/env bash
# 59_split_entry.sh -- ticket 18 s1 says "a guarded-public/unguarded-internal pair is impossible"
# because a BEAM function has one entry label. Claim tested: impossible AS ONE FUNCTION, but a compiler
# can emit TWO (exported guarded stub + local unguarded twin) with local calls bound to the twin.
# REFUTED (i.e. 18 right as worded, even as a pair) if remote inner(1.5) does not raise, or if
# local outer([1.5]) raises. Prints behaviour and Code-chunk bytes of the one-function vs split forms.
set -u; cd "$(dirname "$0")"; . ./env.sh
T=$(mktemp -d "${TMPDIR:-/tmp}/p59split.XXXXXX"); cd "$T"
cat > one.erl <<'ERL'
-module(one). -export([inner/1, outer/1]).
inner(N) when is_integer(N) -> N.
outer([X|_]) -> inner(X).
ERL
cat > two.erl <<'ERL'
-module(two). -export([inner/1, outer/1]).
inner(N) when is_integer(N) -> inner_(N).
inner_(N) -> N.
outer([X|_]) -> inner_(X).
ERL
erlc +deterministic one.erl two.erl
for m in one two; do
 erl -noshell -pa . -eval '
  M = '$m', P = fun(F) -> try {ok, F()} catch C:E -> {C, E} end end,
  io:format("~s: remote inner(1.5) -> ~w ; local-path outer([1.5]) -> ~w ; outer([1]) -> ~w~n",
            [M, P(fun() -> M:inner(1.5) end), P(fun() -> M:outer([1.5]) end), P(fun() -> M:outer([1]) end)]), halt().'
done
erl -noshell -eval '[begin {ok,{_,[{"Code",C}]}}=beam_lib:chunks(atom_to_list(M)++".beam",["Code"]), io:format("~s Code chunk: ~p bytes~n",[M,byte_size(C)]) end || M <- [one,two]], halt().'
