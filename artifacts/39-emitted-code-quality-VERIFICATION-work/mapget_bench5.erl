-module(mapget_bench5).
-export([main/0]).
-define(RUNS, 25).
-define(ITERS, 673364).

%% Original order, but with a warm-up call + explicit GC before each impl's
%% timed loop, to test whether that removes the order-dependent artifact
%% seen in mapget_bench2/3 (identical-bytecode functions running at
%% different speeds purely by position in the sequence).
main() ->
    Impls = [{"get_map_elements (pattern match)", fun mapget_probe2:via_pattern/1},
             {"map_get BIF (bs_emit's .field today)", fun mapget_probe2:via_bif/1},
             {"case+map-pattern (proposed lowering)", fun mapget_probe2:via_case/1}],
    Results = [run(Name, F) || {Name, F} <- Impls],
    report(Results),
    halt().

run(Name, F) ->
    _ = F(?ITERS),
    _ = F(?ITERS),
    erlang:garbage_collect(),
    Times = [begin {T, _} = timer:tc(F, [?ITERS]), T end || _ <- lists:seq(1, ?RUNS)],
    Sorted = lists:sort(Times),
    {Name, hd(Sorted), lists:nth(?RUNS div 2 + 1, Sorted)}.

report(Results) ->
    io:format("~-34s ~9s ~9s ~8s~n", ["", "min ms", "med ms", "rel"]),
    Base = lists:min([Min || {_, Min, _} <- Results]),
    [io:format("~-34s ~9.2f ~9.2f ~7.2fx~n", [Name, Min / 1000, Med / 1000, Min / Base])
     || {Name, Min, Med} <- Results].
