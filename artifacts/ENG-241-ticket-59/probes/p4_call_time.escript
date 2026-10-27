#!/usr/bin/env escript
%% H4: a private-function tag test / is_integer test adds less call time than the run-to-run noise
%%     (recorded in ticket 18: below +/-0.09 ns/call).
%% Control (the non-circular part): two byte-identical copies of the UNGUARDED variant are timed
%%     the same way; a guard delta only counts if it exceeds the A-vs-A' delta.
%% Falsifier: guard delta (ns/call, median) clearly above the A-vs-A' delta.
%% Command: escript p4_call_time.escript    Toolchain: OTP 25.3, x86-64, this container (shared, noisy)
-mode(compile).
-define(CALLS, 5000000).
-define(REPS, 51).

src(Mod, Body) ->
    lists:flatten(io_lib:format(
      "-module(~s).\n-export([run/2]).\n-compile({no_inline,[total/1]}).\n"
      "run(0, Acc) -> Acc;\nrun(N, Acc) -> run(N-1, Acc + total(case N band 1 of 0 -> ARG; _ -> ARG end)).\n~s", [Mod, Body])).

load(Mod, Arg, Body) ->
    S = string:replace(src(Mod, Body), "ARG", Arg, all),
    Path = filename:join("/tmp/claude-0", atom_to_list(Mod) ++ ".erl"),
    ok = file:write_file(Path, S),
    {ok, Mod, Bin} = compile:file(Path, [binary, return_errors]),
    {module, Mod} = code:load_binary(Mod, Path, Bin),
    ok.

bench(Mod) ->
    Ts = [element(1, timer:tc(Mod, run, [?CALLS, 0])) || _ <- lists:seq(1, ?REPS)],
    S = lists:sort(Ts),
    {lists:nth(1, S) * 1000 / ?CALLS, lists:nth(?REPS div 2 + 1, S) * 1000 / ?CALLS}.

main(_) ->
    TagNone  = "total(O) -> map_get(total, O) + 1.\n",
    TagGuard = "total(O) when map_get(kind, O) =:= 'P59.Order' -> map_get(total, O) + 1.\n",
    IntNone  = "total(N) when N >= 9 -> 1;\ntotal(N) when N >= 0, N =< 8 -> 0.\n",
    IntGuard = "total(N) when is_integer(N), N >= 9 -> 1;\ntotal(N) when is_integer(N), N >= 0, N =< 8 -> 0.\n",
    Order = "#{kind => 'P59.Order', total => 5, id => 1}",
    ok = load(t_a,  Order, TagNone), ok = load(t_a2, Order, TagNone), ok = load(t_g, Order, TagGuard),
    ok = load(i_a,  "100",  IntNone), ok = load(i_a2, "100",  IntNone), ok = load(i_g, "100",  IntGuard),
    [bench(M) || M <- [t_a, t_g, i_a, i_g]],           % warm-up
    Res = [{M, bench(M)} || M <- [t_a, t_a2, t_g, i_a, i_a2, i_g]],
    [io:format("TIME ~-5s min=~.2f ns/call  median=~.2f ns/call~n", [M, Mn, Md]) || {M, {Mn, Md}} <- Res],
    D = fun(X, Y) -> {_, {_, MX}} = lists:keyfind(X, 1, Res), {_, {_, MY}} = lists:keyfind(Y, 1, Res), MY - MX end,
    io:format("OTP ~s  jit=~p  schedulers_online=~p~n", [erlang:system_info(otp_release), erlang:system_info(emu_flavor), erlang:system_info(schedulers_online)]),
    io:format("NOISE   tag A vs A' (identical)   median delta = ~.2f ns/call~n", [D(t_a, t_a2)]),
    io:format("GUARD   tag guard vs none          median delta = ~.2f ns/call~n", [D(t_a, t_g)]),
    io:format("NOISE   int A vs A' (identical)   median delta = ~.2f ns/call~n", [D(i_a, i_a2)]),
    io:format("GUARD   is_integer vs none         median delta = ~.2f ns/call~n", [D(i_a, i_g)]).
