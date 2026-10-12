#!/usr/bin/env bash
# Probe 64/06 - lookup loop: bare return vs {ok,V} return (>=5 runs, min and median), plus GC pressure.
set -u
cd "$(dirname "$0")"
W=$(mktemp -d); trap 'rm -rf $W' EXIT
erlc -o $W lk.erl || exit 1
erl -noshell -pa $W -eval 'lk:bench(), halt().'
echo
echo "--- GC pressure: minor collections in a fresh process over one 3,000,000-lookup run (the tagged return allocates a 3-word tuple per hit)"
erl -noshell -pa $W -eval '
M = maps:from_list([{I, I} || I <- lists:seq(0, 999)]),
Run = fun(F) ->
  Self = self(),
  spawn_link(fun() ->
     {_, R0} = process_info(self(), reductions),
     erlang:garbage_collect(),
     F(),
     {_, GC} = process_info(self(), garbage_collection),
     Self ! {done, proplists:get_value(minor_gcs, GC), process_info(self(), reductions)} end),
  receive {done, G, {_, R}} -> {G, R} end end,
{GB, RB} = Run(fun() -> lk:nbare(3000000, M, 0) end),
{GO, RO} = Run(fun() -> lk:nok(3000000, M, 0) end),
io:format("3,000,000 lookups: bare  minor_gcs=~p reductions=~p~n", [GB, RB]),
io:format("3,000,000 lookups: ok    minor_gcs=~p reductions=~p~n", [GO, RO]),
halt().'
echo
echo "--- does the compiler really emit the tuple allocation for the tagged return? (lk.S: put_tuple2 of {atom,ok})"
erlc -S -o $W lk.erl
grep -n "put_tuple2,{x,0},{list,\[{atom,ok}" $W/lk.S
