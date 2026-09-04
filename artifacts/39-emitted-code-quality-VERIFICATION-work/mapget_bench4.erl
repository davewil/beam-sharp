-module(mapget_bench4).
-export([main/0]).
-define(RUNS, 25).
-define(ITERS, 673364).

%% Each impl run in its own FRESH spawned process (heap discarded on exit,
%% no GC bleed across impls), to test whether the ordering artifact in
%% mapget_bench2/3 is caused by shared-process warm-up/GC state.
main() ->
    Impls = [{"get_map_elements (pattern match)", fun mapget_probe2:via_pattern/1},
             {"map_get BIF (bs_emit's .field today)", fun mapget_probe2:via_bif/1},
             {"case+map-pattern (proposed lowering)", fun mapget_probe2:via_case/1}],
    Results = [run(Name, F) || {Name, F} <- Impls],
    report(Results),
    halt().

run(Name, F) ->
    Self = self(),
    Times = [begin
                 spawn(fun() ->
                     {T, _} = timer:tc(F, [?ITERS]),
                     Self ! {time, T}
                 end),
                 receive {time, T} -> T end
             end || _ <- lists:seq(1, ?RUNS)],
    Sorted = lists:sort(Times),
    {Name, hd(Sorted), lists:nth(?RUNS div 2 + 1, Sorted)}.

report(Results) ->
    io:format("~-34s ~9s ~9s ~8s~n", ["", "min ms", "med ms", "rel"]),
    Base = lists:min([Min || {_, Min, _} <- Results]),
    [io:format("~-34s ~9.2f ~9.2f ~7.2fx~n", [Name, Min / 1000, Med / 1000, Min / Base])
     || {Name, Min, Med} <- Results].
