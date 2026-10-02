#!/usr/bin/env escript
%% P3 - a forged value reaches a private function through an exported one.
%% usage: p3_forge.escript <dir with forge_g.beam forge_u.beam>
main([Dir]) ->
    true = code:add_patha(Dir),
    Cust = fun(K, E) -> #{'Kind' => K, 'Email' => E} end,
    Ord  = fun(C) -> #{'Kind' => 'Shop.Order', 'Customer' => C} end,
    Cases = [
      {"c1 right shape                      ", ship, Ord(Cust('Shop.Customer', <<"a@x">>))},
      {"c2 Vendor-tagged, same fields (DDD) ", ship, Ord(Cust('Shop.Vendor',   <<"v@x">>))},
      {"c3 right tag, payload forged Email=42", ship, Ord(Cust('Shop.Customer', 42))},
      {"c4 Customer is a binary             ", ship, Ord(<<"junk">>)},
      {"c5 Customer map without Email       ", ship, Ord(#{'Kind' => 'Shop.Customer'})},
      {"l1 list of right Orders             ", total, [#{'Kind'=>'Shop.Order','Amount'=>5},
                                                       #{'Kind'=>'Shop.Order','Amount'=>7}]},
      {"l2 list with an Invoice-tagged elem ", total, [#{'Kind'=>'Shop.Order','Amount'=>5},
                                                       #{'Kind'=>'Shop.Invoice','Amount'=>7}]},
      {"l3 list with a non-map elem         ", total, [#{'Kind'=>'Shop.Order','Amount'=>5}, 7]}
    ],
    Run = fun(M, F, A) -> try {ok, M:F(A)} catch C:R -> {C, element(1, to_tuple(R))} end end,
    io:format("~-40s ~-28s ~-28s~n", ["case", "private HAS tag test", "private has NO tag test"]),
    Rows = [{L, Run(forge_g, F, A), Run(forge_u, F, A)} || {L, F, A} <- Cases],
    [io:format("~-40s ~-28w ~-28w~n", [L, G, U]) || {L, G, U} <- Rows],
    %% Assertions: the cells that matter. Each would flip if the claim were false.
    {_, {error, function_clause}, {ok, <<"v@x">>}} = lists:keyfind("c2 Vendor-tagged, same fields (DDD) ", 1, Rows),
    {_, {ok, 42}, {ok, 42}}                         = lists:keyfind("c3 right tag, payload forged Email=42", 1, Rows),
    {_, {error, function_clause}, {error, badmap}} = lists:keyfind("c4 Customer is a binary             ", 1, Rows),
    {_, {error, function_clause}, {ok, 12}} = lists:keyfind("l2 list with an Invoice-tagged elem ", 1, Rows),
    io:format("ASSERT ok~n"),
    halt(0).
to_tuple(T) when is_tuple(T) -> T;
to_tuple(T) -> {T}.
