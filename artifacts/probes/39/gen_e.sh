#!/usr/bin/env bash
# Generates e0..e3 into $1 (one module each) from a single template.
set -euo pipefail
out=$1; mkdir -p "$out"
common='
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
'
spin_plain='
spin(Pos, _Step, 0, Zeros) -> {Pos, Zeros};
spin(Pos, Step, Left, Zeros) ->
    Next = wrap(Pos + Step),
    spin(Next, Step, Left - 1, Zeros + hit(Next)).
'
spin_guard='
spin(Pos, _Step, 0, Zeros) when is_integer(Pos), Pos >= 0, Pos =< 99 -> {Pos, Zeros};
spin(Pos, Step, Left, Zeros) when is_integer(Pos), Pos >= 0, Pos =< 99, Step >= -1, Step =< 1 ->
    Next = wrap(Pos + Step),
    spin(Next, Step, Left - 1, Zeros + hit(Next)).
'
mk() { # name wrapdef spindef extra
  printf -- '-module(%s).\n-export([part_two/1]).\n%s\n%s\n%s\n%s\n' "$1" "$4" "$2" "$3" "$common" > "$out/$1.erl"
}
mk e0 'wrap(N) -> ((N rem 100) + 100) rem 100.' "$spin_plain" ''
mk e1 'wrap(N) -> opaque:id(((N rem 100) + 100) rem 100).' "$spin_plain" ''
mk e2 'wrap(N) -> opaque:id(((N rem 100) + 100) rem 100).' "$spin_guard" ''
mk e4 'wrap(N) -> ((N rem 100) + 100) rem 100.' "$spin_plain" '-compile(inline).'
mk e3 'wrap(N) -> ((N rem 100) + 100) rem 100.' "$spin_plain" '-spec wrap(integer()) -> 0..99.'
printf -- '-module(opaque).\n-export([id/1]).\nid(X) -> X.\n' > "$out/opaque.erl"
