-module(v_g_exported).
-export([part_two/1]).
-export([wrap/1, hit/1, spin/4, sign/1, size_/1, clicks/3]).
wrap(N) -> ((N rem 100) + 100) rem 100.

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
