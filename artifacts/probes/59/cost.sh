#!/usr/bin/env bash
# 59 / cost — Code-chunk bytes and hot-loop ns per private call, per compiler variant.
#   cost.sh BSC...    (labels are the variant dir names; the first is the control, run twice for noise)
set -uo pipefail
for B in "$@"; do
  O=$(mktemp -d); "$B" -o "$O" src/B59/b.bs 2>/dev/null
  erl -noshell -pa "$O" -eval '
  {ok,{_,[{"Code",C}]}} = beam_lib:chunks(code:which('"'"'B59'"'"'),["Code"]),
  Ord = #{'"'"'Kind'"'"' => '"'"'B59.Order'"'"', '"'"'Id'"'"' => 1, '"'"'Total'"'"' => 7},
  N = 20000000,
  Best = fun(F) -> lists:min([element(1, timer:tc(F)) || _ <- lists:seq(1,9)]) end,
  R = Best(fun() -> '"'"'B59'"'"':'"'"'RunRec'"'"'(N, Ord) end),
  I = Best(fun() -> '"'"'B59'"'"':'"'"'RunInt'"'"'(N, 200) end),
  io:format("  Code=~w bytes  rec-loop=~.2f ns/iter  int-loop=~.2f ns/iter~n", [byte_size(C), R*1000/N, I*1000/N]),
  halt().' 2>&1 | grep -v "^$" | head -6
  rm -rf "$O"
done
