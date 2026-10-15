#!/usr/bin/env escript
%% 59_forge.escript BEAM_DIR -- load module G from BEAM_DIR and hand its exported functions
%% forged maps from plain Erlang (no B# checker in the way). Prints one line per call:
%%   ok <value>            the call returned (SILENT if the argument was ill-typed)
%%   <Class>:<Reason>      the call raised
main([Dir]) ->
    true = code:add_patha(Dir),
    {module, g_loaded} = {module, g_loaded} ,
    O  = fun(Id, T) -> #{'Kind' => 'G.Order',   'Id' => Id, 'Total' => T} end,
    I  = fun(Id, T) -> #{'Kind' => 'G.Invoice', 'Id' => Id, 'Total' => T} end,
    W  = fun(Inner) -> #{'Kind' => 'G.Wrapper', 'Id' => 1, 'Inner' => Inner} end,
    Cases =
      [{'Direct',    "valid Order",                    [O(1, 5)]},
       {'Direct',    "Invoice-tagged, same fields",    [I(1, 5)]},
       {'Direct',    "42 (not a map)",                 [42]},
       {'Direct',    "Order tag, Total = <<\"x\">>",   [O(1, <<"x">>)]},
       {'Direct',    "Order tag, no Total key",        [#{'Kind' => 'G.Order', 'Id' => 1}]},
       {'Pub',       "Invoice-tagged, same fields",    [I(1, 5)]},
       {'ViaNested', "valid",                          [W(O(1, 5))]},
       {'ViaNested', "Inner Invoice-tagged",           [W(I(1, 5))]},
       {'ViaNested', "Inner = 42",                     [W(42)]},
       {'ViaNested', "Inner Order tag, no Total key",  [W(#{'Kind' => 'G.Order'})]},
       {'ViaNested', "Inner Order tag, Total=<<x>>",   [W(O(1, <<"x">>))]},
       {'ViaList',   "valid",                          [[O(1, 5)]]},
       {'ViaList',   "element Invoice-tagged",         [[I(1, 5)]]},
       {'ViaTuple',  "valid",                          [{1, O(1, 5)}]},
       {'ViaTuple',  "component Invoice-tagged",       [{1, I(1, 5)}]},
       {'ViaUnion',  "Order",                          [O(1, 5)]},
       {'ViaUnion',  "Invoice",                        [I(1, 5)]},
       {'ViaUnion',  "unknown tag",                    [#{'Kind' => 'G.Other', 'Total' => 5}]},
       {'ViaUnion',  "Order tag, Total=<<x>>",         [O(1, <<"x">>)]},
       {'ViaIntDirect', "1",                           [1]},
       {'ViaIntDirect', "1.5 (float)",                 [1.5]},
       {'ViaIntList',   "[1]",                         [[1]]},
       {'ViaIntList',   "[1.5] (float element)",       [[1.5]]},
       {'ViaOctList',   "[100]",                       [[100]]},
       {'ViaOctList',   "[300] (out of range)",        [[300]]},
       {'ViaOctList',   "[1.5] (float)",               [[1.5]]},
       {'ViaValidate', "valid Order",                  [O(1, 5)]},
       {'ViaValidate', "Invoice-tagged",               [I(1, 5)]},
       {'ViaValidate', "Order tag, Total=<<x>>",       [O(1, <<"x">>)]}],
    [begin
         R = try {ok, apply(g_mod(), F, Args)} catch C:E -> {C, short(E)} end,
         io:format("~-13s ~-32s -> ~s~n", [F, Desc, show(R)])
     end || {F, Desc, Args} <- Cases].
g_mod() -> 'G'.
short({badmap, _}) -> badmap;
short({badkey, K}) -> {badkey, K};
short(E) when is_atom(E) -> E;
short(E) -> E.
show({ok, V}) -> io_lib:format("ok ~p", [V]);
show({C, E}) -> io_lib:format("~s:~p", [C, E]).
