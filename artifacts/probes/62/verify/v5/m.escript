#!/usr/bin/env escript
main([P, A]) ->
  lists:foreach(fun(N) ->
    Mod = list_to_atom("N"++integer_to_list(N)),
    F = fun(R) -> filename:join([R, integer_to_list(N), atom_to_list(Mod)++".beam"]) end,
    {ok,Bp} = file:read_file(F(P)), {ok,Ba} = file:read_file(F(A)),
    Tp = lt(Mod, Bp), Ta = lt(Mod, Ba),
    {module,Mod} = code:load_binary(Mod,"x",Bp), Ep = length(Mod:module_info(exports)), code:purge(Mod), code:delete(Mod), code:purge(Mod),
    {module,Mod} = code:load_binary(Mod,"x",Ba), Ea = length(Mod:module_info(exports)), code:purge(Mod), code:delete(Mod), code:purge(Mod),
    io:format("n=~p bytes ~p/~p exports ~p/~p load_us min ~p/~p median ~p/~p (ratio med ~.2f)~n",
      [N, byte_size(Bp), byte_size(Ba), Ep, Ea, lists:min(Tp), lists:min(Ta), med(Tp), med(Ta), med(Ta)/med(Tp)])
  end, [1,10,100,1000]).
lt(Mod, Bin) -> [begin code:purge(Mod), code:delete(Mod), code:purge(Mod),
   S = erlang:monotonic_time(nanosecond), {module,Mod} = code:load_binary(Mod,"x",Bin), E = erlang:monotonic_time(nanosecond), (E-S) div 1000 end || _ <- lists:seq(1,40)].
med(L) -> S = lists:sort(L), lists:nth((length(S)+1) div 2, S).
