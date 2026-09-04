%%% Probe v2 counterpart to GrindOnly.bs. spin/4 stays unexported (matching
%%% bench_erl:spin, called only from part_two -> clicks), reached only
%%% through the exported grind/1 wrapper, so its type inference is exactly
%%% what it is in the real benchmark.
-module(grind_only_erl).
-export([grind/1]).

wrap(N) -> ((N rem 100) + 100) rem 100.

hit(0) -> 1;
hit(_) -> 0.

spin(Pos, _Step, 0, Zeros) -> {Pos, Zeros};
spin(Pos, Step, Left, Zeros) ->
    Next = wrap(Pos + Step),
    spin(Next, Step, Left - 1, Zeros + hit(Next)).

grind(Left) -> spin(50, 1, Left, 0).
