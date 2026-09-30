%%% bench2 variant: the argument is an integer N (not a file) and all impls must agree with each other.
%%% Noise-controlled harness. Differences from aoc/bench/bench.erl (which is unchanged and was run as-is in 01-rebench):
%%%  * every sample runs in a FRESH process (heap discarded, as the repo's fib harness already does);
%%%  * implementations are run in a SHUFFLED order within each round, so position cannot favour anyone;
%%%  * N rounds (default 150); reports min, p25, median and (p75-p25) spread per implementation.
%%% Usage: erl -noshell -pa DIRS -s bench2 main INPUT ROUNDS Spec...   Spec = Mod:Fun (Fun arity 1, takes delta list)
-module(bench3).
-export([main/1, run/3]).

main([Input, RoundsS | Specs]) ->
    Deltas0 = Input,
    Deltas = list_to_integer(Input),
    Rounds = list_to_integer(RoundsS),
    Impls = [begin [M, F] = string:split(S, ":"), {S, list_to_atom(M), list_to_atom(F)} end || S <- Specs],
    run(Deltas, Rounds, Impls).

run(Deltas, Rounds, Impls) ->
    Answers = [{N, M:F(Deltas)} || {N, M, F} <- Impls],
    io:format("answers: ~p~n", [Answers]),
    1 = length(lists:usort([A || {_, A} <- Answers])),
    rand:seed(exsss, {1, 2, 3}),
    All = lists:append([begin
        Order = [X || {_, X} <- lists:sort([{rand:uniform(), I} || I <- Impls])],
        [sample(I, Deltas) || I <- Order]
    end || _ <- lists:seq(1, Rounds)]),
    io:format("~-28s ~8s ~8s ~8s ~8s~n", ["impl", "min_ms", "p25_ms", "med_ms", "iqr_ms"]),
    [begin
        Ts = lists:sort([T || {N2, T} <- All, N2 =:= N]),
        L = length(Ts),
        P = fun(Q) -> lists:nth(max(1, round(L * Q)), Ts) / 1000 end,
        io:format("~-28s ~8.2f ~8.2f ~8.2f ~8.2f~n", [N, hd(Ts) / 1000, P(0.25), P(0.5), P(0.75) - P(0.25)])
    end || {N, _, _} <- Impls],
    halt().

sample({N, M, F}, Deltas) ->
    Self = self(),
    {Pid, Ref} = spawn_monitor(fun() ->
        {T, _} = timer:tc(M, F, [Deltas]), Self ! {t, self(), T} end),
    receive {t, Pid, T} -> receive {'DOWN', Ref, _, _, _} -> ok end, {N, T} end.

read(Path) ->
    {ok, Bin} = file:read_file(Path),
    [parse(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""].
parse([$L | N]) -> -list_to_integer(N);
parse([$R | N]) -> list_to_integer(N).
