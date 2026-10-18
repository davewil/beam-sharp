#!/usr/bin/env bash
# 07 — the time cost of ONE tag test / ONE kind test per call, hand-written Erlang,
# no bsc in the loop (so a bsc emission quirk cannot be what is measured).
# A private (non-exported) callee, called 30M times from a tail-recursive loop.
HERE0="$(cd "$(dirname "$0")" && pwd)"; source "$HERE0/lib.sh"; cd "$WORK"
cat > h.erl <<'X'
-module(h).
-export([plain_rec/2, tag_rec/2, plain_int/2, kind_int/2, tag_and_clause/2]).
-compile({no_inline, [get_p/1, get_t/1, inc_p/1, inc_k/1]}).
-define(O, #{'Kind' => 'Bench.Order', 'Id' => 1, 'Total' => 1}).
plain_rec(N, _) -> lp(N, ?O, 0).
lp(0, _, A) -> A;
lp(N, O, A) -> lp(N - 1, O, A + get_p(O)).
get_p(O) -> map_get('Total', O).

tag_rec(N, _) -> lt(N, ?O, 0).
lt(0, _, A) -> A;
lt(N, O, A) -> lt(N - 1, O, A + get_t(O)).
get_t(O) when map_get('Kind', O) =:= 'Bench.Order' -> map_get('Total', O).

%% what bsc v0 emits for a two-clause private fn: the test is repeated per clause
tag_and_clause(N, _) -> lc(N, ?O, 0).
lc(N, O, A) when map_get('Kind', O) =:= 'Bench.Order' andalso N =< 0 -> A;
lc(N, O, A) when map_get('Kind', O) =:= 'Bench.Order' -> lc(N - 1, O, A + get_t(O)).

plain_int(N, _) -> li(N, 0).
li(0, A) -> A;
li(N, A) -> li(N - 1, inc_p(A)).
inc_p(A) -> A + 1.

kind_int(N, _) -> lk(N, 0).
lk(N, A) when is_integer(N) andalso N =< 0 -> A;
lk(N, A) when is_integer(N) -> lk(N - 1, inc_k(A)).
inc_k(A) when is_integer(A) -> A + 1.
X
erlc h.erl
erl -noshell -eval '
 N = 30000000,
 T = fun(F) -> L = lists:sort([element(1,timer:tc(fun() -> h:F(N, x) end)) || _ <- lists:seq(1,9)]), {hd(L)/1000, lists:nth(5,L)/1000} end,
 [begin {Mn,Md} = T(F), io:format("~-16s min ~7.1f ms  median ~7.1f ms  ~.2f ns/iter~n",[F,Mn,Md,Mn*1000000/N]) end
   || F <- [plain_rec, tag_rec, tag_and_clause, plain_int, kind_int]],
 halt().'
