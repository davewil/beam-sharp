#!/usr/bin/env escript
%% MODEL (not bsc): subtree-rule cost on synthetic module sets of N modules in a directory tree.
%% Rule: a module whose path contains a segment "Internal" is nameable only from modules under the
%% prefix before that segment. Mirrors where bs_check:add_module_import/3 (bs_check.erl:509) would run it:
%% once per `using` edge, with Self and M known.
main(_) ->
    rand:seed(exsss, {1,2,3}),
    io:format("N  edges  restricted  edge_driven_us(min/med)  allpairs_us(min/med)  allpairs_pairs  violations~n"),
    [run(N, 8) || N <- [10,100,1000]],
    io:format("-- control: same sizes, NO restricted modules (rule has nothing to test)~n"),
    [run_ctl(N, 8) || N <- [10,100,1000]].

mods(N, WithInternal) ->
    Ctxs = max(1, N div 10),
    [ list_to_atom(lists:flatten(io_lib:format("Shop.C~p.~s~p", [I rem Ctxs, seg(I, WithInternal), I]))) || I <- lists:seq(1,N)].
seg(I, true) when I rem 3 =:= 0 -> "Internal.M";
seg(_, _) -> "M".

%% restricted -> allowed prefix (string) | none
scope(M) ->
    S = atom_to_list(M),
    case string:find(S, ".Internal.") of
        nomatch -> none;
        Rest -> lists:sublist(S, length(S) - length(Rest) + 1)   %% "Shop.Ck." (incl. trailing dot)
    end.

edges(Ms, K) ->
    T = list_to_tuple(Ms), N = tuple_size(T),
    [{element(I, T), element(rand:uniform(N), T)} || I <- lists:seq(1,N), _ <- lists:seq(1,K)].

viol(Edges, Scope) ->
    length([x || {F,C} <- Edges, S <- [maps:get(C, Scope)], S =/= none, not lists:prefix(S, atom_to_list(F))]).

run(N, K) -> go(N, K, true).
run_ctl(N, K) -> go(N, K, false).
go(N, K, W) ->
    Ms = mods(N, W), Scope = maps:from_list([{M, scope(M)} || M <- Ms]), E = edges(Ms, K),
    TE = bench(fun() -> viol(E, Scope) end),
    AllPairs = fun() -> length([x || F <- Ms, C <- Ms, F =/= C, S <- [maps:get(C, Scope)], S =/= none, not lists:prefix(S, atom_to_list(F))]) end,
    TP = bench(AllPairs),
    io:format("~p  ~p  ~p  ~p/~p  ~p/~p  ~p  ~p~n",
      [N, length(E), length([x||M<-Ms, maps:get(M,Scope)=/=none]), min(TE), med(TE), min(TP), med(TP), N*(N-1), viol(E,Scope)]).
bench(F) -> [begin T0=erlang:monotonic_time(nanosecond), F(), (erlang:monotonic_time(nanosecond)-T0) div 1000 end || _ <- lists:seq(1,15)].
min(L) -> lists:min(L).
med(L) -> lists:nth(8, lists:sort(L)).
