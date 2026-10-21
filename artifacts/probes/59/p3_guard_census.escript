#!/usr/bin/env escript
%% 59 / probe 3 — over every .abstr bsc produced for the shipped examples: how many functions carry each
%% boundary guard, split exported / private?  (Counts clauses' guards only; a private is_integer may be the
%% author's own `when`, so prv_int is an UPPER bound on emitted kind tests.)
main([Dir]) ->
    Files = filelib:wildcard(filename:join(Dir, "*.abstr")),
    Rows = [census(F) || F <- Files],
    Tot = fun(K) -> lists:sum([maps:get(K, R) || R <- Rows]) end,
    io:format("modules=~p~n", [length(Files)]),
    io:format("exported fns with a guard: tag=~p int/kind=~p | private fns with a guard: tag=~p int/kind=~p~n",
              [Tot(exp_tag), Tot(exp_int), Tot(prv_tag), Tot(prv_int)]),
    ok.

census(F) ->
    {ok, Forms} = file:consult(F),
    Exports = lists:append([[N || N <- Ns] || {attribute,_,export,Ns} <- Forms]),
    Fns = [Fm || {function,_,Nm,_,_} = Fm <- Forms, Nm =/= 'bs@type_atoms'],
    Cls = fun({function,_,N,A,Clauses}) -> {lists:member({N,A}, Exports), N, Clauses} end,
    Info = [Cls(Fm) || Fm <- Fns],
    HasTag = fun(Gs) -> contains(Gs, fun({call,_,{remote,_,{atom,_,erlang},{atom,_,map_get}},[{atom,_,'Kind'}|_]}) -> true; (_) -> false end) end,
    HasInt = fun(Gs) -> contains(Gs, fun({call,_,{remote,_,{atom,_,erlang},{atom,_,is_integer}},_}) -> true; ({call,_,{atom,_,is_integer},_}) -> true; (_) -> false end) end,
    Count = fun(Pub, Pred) -> length([x || {P, _, Cs} <- Info, P =:= Pub, lists:any(fun({clause,_,_,G,_}) -> Pred(G) end, Cs)]) end,
    #{exp_tag => Count(true, HasTag), exp_int => Count(true, HasInt),
      prv_tag => Count(false, HasTag), prv_int => Count(false, HasInt)}.

contains(Gs, Pred) -> lists:any(fun(G) -> lists:any(fun(E) -> any_node(E, Pred) end, G) end, Gs).
any_node(T, P) when is_tuple(T) -> P(T) orelse lists:any(fun(E) -> any_node(E, P) end, tuple_to_list(T));
any_node(L, P) when is_list(L) -> lists:any(fun(E) -> any_node(E, P) end, L);
any_node(_, _) -> false.
