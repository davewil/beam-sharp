#!/usr/bin/env escript
%% P3 - a forged value reaches a private function through an exported one.
%% usage: p3_forge.escript <dir with forge_g.beam forge_u.beam>
main([Dir]) ->
    true = code:add_patha(Dir),
    Cust = fun(K, E) -> #{'Kind' => K, 'Email' => E} end,
    Ord  = fun(C) -> #{'Kind' => 'Shop.Order', 'Customer' => C} end,
    Amt  = fun(K, A) -> #{'Kind' => K, 'Amount' => A} end,
    Cases = [
      {"c1 right shape", ship, [Ord(Cust('Shop.Customer', <<"a@x">>))]},
      {"w1 WHOLE value forged (Invoice-tagged), passed on", ship_whole, [#{'Kind' => 'Shop.Invoice', 'Id' => 1}]},
      {"c2 sub-term: Vendor-tagged, same fields (DDD)", ship, [Ord(Cust('Shop.Vendor', <<"v@x">>))]},
      {"c3 sub-term: right tag, payload Email=42", ship, [Ord(Cust('Shop.Customer', 42))]},
      {"c4 sub-term: Customer is a binary", ship, [Ord(<<"junk">>)]},
      {"c5 sub-term: Customer map without Email", ship, [Ord(#{'Kind' => 'Shop.Customer'})]},
      {"l1 list of right Orders", total, [[Amt('Shop.Order', 5), Amt('Shop.Order', 7)]]},
      {"l2 list element Invoice-tagged, same fields", total, [[Amt('Shop.Order', 5), Amt('Shop.Invoice', 7)]]},
      {"l3 list element not a map", total, [[Amt('Shop.Order', 5), 7]]},
      {"f1 escaped fun (private Notify) <- Vendor-tagged", fun_call, [rule, Cust('Shop.Vendor', <<"v@x">>)]},
      {"f2 escaped fun (private Dbl) <- 1.5", fun_call, [rule_int, 1.5]}
    ],
    Run = fun(M, F, A) ->
              try {ok, case F of fun_call -> (M:(hd(A))())(lists:last(A)); _ -> apply(M, F, A) end}
              catch C:R -> {C, element(1, to_tuple(R))} end end,
    io:format("~-52s ~-26s ~-26s~n", ["case", "B: private guarded", "A: private unguarded"]),
    Rows = [{L, Run(forge_b, F, A), Run(forge_a, F, A)} || {L, F, A} <- Cases],
    [io:format("~-52s ~-26w ~-26w~n", [L, B, A]) || {L, B, A} <- Rows],
    Row = fun(Id) -> [R || R = {L, _, _} <- Rows, lists:prefix(Id, L)] end,
    %% each assertion is a cell that would flip if the claim it supports were false
    [{_, {ok, _}, {ok, _}}] = Row("c1"),
    [{_, {error, function_clause}, {error, function_clause}}] = Row("w1"),  %% whole value: caught at the export either way
    [{_, {error, function_clause}, {ok, <<"v@x">>}}] = Row("c2"),
    [{_, {ok, 42}, {ok, 42}}] = Row("c3"),                                  %% payload forgery: neither catches
    [{_, {error, function_clause}, {error, badmap}}] = Row("c4"),
    [{_, {error, badkey}, {error, badkey}}] = Row("c5"),
    [{_, {error, function_clause}, {ok, 12}}] = Row("l2"),
    [{_, {error, function_clause}, {error, badmap}}] = Row("l3"),
    [{_, {error, function_clause}, {ok, <<"v@x">>}}] = Row("f1"),
    [{_, {error, function_clause}, {ok, 3.0}}] = Row("f2"),
    io:format("ASSERT ok~n"),
    halt(0).
to_tuple(T) when is_tuple(T) -> T;
to_tuple(T) -> {T}.
