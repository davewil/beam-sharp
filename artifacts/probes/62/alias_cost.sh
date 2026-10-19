#!/usr/bin/env bash
# ticket 62: BEAM size and compile time of exporting a snake_case alias beside each PascalCase function.
# Aliases here are the CHEAPEST form (a local call, `new(X) -> 'New'(X).`); the bsc emitter may differ.
set -eu; cd "$(dirname "$0")"; mkdir -p cost; cd cost; rm -f *.erl *.beam
for N in 5 20 100; do
 for mode in plain alias; do
  M="m_${mode}_$N"; f="$M.erl"; { echo "-module($M)."
   ex=""; for i in $(seq 1 $N); do ex="$ex'Fun$i'/1,"; [ $mode = alias ] && ex="$ex fun_$i/1,"; done
   echo "-export([${ex%,}])."
   for i in $(seq 1 $N); do
     echo "'Fun$i'(#{'Kind':='Shop.Order','Total':=T}) when T > $i -> {ok, T + $i}; 'Fun$i'(_) -> error."
     [ $mode = alias ] && echo "fun_$i(X) -> 'Fun$i'(X)."
   done; } > $f
  s=$(date +%s%N); erlc $f; e=$(date +%s%N)
  printf "N=%-3s %-5s beam=%6s B  exports=%3s  erlc=%4s ms\n" $N $mode $(stat -c%s $M.beam) $(erl -noshell -pa . -eval "io:format(\"~p\",[length($M:module_info(exports))-2]),halt()." ) $(( (e-s)/1000000 ))
 done
done
