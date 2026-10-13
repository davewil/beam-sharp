#!/usr/bin/env bash
# Ticket 59 P4: widening cost on REAL code: every example module that compiles standalone. BSC=<bsc> corpus_cost.sh
# Prints total Code-chunk bytes over the corpus, and Fib(20000) time (private 4-int-param tail recursion).
set -u
BSC=${BSC:?}; HERE=$(cd "$(dirname "$0")" && pwd); EX=$HERE/../../../compiler/examples
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT; mkdir "$W/out"
for m in Fib Counter Ledger Levels Math Pipeline Queue Readings Stats Stream Wire Frame Intake Parcel Label Names Escalate Shop; do
  "$BSC" --src-root "$EX" -o "$W/out" "$EX/$m" >/dev/null 2>&1
done
erl -noshell -eval '
  Fs = filelib:wildcard("'"$W"'/out/*.beam"),
  Tot = lists:sum([begin {ok,{_,[{"Code",C}]}} = beam_lib:chunks(F,["Code"]), byte_size(C) end || F <- Fs]),
  io:format("modules=~p total Code-chunk bytes=~p~n",[length(Fs), Tot]), halt().'
erl -noshell -pa "$W/out" -eval '
  N = 20000, F = fun() -> '"'"'Fib'"'"':'"'"'Fib'"'"'(N) end,
  L = lists:sort([element(1, timer:tc(F)) || _ <- lists:seq(1, 201)]),
  io:format("Fib(20000) median over 201 runs: ~p us~n",[lists:nth(101,L)]), halt().' 2>&1 | tail -2
