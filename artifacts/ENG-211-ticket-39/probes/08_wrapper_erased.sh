#!/usr/bin/env bash
# H8: bsc's `case erlang:rem(..) of V when is_integer(V) -> V end` foreign-return wrapper (visible in
# Day01.abstr, `Wrap`) leaves no instruction in the optimized beam. Falsified if Wrap/Spin/Clicks instruction
# sequences (labels and names normalised) differ between bench_erl.erl and bsc's Day01.
# SCOPE: Wrap, Hit, Spin, Clicks only. Sign and Size are expected DIFFER: aoc/bench/Day01/bench_bs.bs writes them as
# two clauses (`d < 0` / `d >= 0`) where bench_erl.erl has three (`0`, `D > 0`, `D < 0`), so their sources differ; they run 4,732x, not 673k x.
set -e
W=/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/bsc39/v07
cd $W
norm() { sed -n "/^{function, $1,/,/^\$/p" "$2" | grep -vE 'func_info|\{label|\{line|\{function|var_info' | sed -E 's/\{f,[0-9]+\}/{f,N}/g; s/\{call(_last|_only)?,([0-9]+),\{f,N\}(,[0-9]+)?\}\.? ?(%.*)?/{call\1,\2}/; s/%.*//' | tr -s ' \n' ' '; }
for p in "wrap 'Wrap'" "hit 'Hit'" "spin 'Spin'" "sign 'Sign'" "size_ 'Size'" "clicks 'Clicks'"; do
  set -- $p
  A=$(norm $1 bench_erl.S | sed -E 's/\{tr,\{[xy],[0-9]+\},[^}]*\}+\}?/R/g'); B=$(norm $2 Day01.S | sed -E 's/\{tr,\{[xy],[0-9]+\},[^}]*\}+\}?/R/g')
  A=$(echo "$A" | sed -E "s/bench_erl/M/g; s/\b(wrap|hit|spin|sign|size_|clicks)\b//g; s/'(Wrap|Hit|Spin|Sign|Size|Clicks)'//g")
  B=$(echo "$B" | sed -E "s/'Day01'/M/g; s/\b(wrap|hit|spin|sign|size_|clicks)\b//g; s/'(Wrap|Hit|Spin|Sign|Size|Clicks)'//g")
  [ "$A" = "$B" ] && echo "$1: instruction sequences IDENTICAL ($(echo "$A" | grep -o '{' | wc -l) tuples)" || { echo "$1: DIFFER"; echo " erl: $A"; echo " bsc: $B"; }
done
