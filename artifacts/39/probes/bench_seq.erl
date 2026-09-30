%%% The ORIGINAL protocol of aoc/bench/bench.erl (25 consecutive calls in the same process, min/median),
%%% but the order of implementations is an argument, to test whether position in the list matters.
-module(bench_seq).
-export([main/1]).
main([Input | Specs]) ->
    Deltas = read(Input),
    Impls = [begin [M, F] = string:split(S, ":"), {S, list_to_atom(M), list_to_atom(F)} end || S <- Specs],
    [begin
        Ts = lists:sort([begin {T, _} = timer:tc(M, F, [Deltas]), T end || _ <- lists:seq(1, 25)]),
        io:format("~-26s min ~6.2f  med ~6.2f~n", [N, hd(Ts) / 1000, lists:nth(13, Ts) / 1000])
    end || {N, M, F} <- Impls],
    halt().
read(Path) ->
    {ok, Bin} = file:read_file(Path),
    [parse(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""].
parse([$L | N]) -> -list_to_integer(N);
parse([$R | N]) -> list_to_integer(N).
