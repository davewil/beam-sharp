-module(shape_bench_rev).
-export([main/0]).
-define(RUNS, 25).
-define(ITERS, 673364).
main() ->
    Impls = [{"beam-sharp", fun 'ShapeBench':'Grind'/1},
             {"Erlang",     fun shape_bench_erl:grind/1}],
    Results = [run(Name, F) || {Name, F} <- Impls],
    report(Results),
    halt().
run(Name, F) ->
    Answer = F(?ITERS),
    Times = [begin {T, _} = timer:tc(F, [?ITERS]), T end || _ <- lists:seq(1, ?RUNS)],
    Sorted = lists:sort(Times),
    {Name, Answer, hd(Sorted), lists:nth(?RUNS div 2 + 1, Sorted)}.
report(Results) ->
    io:format("~-12s ~-14s ~9s ~9s ~8s~n", ["", "answer", "min ms", "med ms", "rel"]),
    Base = lists:min([Min || {_, _, Min, _} <- Results]),
    [io:format("~-12s ~-14s ~9.2f ~9.2f ~7.2fx~n", [Name, integer_to_list(Answer), Min / 1000, Med / 1000, Min / Base]) || {Name, Answer, Min, Med} <- Results].
