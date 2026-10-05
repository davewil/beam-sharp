#!/usr/bin/env escript
%% drive_deep.escript BEAMDIR : call module 'Deep' with FORGED terms from Erlang (no B# call site
%% can produce these) and print, per case, the result or the {Class, Reason, raising function}.
main([Dir]) ->
    true = code:add_patha(Dir),
    {module, 'Deep'} = code:load_file('Deep'),
    Ord = fun(T) -> #{'Kind' => 'Deep.Order', 'Id' => 1, 'Total' => T} end,
    Inv = fun(T) -> #{'Kind' => 'Deep.Invoice', 'Id' => 1, 'Total' => T} end,
    Cases =
      [{"C1 control   Top(valid Order)",                 fun() -> 'Deep':'Top'(Ord(5)) end},
       {"C2 forged    Top(Invoice-as-Order)  [top-level param -> private Amount]",
                                                         fun() -> 'Deep':'Top'(Inv(9)) end},
       {"C3 control   SumTotals([Order 5, Order 7])",    fun() -> 'Deep':'SumTotals'([Ord(5), Ord(7)]) end},
       {"C4 forged    SumTotals([Order 5, Invoice 9])  [element one projection down]",
                                                         fun() -> 'Deep':'SumTotals'([Ord(5), Inv(9)]) end},
       {"C5 forged    SumTotals([Order 5, #{} ])  [empty map, no Total]",
                                                         fun() -> 'Deep':'SumTotals'([Ord(5), #{}]) end},
       {"C6 control   SumWeights([1, 100])",             fun() -> 'Deep':'SumWeights'([1, 100]) end},
       {"C7 forged    SumWeights([1, 100.5])  [float element]",  fun() -> 'Deep':'SumWeights'([1, 100.5]) end},
       {"C8 forged    SumWeights([1, 300])  [out-of-range int element]",
                                                         fun() -> 'Deep':'SumWeights'([1, 300]) end},
       {"C9 forged    SumWeights([1, foo])  [atom element]",     fun() -> 'Deep':'SumWeights'([1, foo]) end},
       {"C10 forged   WeightPub(100.5)  [exported control]",      fun() -> 'Deep':'WeightPub'(100.5) end},
       {"C11 control  Doubled([1, 2])",                  fun() -> 'Deep':'Doubled'([1, 2]) end},
       {"C12 forged   Doubled([1, 1.5])  [float element, private fun handed to List.Map]",
                                                         fun() -> 'Deep':'Doubled'([1, 1.5]) end}],
    [begin
         R = try {ok, F()}
             catch Class:Reason:St ->
                 {error, Class, Reason, hd([{M, Fn, ar(A)} || {M, Fn, A, _} <- St, M =:= 'Deep'] ++ [none])}
             end,
         io:format("~s~n      => ~p~n", [Name, R])
     end || {Name, F} <- Cases].
ar(A) when is_list(A) -> length(A);
ar(A) -> A.
