#!/usr/bin/env escript
main([ModsFile]) ->
    code:add_patha("."),
    {ok, B} = file:read_file(ModsFile),
    Mods = [list_to_atom(L) || L <- string:split(string:trim(binary_to_list(B)), "\n", all)],
    T = [{'Other.Thing', 'Shop.Orders.Internal.Cache', refused},
         {'Shop.Billing', 'Shop.Orders.Internal.Cache', refused},
         {'Shop.Orders', 'Shop.Orders.Internal.Cache', allowed},
         {'Shop.Orders.Total', 'Shop.Orders.Internal.Cache', allowed},
         {'Shop.OrdersX', 'Shop.Orders.Internal.Cache', refused},   %% flat-prefix trap
         {'Shop.Orders.Internal.Cache', 'Shop.Orders.Internal.Cache', allowed},
         {'Shop.Billing', 'Shop.Orders', allowed},
         %% first expectation for Billing->Shop.Internal (refused) was wrong: parent of Internal is Shop; Billing is under Shop
         {'Shop.Billing', 'Shop.Internal', allowed}, {'Shop', 'Shop.Internal', allowed},
         %% first expectation (refused) wrong too: a top-level Internal has an empty parent = visible to the whole source root (Go does the same)
         {'Other', 'Internal.X', allowed}],
    [begin G = may_name:internal_rule(I, C),
           io:format("~-34s -> ~-30s expect ~-8s got ~-8s ~s~n", [I, C, E, G, case G of E -> "ok"; _ -> "MISMATCH" end])
     end || {I, C, E} <- T],
    %% the flat prefix an Erlang-xref-style string check would use, to show the trap is real:
    io:format("flat lists:prefix(\"Shop.Orders\", \"Shop.OrdersX\") = ~p~n", [lists:prefix("Shop.Orders", "Shop.OrdersX")]),
    io:format("declared: ~p ~p~n", [may_name:declared_rule('Shop.Orders.Total', 'Shop.Orders.Cache', ['Shop.Orders']),
                                    may_name:declared_rule('Other.Thing', 'Shop.Orders.Cache', ['Shop.Orders'])]),
    Pairs = [{I, C} || I <- Mods, C <- Mods, I =/= C],
    Ref = [P || {I, C} = P <- Pairs, may_name:internal_rule(I, C) =:= refused],
    io:format("corpus: ~p modules, ~p ordered pairs, refused under Internal rule: ~p~n", [length(Mods), length(Pairs), length(Ref)]),
    {N, _} = timer:tc(fun() -> [may_name:internal_rule(I, C) || _ <- lists:seq(1,100), {I, C} <- Pairs] end),
    io:format("~p checks in ~p ms (~.2f us/check)~n", [100*length(Pairs), N div 1000, N / (100*length(Pairs))]).
