#!/usr/bin/env bash
# What does an emitted range guard on a PRIVATE hot function cost when the optimiser cannot use it?
# e_base: bench_erl loop (annotated by inference).  e_guard: spin/4 second clause gets  is_integer(Pos), Pos >= 0 .. but
# Pos in the loop is -99..99 for erl (see a/), so use the real domain of the B# type Cell = 0..99 on Next (the value returned by wrap).
body() { cat <<'EOT'
wrap(N) -> ((N rem 100) + 100) rem 100.
hit(0) -> 1;
hit(_) -> 0.
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
EOT
}
mk() { { echo "-module($1)."; echo "-export([part_two/1])."; echo "$2"; body; } > $1.erl; erlc -S $1.erl; erlc $1.erl; }
SPIN_BASE='spin(Pos, _Step, 0, Zeros) -> {Pos, Zeros};
spin(Pos, Step, Left, Zeros) -> Next = wrap(Pos + Step), spin(Next, Step, Left - 1, Zeros + hit(Next)).'
SPIN_G='spin(Pos, _Step, 0, Zeros) -> {Pos, Zeros};
spin(Pos, Step, Left, Zeros) when is_integer(Pos), Pos >= -99, Pos =< 99 -> Next = wrap(Pos + Step), spin(Next, Step, Left - 1, Zeros + hit(Next)).'
mk e_base_a "$SPIN_BASE"
mk e_base_b "$SPIN_BASE"
mk e_guard_a "$SPIN_G"
mk e_guard_b "$SPIN_G"
# a guard stating a fact the optimiser CANNOT already prove (Left is a plain integer): real tests, no typing benefit.
SPIN_L='spin(Pos, _Step, 0, Zeros) -> {Pos, Zeros};
spin(Pos, Step, Left, Zeros) when is_integer(Left), Left >= 0, Left =< 1000000 -> Next = wrap(Pos + Step), spin(Next, Step, Left - 1, Zeros + hit(Next)).'
mk e_left_a "$SPIN_L"
mk e_left_b "$SPIN_L"
