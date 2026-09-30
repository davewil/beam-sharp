#!/usr/bin/env escript
%% usage: corpus.escript Dir... -- totals over every .beam in the given output dirs:
%% functions, private functions, guards on each, Code-chunk bytes.
main(Dirs) ->
    Beams = lists:append([filelib:wildcard(D ++ "/*.beam") || D <- Dirs]),
    Rows = lists:append([fns(B) || B <- Beams]),
    Code = lists:sum([code(B) || B <- Beams]),
    P = [R || {priv, _, _} = R <- Rows], E = [R || {exp, _, _} = R <- Rows],
    Cnt = fun(L, K) -> length([1 || {_, _, Fl} <- L, lists:member(K, Fl)]) end,
    io:format("beams=~p functions=~p exported=~p private=~p | private with: tag=~p kind=~p float=~p | exported with: tag=~p kind=~p float=~p | code_bytes=~p~n",
      [length(Beams), length(Rows), length(E), length(P), Cnt(P,tag), Cnt(P,int), Cnt(P,float), Cnt(E,tag), Cnt(E,int), Cnt(E,float), Code]).
code(B) -> {ok,{_,[{"Code",C}]}} = beam_lib:chunks(B, ["Code"]), byte_size(C).
fns(B) ->
    {ok,{_,[{abstract_code,{_,Forms}}]}} = beam_lib:chunks(B,[abstract_code]),
    Exp = lists:append([X || {attribute,_,export,X} <- Forms]),
    [begin
        T = lists:flatten([erl_pp:guard(G) || {clause,_,_,G,_} <- Cs, G =/= []]),   %% guards only: a head pattern on 'Kind' is not the boundary test
        Fl = [tag || has(T,"map_get('Kind'")] ++ [int || has(T,"is_integer")] ++ [float || has(T,"is_float")],
        {case lists:member({N,A},Exp) of true -> exp; false -> priv end, {N,A}, Fl}
     end || {function,_,N,A,Cs} <- Forms, N =/= 'bs@type_atoms', N =/= module_info].
has(S,P) -> string:find(S,P) =/= nomatch.
