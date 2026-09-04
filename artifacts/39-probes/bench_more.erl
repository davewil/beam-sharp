%%% Probe for ticket 39: same logic as aoc/bench/bench.erl, but with more
%%% runs (200 instead of 25) and it reports p10/p25 alongside min/median to
%%% see whether the 20% gap from the original ticket measurement reproduces
%%% on this sandbox's OTP 25 / x86_64 JIT. Does not modify aoc/bench/bench.erl.
-module(bench_more).
-export([main/1]).

-define(RUNS, 200).

main([InputPath]) ->
    Deltas = read(InputPath),
    io:format("~p rotations, ~p clicks simulated per run, ~p runs~n~n",
              [length(Deltas), lists:sum([abs(D) || D <- Deltas]), ?RUNS]),
    Impls = [{"Erlang",     fun bench_erl:part_two/1},
             {"Elixir",     fun 'Elixir.BenchEx':part_two/1},
             {"Gleam",      fun bench_gleam:part_two/1},
             {"beam-sharp", fun 'Day01':'PartTwo'/1}],
    %% warm up each once outside the timed set (code loading / first-call jit)
    [F(Deltas) || {_, F} <- Impls],
    Results = [run(Name, F, Deltas) || {Name, F} <- Impls],
    report(Results),
    halt().

run(Name, F, Deltas) ->
    Answer = F(Deltas),
    Times = [begin {T, _} = timer:tc(F, [Deltas]), T end
             || _ <- lists:seq(1, ?RUNS)],
    Sorted = lists:sort(Times),
    N = length(Sorted),
    Pct = fun(P) -> lists:nth(max(1, round(P * N)), Sorted) end,
    {Name, Answer, hd(Sorted), Pct(0.10), Pct(0.25), Pct(0.50)}.

report(Results) ->
    io:format("~-12s ~-8s ~9s ~9s ~9s ~9s ~8s~n",
              ["", "answer", "min ms", "p10 ms", "p25 ms", "med ms", "rel(min)"]),
    Base = lists:min([Min || {_, _, Min, _, _, _} <- Results]),
    [io:format("~-12s ~-8s ~9.3f ~9.3f ~9.3f ~9.3f ~7.2fx~n",
               [Name, integer_to_list(Answer), Min / 1000, P10 / 1000,
                P25 / 1000, Med / 1000, Min / Base])
     || {Name, Answer, Min, P10, P25, Med} <- Results],
    Wrong = [N || {N, A, _, _, _, _} <- Results, A =/= 6770],
    case Wrong of
        [] -> io:format("~nall four agree on 6770~n");
        _  -> io:format("~nWRONG ANSWER from: ~p~n", [Wrong])
    end.

read(Path) ->
    {ok, Bin} = file:read_file(Path),
    [parse(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""].

parse([$L | N]) -> -list_to_integer(N);
parse([$R | N]) -> list_to_integer(N).
