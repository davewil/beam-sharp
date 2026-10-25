%% UPPER-BOUND ESTIMATE, NOT AN EMITTER OUTPUT (ticket 39 §3.3).
%% Same algorithm as aoc/bench/bench_erl.erl, with ONE hand-applied fact: pos is 0..99 and step is -1|1, so pos+step is
%% -1..100 and the double `rem` collapses to a two-way fix-up. A compiler that carried `pos: 0..99` from a refinement
%% could in principle emit this; none does today. -compile(inline) is on so it is comparable with the inlined variants.
-module(oracle).
-export([part_two/1]).
-compile(inline).

wrap(-1) -> 99;
wrap(100) -> 0;
wrap(N) -> N.

hit(0) -> 1;
hit(_) -> 0.

spin(Pos, _Step, 0, Zeros) -> {Pos, Zeros};
spin(Pos, Step, Left, Zeros) ->
    Next = wrap(Pos + Step),
    spin(Next, Step, Left - 1, Zeros + hit(Next)).

sign(0) -> 1;
sign(D) when D > 0 -> 1;
sign(D) when D < 0 -> -1.

size_(D) when D >= 0 -> D;
size_(D) when D < 0 -> -D.

clicks([], _Pos, Zeros) -> Zeros;
clicks([D | Rest], Pos, Zeros) ->
    {Next, Hits} = spin(Pos, sign(D), size_(D), Zeros),
    clicks(Rest, Next, Hits).

part_two(Rs) -> clicks(Rs, 50, 0).
