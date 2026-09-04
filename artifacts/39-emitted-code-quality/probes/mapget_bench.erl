-module(mapget_bench).
-export([main/0]).
-define(RUNS, 25).
-define(ITERS, 673364).

main() ->
    Impls = [{"get_map_elements (pattern)", fun mapget_probe:via_pattern/1},
             {"map_get BIF (bs_emit's .field)", fun mapget_probe:via_bif/1}],
    Results = [run(Name, F) || {Name, F} <- Impls],
    report(Results),
    halt().

run(Name, F) ->
    Answer = F(?ITERS),
    Times = [begin {T, _} = timer:tc(F, [?ITERS]), T end || _ <- lists:seq(1, ?RUNS)],
    Sorted = lists:sort(Times),
    {Name, Answer, hd(Sorted), lists:nth(?RUNS div 2 + 1, Sorted)}.

report(Results) ->
    io:format("~-34s ~9s ~9s ~8s~n", ["", "min ms", "med ms", "rel"]),
    Base = lists:min([Min || {_, _, Min, _} <- Results]),
    [io:format("~-34s ~9.2f ~9.2f ~7.2fx~n", [Name, Min / 1000, Med / 1000, Min / Base])
     || {Name, _Answer, Min, Med} <- Results].
