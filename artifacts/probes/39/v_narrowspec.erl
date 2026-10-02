-module(v_narrowspec).
-export([part_two/1, spin_only/1]).
-spec wrap(integer()) -> 0..99.
-spec hit(0..99) -> 0..1.
-spec spin(0..99, -1..1, 0..16#7FFFFFF, 0..16#7FFFFFF) -> {0..99, 0..16#7FFFFFF}.
-spec spin_only(0..16#7FFFFFF) -> {0..99, 0..16#7FFFFFF}.
-spec part_two([integer()]) -> 0..16#7FFFFFF.

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
spin_only(Left) -> spin(50, 1, Left, 0).

