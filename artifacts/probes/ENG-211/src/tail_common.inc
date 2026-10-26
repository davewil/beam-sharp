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
