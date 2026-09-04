%%% Probe for ticket 39 sub-investigation #1: hand-written Erlang counterpart
%%% to SpinOnly.bs / bench_erl:spin — the hot loop in isolation, called
%%% directly (no Clicks fold, no list traversal, no Sign/Size per click).
-module(spin_only_erl).
-export([spin/4]).

wrap(N) -> ((N rem 100) + 100) rem 100.

hit(0) -> 1;
hit(_) -> 0.

spin(Pos, _Step, 0, Zeros) -> {Pos, Zeros};
spin(Pos, Step, Left, Zeros) ->
    Next = wrap(Pos + Step),
    spin(Next, Step, Left - 1, Zeros + hit(Next)).
