-module(mapget_bench3).
-export([main/0]).
-define(RUNS, 25).
-define(ITERS, 673364).

%% Same as mapget_bench2 but REVERSED impl order, to test for an
%% order/warm-up artifact in the single-process sequential benchmark.
main() ->
    Impls = [{"case+map-pattern (proposed lowering)", fun mapget_probe2:via_case/1},
             {"map_get BIF (bs_emit's .field today)", fun mapget_probe2:via_bif/1},
             {"get_map_elements (pattern match)", fun mapget_probe2:via_pattern/1}],
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
