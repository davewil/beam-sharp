#!/usr/bin/env bash
# P9: blast radius of a "module must be present at compile time" check, measured over the repo's own sources.
# (1) static census of every foreign `using :M` in .bs files and in compiler/test/*.erl inline sources;
# (2) for each module: present on the default OTP-25 code path? (3) stock vs prototype verdict per .bs file that has a foreign using.
cd /home/user/beam-sharp
echo "== (1)(2) modules named by foreign using, and whether code:which finds them (default path, no ERL_LIBS)"
{ grep -rhoE --include=*.bs "^using :([a-z_0-9]+|'[^']+')" . ; grep -rhoE "using :([a-z_0-9]+|'[^']+')" compiler/test/*.erl; } 2>/dev/null \
  | grep -v _build | sed 's/^using :\(.*\)$/\1/' | sort | uniq -c | sort -rn > /tmp/p9_mods.txt
erl -noshell -eval '
{ok,B}=file:read_file("/tmp/p9_mods.txt"),
Ls=[string:trim(L)||L<-string:split(binary_to_list(B),"\n",all),L=/=""],
R=[begin [C,M0]=string:split(L," "), M=list_to_atom(string:trim(M0,both,"\x27")), {M,list_to_integer(C),code:which(M)=/=non_existing} end||L<-Ls],
Abs=[{M,C}||{M,C,false}<-R],
io:format("distinct modules: ~p, occurrences: ~p~n",[length(R),lists:sum([C||{_,C,_}<-R])]),
io:format("ABSENT on default path: ~p~n",[Abs]),
io:format("present: ~p~n",[[M||{M,_,true}<-R]]),
halt().'
echo
echo "== (3) per-file verdict, stock vs prototype (default ERL_LIBS unset). Directory = module (F15)."
ST=/tmp/bsbuild/ebin; PR=/tmp/bsb_52_x/ebin
verdict() { # verdict EBIN DIR -> accepted|refused:<first line>
  local out; out=$(cd "$(dirname "$2")" && erl -noshell -pa "$1" -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra -o "$OUT" "$(basename "$2")" 2>&1 | head -1)
  [ -z "$out" ] && echo accepted || echo "refused: $out" | cut -c1-110
}
OUT=$(mktemp -d)
n=0; flip=0
for f in $(grep -rl --include=*.bs "^using :" . | grep -v _build | sort); do
  d=$(dirname "$f")
  s=$(verdict $ST "$d"); p=$(PROTO=1 verdict $PR "$d")
  n=$((n+1)); mark="  "; if [ "$s" = accepted ] && [ "$p" != accepted ]; then mark="!!"; flip=$((flip+1)); fi
  printf '%s %-58s stock=%-10s proto=%s\n' "$mark" "$d" "$(echo $s | cut -c1-9)" "$(echo $p | cut -c1-90)"
done
echo "files with a foreign using: $n ; stock accepts but prototype refuses (flipped): $flip"
