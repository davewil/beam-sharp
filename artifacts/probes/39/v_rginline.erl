-module(v_rginline).
-compile(inline).
-export([part_two/1, spin_only/1]).

wrap(N) ->
    case erlang:'rem'(case erlang:'rem'(N, 100) of
                        V1 when erlang:is_integer(V1) -> V1
                    end + 100, 100) of
        V2 when erlang:is_integer(V2) -> V2
    end.
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

