%%% Times ONE call to each language's isolated Spin/Wrap/Hit loop with
%%% Left = 673364 (the same total click count bench.erl's whole fold
%%% simulates), instead of the many small spin/4 calls Clicks makes. This
%%% localises ticket 39 §3 item 1: is the cost in the loop itself, or in the
%%% outer Clicks/Sign/Size/list-fold machinery.
-module(isolated_bench).
-export([main/0]).

-define(RUNS, 25).

main() ->
    Left = 673364,
    Impls = [{"Erlang",     fun spin_isolated:run/1},
             {"Elixir",     fun 'Elixir.SpinIsolated':run/1},
             {"Gleam",      fun spin_isolated_gleam:run/1},
             {"beam-sharp", fun 'Day01Isolated':'Run'/1}],
    Results = [run(Name, F, Left) || {Name, F} <- Impls],
    report(Results),
    halt().

run(Name, F, Left) ->
    Answer = F(Left),
    Times = [begin {T, _} = timer:tc(F, [Left]), T end || _ <- lists:seq(1, ?RUNS)],
    Sorted = lists:sort(Times),
    {Name, Answer, hd(Sorted), lists:nth(?RUNS div 2 + 1, Sorted)}.

report(Results) ->
    io:format("~-12s ~-16s ~9s ~9s ~8s~n",
              ["", "answer", "min ms", "med ms", "rel"]),
    Base = lists:min([Min || {_, _, Min, _} <- Results]),
    [io:format("~-12s ~-16s ~9.3f ~9.3f ~7.2fx~n",
               [Name, io_lib:format("~p", [Answer]), Min / 1000, Med / 1000,
                Min / Base])
     || {Name, Answer, Min, Med} <- Results].
