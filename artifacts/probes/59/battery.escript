#!/usr/bin/env escript
%% Usage: battery.escript DIR_WITH_T.beam
%% Calls the compiled module T with a forged value at each door; prints what came back (raw, no expectations).
main([Dir]) ->
    code:add_patha(Dir),
    Order   = #{'Kind' => 'T.Order',   'Id' => 1, 'Total' => 10},
    Invoice = #{'Kind' => 'T.Invoice', 'Id' => 2, 'Total' => 999},   %% same field set, other record
    Wrap = fun(C) -> #{'Kind' => 'T.Wrapper', 'Cust' => C} end,
    Calls = [
      {"Outer(Invoice)                 exported, direct",        fun() -> 'T':'Outer'(Invoice) end},
      {"OuterL([Order, Invoice])       exported, via list",      fun() -> 'T':'OuterL'([Order, Invoice]) end},
      {"OuterL([Order, Order])         control (valid)",         fun() -> 'T':'OuterL'([Order, Order]) end},
      {"SumO([1, 1.5])                 exported, via list",      fun() -> 'T':'SumO'([1, 1.5]) end},
      {"SumO([300])                    exported, via list",      fun() -> 'T':'SumO'([300]) end},
      {"SumO([1, 2])                   control (valid)",         fun() -> 'T':'SumO'([1, 2]) end},
      {"(InnerAsValue())(Invoice)      private escaped as fun",  fun() -> ('T':'InnerAsValue'())(Invoice) end},
      {"(BumpAsValue())(1.5)           private escaped as fun",  fun() -> ('T':'BumpAsValue'())(1.5) end},
      {"(BumpAsValue())(300)           private escaped as fun",  fun() -> ('T':'BumpAsValue'())(300) end},
      {"Nested(Wrapper{Cust=Order})    exported, nested record",  fun() -> 'T':'Nested'(Wrap(Order#{'Score' => 5})) end},
      {"Nested(Wrapper{Cust=Cust})     control (valid)",         fun() -> 'T':'Nested'(Wrap(#{'Kind' => 'T.Cust', 'Id' => 1, 'Score' => 5})) end},
      {"OuterI(1.5)                    exported, direct",        fun() -> 'T':'OuterI'(1.5) end}
    ],
    [begin
         R = try {returned, F()} catch C:E -> {raised, C, case E of T when is_tuple(T) -> element(1,T); _ -> E end} end,
         io:format("~-62s => ~0p~n", [L, R])
     end || {L, F} <- Calls].
