%%% Probe for ticket 39 sub-decision 1: isolates ONLY the hot wrap/spin loop
%%% (no list traversal, no Clicks fold). Body is a verbatim copy of
%%% aoc/bench/bench_erl.erl's wrap/1, hit/1 and spin/4 — unmodified — with a
%%% new spin_only/2 entry point added so it can be timed directly.
-module(probe_erl_spin).
-export([spin_only/2]).

wrap(N) -> ((N rem 100) + 100) rem 100.

hit(0) -> 1;
hit(_) -> 0.

spin(Pos, _Step, 0, Zeros) -> {Pos, Zeros};
spin(Pos, Step, Left, Zeros) ->
    Next = wrap(Pos + Step),
    spin(Next, Step, Left - 1, Zeros + hit(Next)).

spin_only(Step, Left) -> spin(50, Step, Left, 0).
