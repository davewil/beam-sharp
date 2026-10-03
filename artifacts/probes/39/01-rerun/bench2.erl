%% Same four implementations and the same answer check as aoc/bench/bench.erl, but
%% reports min / median / IQR over N runs, with the order of implementations
%% rotated every round so drift (thermal, GC, neighbours) is spread across them.
-module(bench2).
-export([main/1]).
main([Input, NStr]) ->
    N = list_to_integer(NStr),
    Ds = read(Input),
    Impls = [{"Erlang", fun bench_erl:part_two/1},
             {"Elixir", fun 'Elixir.BenchEx':part_two/1},
             {"Gleam", fun bench_gleam:part_two/1},
             {"beam-sharp", fun 'Day01':'PartTwo'/1}],
    [begin 6770 = F(Ds), [F(Ds) || _ <- lists:seq(1,20)] end || {_, F} <- Impls], % warm
    Rounds = [round(R, Impls, Ds) || R <- lists:seq(0, N-1)],
    io:format("OTP ~s erts ~s, ~p runs/impl, order rotated per round~n",
              [erlang:system_info(otp_release), erlang:system_info(version), N]),
    io:format("~-12s ~8s ~8s ~8s ~8s ~8s ~8s~n", ["", "min ms", "q1", "median", "q3", "IQR", "rel(med)"]),
    Stats = [{Name, stats([T || R <- Rounds, {Nm, T} <- R, Nm =:= Name])} || {Name, _} <- Impls],
    Base = element(3, proplists:get_value("Erlang", Stats)),
    [io:format("~-12s ~8.2f ~8.2f ~8.2f ~8.2f ~8.2f ~7.2fx~n",
       [Name, Mn/1000, Q1/1000, Md/1000, Q3/1000, (Q3-Q1)/1000, Md/Base]) || {Name,{Mn,Q1,Md,Q3}} <- Stats],
    halt().
round(R, Impls, Ds) ->
    {A, B} = lists:split(R rem length(Impls), Impls),
    [begin {T,6770} = timer:tc(F, [Ds]), {Name, T} end || {Name, F} <- B ++ A].
stats(L) -> S = lists:sort(L), Len = length(S),
    {hd(S), lists:nth(Len div 4 + 1, S), lists:nth(Len div 2 + 1, S), lists:nth((3*Len) div 4 + 1, S)}.
read(Path) ->
    {ok, Bin} = file:read_file(Path),
    [parse(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""].
parse([$L | N]) -> -list_to_integer(N);
parse([$R | N]) -> list_to_integer(N).
