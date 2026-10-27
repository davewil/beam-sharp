#!/usr/bin/env escript
%% usage: guard_shape.escript FILE.abstr  -- prints functions, then asserts guard shapes.
main([F]) ->
    {ok, Fs} = file:consult(F),
    [io:format("~s", [erl_pp:form(X)]) || X <- Fs, element(1, X) =:= function],
    Guards = fun(Name) -> [G || {function,_,N,_,Cl} <- Fs, N =:= Name, {clause,_,_,G,_} <- [hd(Cl)]] end,
    Walk = fun W(T, P) when is_tuple(T) -> P(T) orelse lists:any(fun(E) -> W(E, P) end, tuple_to_list(T));
               W(L, P) when is_list(L) -> lists:any(fun(E) -> W(E, P) end, L);
               W(_, _) -> false end,
    IsInt = fun({call,_,{remote,_,{atom,_,erlang},{atom,_,is_integer}},_}) -> true; (_) -> false end,
    IsTag = fun({op,_,'=:=',{call,_,{remote,_,{atom,_,erlang},{atom,_,map_get}},[{atom,_,'Kind'}|_]},_}) -> true; (_) -> false end,
    Has = fun(Name, P) -> lists:any(fun(G) -> Walk(G, P) end, Guards(Name)) end,
    %% non-vacuity: every function inspected must have been found, else a miss reads as 'no guard'
    Found = [{N, length(Guards(N))} || N <- ['Total','Big','BigOf','TotalOf','SumTotals','SumBig']],
    [io:format("FOUND ~p clause-guard lists for ~p~n", [C, N]) || {N, C} <- Found],
    true = lists:all(fun({_, C}) -> C =:= 1 end, Found),
    R = [{'Total (private) has tag test',        Has('Total', IsTag),   true},
         {'Big (private) has is_integer',        Has('Big', IsInt),     false},
         {'BigOf (exported) has is_integer',     Has('BigOf', IsInt),   true},
         {'TotalOf (exported) has tag test',     Has('TotalOf', IsTag), true},
         {'SumTotals (exported list<Order>) has any element test',
              Has('SumTotals', IsTag) orelse Has('SumTotals', IsInt), false},
         {'SumBig (exported list<Octet>) has any element test',
              Has('SumBig', IsTag) orelse Has('SumBig', IsInt), false}],
    [io:format("CHECK ~s: observed=~p expected=~p ~s~n", [N, O, E, case O =:= E of true -> "ok"; false -> "FAIL" end]) || {N,O,E} <- R],
    halt(case lists:all(fun({_,O,E}) -> O =:= E end, R) of true -> 0; false -> 1 end).
