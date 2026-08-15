%%% Times four BEAM implementations of AoC 2025 Day 1 part two.
%%%
%%% FAIRNESS. Every one of these compiles to BEAM bytecode and runs on the same
%%% VM, so what is being compared is the EMITTED CODE, not the toolchain. The
%%% harness therefore:
%%%   * loads all four as .beam and calls the function directly, so no CLI
%%%     startup, no compile step and no `erl` boot is inside the number;
%%%   * checks the ANSWER first, because a fast wrong answer is worth nothing;
%%%   * reports the MINIMUM over N runs as well as the median, since a
%%%     micro-benchmark's noise is one-sided — nothing makes it accidentally
%%%     faster.
-module(bench).
-export([main/1]).

-define(RUNS, 25).

main([InputPath]) ->
    Deltas = read(InputPath),
    io:format("~p rotations, ~p clicks simulated per run~n~n",
              [length(Deltas), lists:sum([abs(D) || D <- Deltas])]),
    Impls = [{"Erlang",     fun bench_erl:part_two/1},
             {"Elixir",     fun 'Elixir.BenchEx':part_two/1},
             {"Gleam",      fun bench_gleam:part_two/1},
             {"beam-sharp", fun 'Day01':'PartTwo'/1}],
    Results = [run(Name, F, Deltas) || {Name, F} <- Impls],
    report(Results),
    halt().

run(Name, F, Deltas) ->
    Answer = F(Deltas),
    Times = [begin {T, _} = timer:tc(F, [Deltas]), T end
             || _ <- lists:seq(1, ?RUNS)],
    Sorted = lists:sort(Times),
    {Name, Answer, hd(Sorted), lists:nth(?RUNS div 2 + 1, Sorted)}.

report(Results) ->
    io:format("~-12s ~-8s ~9s ~9s ~8s~n",
              ["", "answer", "min ms", "med ms", "rel"]),
    Base = lists:min([Min || {_, _, Min, _} <- Results]),
    [io:format("~-12s ~-8s ~9.2f ~9.2f ~7.2fx~n",
               [Name, integer_to_list(Answer), Min / 1000, Med / 1000,
                Min / Base])
     || {Name, Answer, Min, Med} <- Results],
    Wrong = [N || {N, A, _, _} <- Results, A =/= 6770],
    case Wrong of
        [] -> io:format("~nall four agree on 6770~n");
        _  -> io:format("~nWRONG ANSWER from: ~p~n", [Wrong])
    end.

read(Path) ->
    {ok, Bin} = file:read_file(Path),
    [parse(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""].

parse([$L | N]) -> -list_to_integer(N);
parse([$R | N]) -> list_to_integer(N).
