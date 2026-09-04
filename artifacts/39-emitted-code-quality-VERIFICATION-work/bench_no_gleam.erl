%%% Probe variant of aoc/bench/bench.erl for ticket 39 research.
%%%
%%% Gleam is not installed in this sandbox (no apt package, github.com blocked),
%%% so this drops the Gleam leg and times only Erlang, Elixir and beam-sharp.
%%% Otherwise identical methodology to the original: load as .beam, call
%%% directly, check the answer, report min/median over 25 runs.
-module(bench_no_gleam).
-export([main/1]).

-define(RUNS, 25).

main([InputPath]) ->
    Deltas = read(InputPath),
    io:format("~p rotations, ~p clicks simulated per run~n~n",
              [length(Deltas), lists:sum([abs(D) || D <- Deltas])]),
    Impls = [{"Erlang",     fun bench_erl:part_two/1},
             {"Elixir",     fun 'Elixir.BenchEx':part_two/1},
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
        [] -> io:format("~nall three agree on 6770~n");
        _  -> io:format("~nWRONG ANSWER from: ~p~n", [Wrong])
    end.

read(Path) ->
    {ok, Bin} = file:read_file(Path),
    [parse(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""].

parse([$L | N]) -> -list_to_integer(N);
parse([$R | N]) -> list_to_integer(N).
