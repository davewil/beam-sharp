-module(xmod_b_specd).
-export([spin_only/2]).

spin(Pos, _Step, 0, Zeros) -> {Pos, Zeros};
spin(Pos, Step, Left, Zeros) ->
    Next = xmod_a_specd:wrap(Pos + Step),
    spin(Next, Step, Left - 1, Zeros + xmod_a_specd:hit(Next)).

spin_only(Step, Left) -> spin(50, Step, Left, 0).
