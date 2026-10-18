#!/usr/bin/env bash
# 06 — what ONE guard costs in .beam Code-chunk bytes, hand-written Erlang, so no
# bsc variant is in the loop.  Re-measures ticket 26a (+14 B tag) and 18a (+3-5 B is_integer).
HERE0="$(cd "$(dirname "$0")" && pwd)"; source "$HERE0/lib.sh"; cd "$WORK"
cat > g_plain.erl <<'X'
-module(g_plain).
-export([i/1, r/1, f/1, b/1]).
i(N) -> N + 1.
r(O) -> map_get('Total', O).
f(X) -> X * 2.0.
b(X) -> X.
X
cat > g_guard.erl <<'X'
-module(g_guard).
-export([i/1, r/1, f/1, b/1]).
i(N) when is_integer(N) -> N + 1.
r(O) when map_get('Kind', O) =:= 'Bench.Order' -> map_get('Total', O).
f(X) when is_float(X) -> X * 2.0.
b(X) when is_integer(X), X >= 0, X =< 255 -> X.
X
erlc g_plain.erl g_guard.erl
erl -noshell -eval '
 C = fun(M) -> {ok,{_,[{"Code",Code}]}} = beam_lib:chunks(atom_to_list(M)++".beam",["Code"]), byte_size(Code) end,
 P = C(g_plain), G = C(g_guard),
 io:format("whole module (4 fns): plain ~p B, guarded ~p B, delta ~p B~n",[P,G,G-P]),
 halt().'
# one function per module, so the delta is attributable
one() { # one NAME ARG BODY GUARD
  printf -- "-module(p_$1).\n-export([$1/1]).\n$1($2) -> $3.\n" > p_$1.erl
  printf -- "-module(q_$1).\n-export([$1/1]).\n$1($2) when $4 -> $3.\n" > q_$1.erl
  erlc p_$1.erl q_$1.erl
  erl -noshell -eval '
   C = fun(M) -> {ok,{_,[{"Code",Code}]}} = beam_lib:chunks(atom_to_list(M)++".beam",["Code"]), byte_size(Code) end,
   P = C(p_'$1'), G = C(q_'$1'),
   io:format("~-52s plain ~p B  guarded ~p B  delta ~p B~n",[<<"'"$4"'">>,P,G,G-P]), halt().'
}
one i N   "N + 1"              "is_integer(N)"
one r O   "map_get('Total', O)" "map_get('Kind', O) =:= 'Bench.Order'"
one f X   "X * 2.0"            "is_float(X)"
one b X   "X"                  "is_integer(X), X >= 0, X =< 255"
