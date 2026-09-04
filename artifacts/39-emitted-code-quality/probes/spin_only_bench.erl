%%% Probe for ticket 39 sub-investigation #1 ("Is the gap in Spin at all?").
%%% Calls the hot Spin/4 loop directly with the same total iteration count
%%% as the full Day01 benchmark (673364), bypassing Clicks' list traversal
%%% and per-click Sign/Size calls. Same methodology as aoc/bench/bench.erl:
%%% load as .beam, call directly, min/median of 25 runs.
-module(spin_only_bench).
-export([main/0]).

-define(RUNS, 25).
-define(ITERS, 673364).

main() ->
    Impls = [{"Erlang",     fun spin_only_erl:spin/4},
             {"beam-sharp", fun 'SpinOnly':'Spin'/4}],
    Results = [run(Name, F) || {Name, F} <- Impls],
    report(Results),
    halt().

run(Name, F) ->
    Answer = F(50, 1, ?ITERS, 0),
    Times = [begin {T, _} = timer:tc(F, [50, 1, ?ITERS, 0]), T end
             || _ <- lists:seq(1, ?RUNS)],
    Sorted = lists:sort(Times),
    {Name, Answer, hd(Sorted), lists:nth(?RUNS div 2 + 1, Sorted)}.

report(Results) ->
    io:format("~-12s ~-18s ~9s ~9s ~8s~n",
              ["", "answer", "min ms", "med ms", "rel"]),
    Base = lists:min([Min || {_, _, Min, _} <- Results]),
    [io:format("~-12s ~-18s ~9.2f ~9.2f ~7.2fx~n",
               [Name, lists:flatten(io_lib:format("~p", [Answer])),
                Min / 1000, Med / 1000, Min / Base])
     || {Name, Answer, Min, Med} <- Results].
