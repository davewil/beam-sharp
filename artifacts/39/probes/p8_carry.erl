%% Three ways Erlang-side code could tell the optimiser "wrap/1 returns 0..99":
%% a) nothing (baseline, what bsc emits today plus a widened spec)
%% b) -spec with a range  (what bs_emit COULD emit: the algebra holds the interval)
%% c) a result guard in a case (what the boundary guards bs@rv already do for is_integer)
-module(p8_carry).
-export([a/1, b/1, c/1]).
-spec wa(integer()) -> integer().
wa(N) -> ((N rem 100) + 100) rem 100.
-spec wb(integer()) -> 0..99.
wb(N) -> ((N rem 100) + 100) rem 100.
wc(N) -> case ((N rem 100) + 100) rem 100 of R when R >= 0, R < 100 -> R end.
hit(0) -> 1;
hit(_) -> 0.
a(N) -> hit(wa(N) + 1).
b(N) -> hit(wb(N) + 1).
c(N) -> hit(wc(N) + 1).
