-module(bench4).
-export([main/1]).
-define(RUNS, 25).
main([P]) ->
    Ds = read(P),
    Impls = [{"Erlang", fun bench_erl:part_two/1}, {"Elixir", fun 'Elixir.BenchEx':part_two/1},
             {"beam-sharp(shim)", fun 'Day01':'PartTwo'/1}],
    R = [run(N, F, Ds) || {N, F} <- Impls],
    Base = lists:min([M || {_, _, M, _} <- R]),
    [io:format("~-18s ~-6w min ~7.2f med ~7.2f rel ~5.2fx~n", [N, A, M/1000, Md/1000, M/Base]) || {N, A, M, Md} <- R],
    case [N || {N, A, _, _} <- R, A =/= 6770] of [] -> io:format("answers agree: 6770~n"); W -> io:format("WRONG: ~p~n", [W]) end,
    halt().
run(N, F, Ds) ->
    A = F(Ds),
    T = lists:sort([begin {X, _} = timer:tc(F, [Ds]), X end || _ <- lists:seq(1, ?RUNS)]),
    {N, A, hd(T), lists:nth(?RUNS div 2 + 1, T)}.
read(P) ->
    {ok, B} = file:read_file(P),
    [parse(L) || L <- string:split(binary_to_list(B), "\n", all), L =/= ""].
parse([$L | N]) -> -list_to_integer(N);
parse([$R | N]) -> list_to_integer(N).
