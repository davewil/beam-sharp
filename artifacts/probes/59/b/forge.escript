#!/usr/bin/env escript
%% usage: forge.escript OUTDIR   -- foreign (Erlang) caller handing forged terms to Forge's exported functions
main([Dir]) ->
    true = code:add_patha(Dir), {module, 'Forge'} = code:load_file('Forge'),
    Inv  = #{'Kind' => 'Forge.Invoice', 'Id' => 1, 'Total' => 999},       %% wrong tag, right shape
    Bare = #{'Kind' => 'Forge.Invoice'},                                   %% wrong tag, wrong shape
    NoTot = #{'Kind' => 'Forge.Order', 'Id' => 1},                         %% RIGHT tag, wrong shape
    Good = #{'Kind' => 'Forge.Order', 'Id' => 1, 'Total' => 5},
    Cart = fun(I) -> #{'Kind' => 'Forge.Cart', 'Item' => I, 'N' => 1} end,
    Cases =
      [{"Direct(good Order)",                 fun() -> 'Forge':'Direct'(Good) end},
       {"Direct(forged Invoice)  [exported, direct]", fun() -> 'Forge':'Direct'(Inv) end},
       {"ViaCart(Cart{Item=good})",           fun() -> 'Forge':'ViaCart'(Cart(Good)) end},
       {"ViaCart(Cart{Item=Invoice 999})  [forged, nested]", fun() -> 'Forge':'ViaCart'(Cart(Inv)) end},
       {"ViaCart(Cart{Item=bare Invoice tag only})", fun() -> 'Forge':'ViaCart'(Cart(Bare)) end},
       {"ViaCart(Cart{Item=Order tag, no Total})  [tag ok, shape wrong]", fun() -> 'Forge':'ViaCart'(Cart(NoTot)) end},
       {"ViaList([Invoice 999])  [forged, list element]", fun() -> 'Forge':'ViaList'([Inv]) end},
       {"InlineCart(Cart{Item=Invoice 999})  [same read, no helper]", fun() -> 'Forge':'InlineCart'(Cart(Inv)) end},
       {"PubClassify(100.5)  [exported int, direct float]", fun() -> 'Forge':'PubClassify'(100.5) end},
       {"ViaOctets([100.5])  [float via list into PRIVATE int fn]", fun() -> 'Forge':'ViaOctets'([100.5]) end},
       {"ViaOctets([300])   [out-of-range int via list into PRIVATE fn]", fun() -> 'Forge':'ViaOctets'([300]) end},
       {"ViaOctets([<<\"x\">>]) [binary via list into PRIVATE fn]", fun() -> 'Forge':'ViaOctets'([<<"x">>]) end}],
    [begin
         R = try Fun() of V -> {returned, V} catch C:E -> {C, element(1, if is_tuple(E) -> E; true -> {E} end)} end,
         io:format("  ~-66s => ~w~n", [Name, R])
     end || {Name, Fun} <- Cases].
