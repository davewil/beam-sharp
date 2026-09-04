-module(bench_rev).
-export([main/1]).
-define(RUNS, 25).
main([InputPath]) ->
    Deltas = read(InputPath),
    Impls = [{"beam-sharp", fun 'Day01':'PartTwo'/1},
             {"Elixir",     fun 'Elixir.BenchEx':part_two/1},
             {"Erlang",     fun bench_erl:part_two/1}],
    Results = [run(Name, F, Deltas) || {Name, F} <- Impls],
    report(Results),
    halt().
run(Name, F, Deltas) ->
    Answer = F(Deltas),
    Times = [begin {T, _} = timer:tc(F, [Deltas]), T end || _ <- lists:seq(1, ?RUNS)],
    Sorted = lists:sort(Times),
    {Name, Answer, hd(Sorted), lists:nth(?RUNS div 2 + 1, Sorted)}.
report(Results) ->
    io:format("~-12s ~-8s ~9s ~9s ~8s~n", ["", "answer", "min ms", "med ms", "rel"]),
    Base = lists:min([Min || {_, _, Min, _} <- Results]),
    [io:format("~-12s ~-8s ~9.2f ~9.2f ~7.2fx~n", [Name, integer_to_list(Answer), Min / 1000, Med / 1000, Min / Base]) || {Name, Answer, Min, Med} <- Results].
read(Path) ->
    {ok, Bin} = file:read_file(Path),
    [parse(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""].
parse([$L | N]) -> -list_to_integer(N);
parse([$R | N]) -> list_to_integer(N).
