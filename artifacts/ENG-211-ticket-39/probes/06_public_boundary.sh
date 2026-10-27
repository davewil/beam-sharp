#!/usr/bin/env bash
# ticket 39 §3.3. Hypothesis H6: bsc proves a parameter is 0..255 and the proof reaches the optimizer in
# the emitted code of a PUBLIC function (guard + {tr} range on the `+` operand). Falsified if the `+`
# operand in Next's asm is `t_integer,any` (the range was proven by the checker and discarded at emission).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
W=/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/bsc39; O=$W/v06; rm -rf $O; mkdir -p $O
erl -noshell -pa $W/ebin -eval 'bsc:main(["-o","'$O'","'$HERE'/Octets"]),halt().'
cd $O && erlc +from_abstr -S Octets.abstr
echo "--- emitted .abstr clause of Next (guard as bsc writes it)"; grep -n -A14 "function,.*'Next'" Octets.abstr | head -30
echo "--- asm for Next and Bump"; sed -n "/function, 'Next'/,/^\$/p;/function, 'Bump'/,/^\$/p" Octets.S
