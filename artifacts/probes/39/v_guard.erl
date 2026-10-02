-module(v_guard).
-export([part_two/1, spin_only/1]).

wrap(N) -> ((N rem 100) + 100) rem 100.
hit(0) -> 1;
hit(_) -> 0.

spin(Pos, _Step, 0, Zeros) when is_integer(Pos), Pos >= 0, Pos =< 99, is_integer(Zeros), Zeros >= 0, Zeros =< 16#7FFFFFF -> {Pos, Zeros};
spin(Pos, Step, Left, Zeros) when is_integer(Pos), Pos >= 0, Pos =< 99, is_integer(Step), Step >= -1, Step =< 1,
                                  is_integer(Left), Left >= 0, Left =< 16#7FFFFFF, is_integer(Zeros), Zeros >= 0, Zeros =< 16#7FFFFFF ->
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
spin_only(Left) -> spin(50, 1, Left, 0).

