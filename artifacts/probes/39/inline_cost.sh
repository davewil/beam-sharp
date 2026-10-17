#!/usr/bin/env bash
# Cost side of -compile(inline): .beam bytes, compile time, and what a crash inside
# an inlined helper looks like. usage: inline_cost.sh WORKDIR_FROM_run.sh
set -euo pipefail
W="$1"
echo "-- .beam bytes (stripped of nothing; debug_info included)"
for f in "$W/e/e0.beam" "$W/e/e4.beam" "$W/v/bs0.beam" "$W/v/bs4.beam" "$W/v/bs5.beam"; do
  printf '%-22s %s\n' "$(basename "$f")" "$(stat -c %s "$f")"
done
echo "-- stack trace of a crash inside a helper, without and with -compile(inline)"
mkdir -p "$W/st" && cd "$W/st"
for m in st0 st1; do
  { echo "-module($m)."; [ "$m" = st1 ] && echo "-compile(inline)."
    echo "-export([run/1])."
    echo "helper(X) when X > 0 -> X * 2."
    echo "run(X) -> helper(X) + 1."; } > $m.erl
  erlc +debug_info $m.erl
  erl -noshell -eval "try $m:run(-1) catch error:E:St -> io:format(\"$m ~p ~p~n\", [E, [{M,F,A} || {M,F,A,_} <- St]]) end, halt()."
done
