#!/bin/bash
# Ticket 39 §3.3: does handing the JIT a range (as a guard does) make hot arithmetic faster — i.e. is there a ceiling
# above plain Erlang that an interval-aware emitter could reach? Pure Erlang; no bsc involved, so it bounds the idea only.
. "$(dirname "$0")/../env.sh"
work 39c
cat > ceil.erl <<'B'
-module(ceil).
-export([run/0]).
%% same arithmetic; the second form is what bsc would emit for `int where value >= 0 and value <= 1000` params
unb(0, _, Acc) -> Acc;
unb(N, X, Acc) -> unb(N - 1, X, (Acc + mix(X, N rem 1001)) rem 1000003).
mix(A, B) -> (A * B + A) rem 997.

bnd(0, _, Acc) -> Acc;
bnd(N, X, Acc) -> bnd(N - 1, X, (Acc + mixb(X, N rem 1001)) rem 1000003).
mixb(A, B) when is_integer(A), A >= 0, A =< 1000, is_integer(B), B >= 0, B =< 1000 -> (A * B + A) rem 997.

t(F) -> lists:min([element(1, timer:tc(F)) || _ <- lists:seq(1, 25)]).
run() ->
    N = 3000000,
    U = t(fun() -> unb(N, 500, 0) end),
    B = t(fun() -> bnd(N, 500, 0) end),
    io:format("  unbounded ~6.2f ms   range-guarded ~6.2f ms   ratio ~.3f   (~p iterations, min of 25)~n",
              [U/1000, B/1000, B/U, N]),
    halt().
B
for otp in otp28 beam; do
  E=$S/mamba/envs/$otp/bin; mkdir -p $otp; $E/erlc -S -o $otp ceil.erl; $E/erlc -o $otp ceil.erl
  echo "=== $otp: {tr,} operands in mix/mixb asm: $(grep -c 'tr,' $otp/ceil.S)"
  $E/erl -noshell +S 1:1 -pa $otp -eval 'ceil:run()'
done
