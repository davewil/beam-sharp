%% Interleaved, fresh-process-per-run timing of Day-1-shaped variants.
%% Input is synthetic (the real puzzle input is not in the repo): 4732 rotations,
%% |d| uniform in 1..283 from a fixed LCG, ~670k clicks, so the answer is only
%% compared ACROSS variants, never against 6770.
-module(bench39).
-export([main/1]).
-define(ROUNDS, 31).

main(Vs0) ->
    Vs = [case V of A when is_atom(A) -> A; S -> list_to_atom(S) end || V <- Vs0],
    In = input(),
    Clicks = lists:sum([abs(D) || D <- In]),
    [{_, Ans} | _] = Ref = [{V, V:part_two(In)} || V <- Vs],
    true = lists:all(fun({_, A}) -> A =:= Ans end, Ref),
    io:format("# rotations=~p clicks=~p answer(all variants)=~p~n", [length(In), Clicks, Ans]),
    Runs = [[{V, once(V, In)} || V <- shuffle(Vs, R)] || R <- lists:seq(1, ?ROUNDS)],
    io:format("~-22s ~8s ~8s ~8s ~7s~n", ["variant", "min_ms", "med_ms", "max_ms", "min_rel"]),
    Stats = [begin
                 Ts = lists:sort([T || Round <- Runs, {X, T} <- Round, X =:= V]),
                 {V, hd(Ts), lists:nth((length(Ts) + 1) div 2, Ts), lists:last(Ts)}
             end || V <- Vs],
    Base = element(2, hd(Stats)),
    [io:format("~-22s ~8.2f ~8.2f ~8.2f ~6.2fx~n", [V, A/1000, B/1000, C/1000, A/Base]) || {V, A, B, C} <- Stats],
    halt().

once(V, In) ->
    Self = self(), Ref = make_ref(),
    spawn_opt(fun() -> {T, _} = timer:tc(V, part_two, [In]), Self ! {Ref, T} end, [link]),
    receive {Ref, T} -> T end.

shuffle(L, Seed) -> %% deterministic rotation so no variant is always first
    N = Seed rem length(L), {A, B} = lists:split(N, L), B ++ A.

input() ->
    {L, _} = lists:mapfoldl(fun(_, S) ->
        S1 = (S * 1103515245 + 12345) band 16#7fffffff,
        Mag = (S1 bsr 8) rem 283 + 1,
        S2 = (S1 * 1103515245 + 12345) band 16#7fffffff,
        {case (S2 bsr 12) band 1 of 0 -> -Mag; 1 -> Mag end, S2}
      end, 42, lists:seq(1, 4732)),
    L.
