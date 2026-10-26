#!/usr/bin/env escript
%% P5: where does a forged (wrong-identity) map get stopped?
main(_) ->
    Forged = #{'Kind' => not_an_order, 'Total' => 1},
    Real   = #{'Kind' => order, 'Total' => 1},
    code:add_patha("ebin"),
    t("ship(Forged)            exported, tag-tested",            fun() -> forge:ship(Forged) end),
    t("ship(Real)",                                              fun() -> forge:ship(Real) end),
    t("ship_all([Forged])      exported list<Order>, private fn UNguarded", fun() -> forge:ship_all([Forged]) end),
    t("ship_all_guarded_inner([Forged])  same, private fn tag-tested",      fun() -> forge:ship_all_guarded_inner([Forged]) end),
    t("ship_field(Envelope{Order=Forged}) nested record, private UNguarded",
      fun() -> forge:ship_field(#{'Kind' => envelope, 'Order' => Forged}) end).
t(Name, F) ->
    R = try F() catch C:E -> {C, E} end,
    io:format("~-78s => ~p~n", [Name, R]).
