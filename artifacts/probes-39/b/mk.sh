#!/usr/bin/env bash
# Variants of the Day01 loop whose start position is a PARAMETER of the exported function (so the optimiser cannot
# see the range of Pos at spin/4's entry), with / without a range guard on that parameter.
set -e
common() { cat <<'EOT'
wrap(N) -> ((N rem 100) + 100) rem 100.
hit(0) -> 1;
hit(_) -> 0.
spin(Pos, _Step, 0, Zeros) -> {Pos, Zeros};
spin(Pos, Step, Left, Zeros) ->
    Next = wrap(Pos + Step),
    spin(Next, Step, Left - 1, Zeros + hit(Next)).
sign(D) when D < 0 -> -1;
sign(D) when D >= 0 -> 1.
size_(D) when D < 0 -> -D;
size_(D) when D >= 0 -> D.
clicks([], _Pos, Zeros) -> Zeros;
clicks([D | Rest], Pos, Zeros) ->
    {Next, Hits} = spin(Pos, sign(D), size_(D), Zeros),
    clicks(Rest, Next, Hits).
EOT
}
mk() { # name, part_two clause(s)
  { echo "-module($1)."; echo "-export([part_two/1, part_two/2])."; common; echo "$2"; echo "part_two(Rs) -> part_two(Rs, 50)."; } > $1.erl
  erlc -S $1.erl; erlc $1.erl
}
mk b_const   'part_two(Rs, _P) -> clicks(Rs, 50, 0).'
mk b_unk_a   'part_two(Rs, P) -> clicks(Rs, P, 0).'
mk b_unk_b   'part_two(Rs, P) -> clicks(Rs, P, 0).'
# bs_emit's public-boundary guard is is_integer/1 FIRST, then the range (bs_emit.erl:195-199, :335-350, F24+F37)
mk b_guard_a 'part_two(Rs, P) when is_integer(P), P >= 0, P =< 99 -> clicks(Rs, P, 0).'
mk b_guard_b 'part_two(Rs, P) when is_integer(P), P >= 0, P =< 99 -> clicks(Rs, P, 0).'
# the kind guard alone (what F24 emits for a bare `int` parameter): is_integer(P) with no range
mk b_kind_a  'part_two(Rs, P) when is_integer(P) -> clicks(Rs, P, 0).'
mk b_kind_b  'part_two(Rs, P) when is_integer(P) -> clicks(Rs, P, 0).'
# range carried by an operation the optimiser understands (band), once, at the boundary, after the guard proved 0..99.
mk b_band_a  'part_two(Rs, P) when is_integer(P), P >= 0, P =< 99 -> clicks(Rs, P band 127, 0).'
mk b_band_b  'part_two(Rs, P) when is_integer(P), P >= 0, P =< 99 -> clicks(Rs, P band 127, 0).'
