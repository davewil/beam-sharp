#!/bin/sh
# Adjunct to the provenance check: the same lookup can also confirm the DECLARED function exists,
# but only if the beam is read, not loaded. code:ensure_loaded runs -on_load code in bsc's VM.
. "$(dirname "$0")/env.sh"
mkdir -p $W/onl && erlc -o $W/onl $FIX/onload/onload_mod.erl
export ERL_LIBS=$W/greeter_build/dev/lib
erl -noshell -pa $W/onl -eval '
io:format("-- beam_lib exports of Elixir.Greeter (no load): ~p~n", [begin {ok,{_,[{exports,E}]}} = beam_lib:chunks(code:which('"'"'Elixir.Greeter'"'"'), [exports]), E end]),
io:format("-- declared hello/2 (typo in arity) would be refused: ~p~n", [lists:member({hello,2}, element(2, element(2, hd([beam_lib:chunks(code:which('"'"'Elixir.Greeter'"'"'), [exports])]))) ++ [])]),
io:format("-- on_load module: does code:which load it? "), _ = code:which(onload_mod), io:format("no output above = not loaded: ~p~n", [erlang:module_loaded(onload_mod)]),
io:format("-- beam_lib:chunks(exports) on it: "), {ok,_} = beam_lib:chunks(code:which(onload_mod), [exports]), io:format("no on_load output either~n"),
io:format("-- code:ensure_loaded(onload_mod): ~n"), code:ensure_loaded(onload_mod),
Bench = fun(Name, N, F) -> Ts = [begin T0 = erlang:monotonic_time(nanosecond), F(), (erlang:monotonic_time(nanosecond)-T0)/1000 end || _ <- lists:seq(1,N)], S = lists:sort(Ts), io:format("  ~-40s median ~.1f us~n", [Name, lists:nth(N div 2, S)]) end,
P = code:which('"'"'Elixir.Greeter'"'"'),
Bench("beam_lib:chunks(exports), file read", 500, fun() -> beam_lib:chunks(P, [exports]) end),
halt().' 2>&1
