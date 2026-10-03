#!/usr/bin/env escript
%% usage: forge.escript EBIN   -- foreign Erlang caller of the Gleam-generated module
main([Dir]) ->
    true = code:add_patha(Dir),
    C = fun(I) -> {cart, I, 1} end,
    Cases = [{"pub_amount({invoice,1,999})  [wrong tag, exported, direct]", fun() -> probe:pub_amount({invoice,1,999}) end},
             {"via_cart({cart,{invoice,1,999},1}) [wrong tag, through private fn]", fun() -> probe:via_cart(C({invoice,1,999})) end},
             {"via_match({invoice,1,999})  [private head is a tuple pattern {order,_,T}]", fun() -> probe:via_match({invoice,1,999}) end},
             {"via_n({cart,{order,1,2},<<\"x\">>}) [binary into private Int fn]", fun() -> probe:via_n({cart,{order,1,2},<<"x">>}) end},
             {"token_value({token,<<\"x\">>}) [opaque type, forged from Erlang]", fun() -> probe:token_value({token,<<"x">>}) end}],
    [begin R = try Fun() of V -> {returned, V} catch Cl:E -> {Cl, case E of {Tag,_} -> Tag; _ -> E end} end,
           io:format("  ~-74s => ~w~n", [Name, R]) end || {Name, Fun} <- Cases].
