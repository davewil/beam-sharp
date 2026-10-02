%% Round-robin timing: each round runs every variant once (order rotated), so drift and
%% noisy neighbours hit all variants equally.  Reports min / median / p90 (ms) per variant for
%%   full  = part_two(Deltas), 673,364 iterations incl. sign/size/clicks, and
%%   spin  = spin_only(673364), the hot loop in isolation (ticket 39 section 3.1).
%% Every variant's answer is checked first (6770 / {50+673364 mod.., Zeros}) - a wrong fast
%% answer is worth nothing.   usage: bench:main(Input, Runs, [ModuleAtom...])
-module(bench).
-export([main/3]).

main(Input, Runs, Mods) ->
    Ds = read(Input),
    Clicks = lists:sum([abs(D) || D <- Ds]),
    Ans = [{M, M:part_two(Ds), M:spin_only(Clicks)} || M <- Mods],
    [{_, A0, S0} | _] = Ans,
    [io:format("ANSWER MISMATCH ~p ~p ~p~n", [M, A, S]) || {M, A, S} <- Ans, {A, S} =/= {A0, S0}],
    io:format("clicks=~p part_two=~p spin_only=~p~n", [Clicks, A0, S0]),
    Rounds = [round_(Mods, R, Ds, Clicks) || R <- lists:seq(1, Runs)],
    io:format("~-22s ~8s ~8s ~8s   ~8s ~8s ~8s~n", ["variant", "full min", "median", "p90", "spin min", "median", "p90"]),
    Base = lists:min([stat(M, full, Rounds, min) || M <- Mods]),
    BaseS = lists:min([stat(M, spin, Rounds, min) || M <- Mods]),
    [io:format("~-22s ~8.2f ~8.2f ~8.2f   ~8.2f ~8.2f ~8.2f   rel ~.3f / ~.3f~n",
               [atom_to_list(M),
                stat(M, full, Rounds, min), stat(M, full, Rounds, med), stat(M, full, Rounds, p90),
                stat(M, spin, Rounds, min), stat(M, spin, Rounds, med), stat(M, spin, Rounds, p90),
                stat(M, full, Rounds, min) / Base, stat(M, spin, Rounds, min) / BaseS])
     || M <- Mods],
    ok.

round_(Mods, R, Ds, Clicks) ->
    Rot = lists:nthtail(R rem length(Mods), Mods) ++ lists:sublist(Mods, R rem length(Mods)),
    [{M, full, t(fun() -> M:part_two(Ds) end)} || M <- Rot] ++
    [{M, spin, t(fun() -> M:spin_only(Clicks) end)} || M <- Rot].

t(F) -> erlang:garbage_collect(), {T, _} = timer:tc(F), T / 1000.

stat(M, K, Rounds, What) ->
    Xs = lists:sort([T || R <- Rounds, {M1, K1, T} <- R, M1 =:= M, K1 =:= K]),
    N = length(Xs),
    case What of
        min -> hd(Xs);
        med -> lists:nth((N + 1) div 2, Xs);
        p90 -> lists:nth(max(1, trunc(N * 0.9)), Xs)
    end.

read(Path) ->
    {ok, Bin} = file:read_file(Path),
    [parse(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""].

parse([$L | N]) -> -list_to_integer(N);
parse([$R | N]) -> list_to_integer(N).
