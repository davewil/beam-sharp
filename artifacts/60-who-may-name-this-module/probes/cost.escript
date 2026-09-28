#!/usr/bin/env escript
%% PREDICTION (before running). Cost of a compile-time "may Caller name Callee" test, per check, OTP 25 JIT, this box:
%%  - map key lookup (is_key) and segment-aware prefix on a short atom name: < 2 us, flat in N (10 / 1k / 100k).
%%  - lists:member over an atom list with a MISS: linear in N; ~0.05-0.1 us at N=10, ~1 ms at N=100k.
%%  - scan of all N module names for "which modules mention X" (reverse index): linear, ~ms at 100k.
%%  - all of these are far below one erlc compile of a tiny module (~ms), so cost of the check is not the deciding axis.
%% N is the number of module names in the world / the size of a rule's allowed list.
-mode(compile).
main(_) ->
    io:format("names are 'Shop.MNNNNNN.Leaf' style atoms; caller is a miss unless stated~n"),
    [run(N) || N <- [10, 1000, 100000]],
    {TC, _} = timer:tc(fun() -> compile:file("fixtures/erl/shop_orders.erl", [binary]) end),
    io:format("reference: erlc compile:file of the 10-line shop_orders fixture: ~p us~n", [TC]).

run(N) ->
    Names = [list_to_atom("Shop.M" ++ integer_to_list(I) ++ ".Leaf") || I <- lists:seq(1, N)],
    Map = maps:from_list([{X, true} || X <- Names]),
    Sets = sets:from_list(Names),
    Hit = lists:last(Names),
    Miss = 'Other.Caller',
    Root = 'Shop.M1',                                % subtree rule: root atom
    Reps = case N of 100000 -> 200; 1000 -> 20000; _ -> 200000 end,
    io:format("~nN = ~p~n", [N]),
    t("map is_key (miss)",            Reps, fun() -> maps:is_key(Miss, Map) end),
    t("map is_key (hit)",             Reps, fun() -> maps:is_key(Hit, Map) end),
    t("sets:is_element (miss)",       Reps, fun() -> sets:is_element(Miss, Sets) end),
    t("lists:member (miss, worst)",   Reps, fun() -> lists:member(Miss, Names) end),
    t("lists:member (hit=last)",      Reps, fun() -> lists:member(Hit, Names) end),
    t("subtree prefix test, one root (in)",  Reps, fun() -> under('Shop.M1.Leaf', Root) end),
    t("subtree prefix test, one root (out)", Reps, fun() -> under(Miss, Root) end),
    %% callee declares N roots, caller must be under one (naive scan, miss)
    t("subtree vs N roots (naive scan, miss)", max(Reps div 100, 2), fun() -> lists:any(fun(R) -> under(Miss, R) end, Names) end),
    %% build-wide: verify every import edge of an N-module world, one edge per module, map lookup + prefix
    Edges = [{X, lists:nth(1 + (I * 7) rem N, Names)} || {I, X} <- lists:zip(lists:seq(1, N), Names)],
    {T, _} = timer:tc(fun() -> [maps:is_key(C, Map) andalso under(X, 'Shop') || {X, C} <- Edges] end),
    io:format("  whole-world sweep: ~p edges, one map lookup + one prefix test each: ~p us total (~.3f us/edge)~n", [N, T, T / N]).

under(Caller, Root) ->
    C = atom_to_list(Caller), R = atom_to_list(Root),
    C =:= R orelse lists:prefix(R ++ ".", C).

t(Label, Reps, F) ->
    {T, _} = timer:tc(fun() -> loop(Reps, F) end),
    io:format("  ~-42s ~10.4f us/check  (~p reps)~n", [Label, T / Reps, Reps]).
loop(0, _) -> ok;
loop(N, F) -> F(), loop(N - 1, F).
