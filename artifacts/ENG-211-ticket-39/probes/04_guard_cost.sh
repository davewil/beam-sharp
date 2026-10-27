#!/usr/bin/env bash
# ticket 39 §3.3 cost side. Hypothesis H4: emitting a proven range as a guard in the hot loop costs >=10%
# unless the optimizer elides it. Variants of bench_erl's loop:
#   a  plain (== bench_erl)          a2 byte-identical control (noise floor)
#   b  `when Left > 0` on the recursive clause (the README's accidental guard)
#   c  range guard on Pos: `when Pos >= -99, Pos =< 99` (a fact the optimizer already infers => may be elided)
#   d  a TRUE guard the optimizer cannot already know: `when Zeros >= 0, Zeros =< 1000000` (first draft used Pos =< 98, which is false at Pos=99; the answer check caught it, so it was replaced, not tuned)
# Falsified if b,d stay within the a-vs-a2 noise. Also prints test instructions emitted per variant.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
W=/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/bsc39/v04; rm -rf $W; mkdir -p $W; cd $W
gen() { # modname, guardline for the recursive clause
cat > $1.erl <<EOF
-module($1).
-export([part_two/1]).
wrap(N) -> ((N rem 100) + 100) rem 100.
hit(0) -> 1;
hit(_) -> 0.
spin(Pos, _Step, 0, Zeros) -> {Pos, Zeros};
spin(Pos, Step, Left, Zeros) $2 ->
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
EOF
}
gen va ""; gen va2 ""; gen vb "when Left > 0"; gen vc "when Pos >= -99, Pos =< 99"; gen vd "when Zeros >= 0, Zeros =< 1000000"
for m in va va2 vb vc vd; do erlc -S $m.erl; erlc $m.erl
  printf "%-4s beam=%5sB  is_ge/lt tests in spin: %s  body instr lines: %s\n" $m "$(stat -c%s $m.beam)" \
   "$(sed -n '/^{function, spin/,/^$/p' $m.S | grep -cE 'is_ge|is_lt|is_eq_exact')" \
   "$(sed -n '/^{function, spin/,/^$/p' $m.S | grep -cE '^    \{')"; done
cp "$HERE/bench_mods.erl" . && erlc bench_mods.erl
erl -noshell -pa $W -s bench_mods main /home/user/beam-sharp/aoc/2025/Day01/input.txt va va2 vb vc vd
