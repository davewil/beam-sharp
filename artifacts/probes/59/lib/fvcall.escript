#!/usr/bin/env escript
%% usage: fvcall.escript OutDir Getter Arg  -- gets a fun from Fv:Getter(member), applies it to the (erlang term) Arg from outside
main([Dir, G, ArgS]) ->
    code:add_patha(Dir),
    {ok, T, _} = erl_scan:string(ArgS ++ "."), {ok, Arg} = erl_parse:parse_term(T),
    F = 'Fv':(list_to_atom(G))(member),
    try F(Arg) of V -> io:format("ok:~w~n", [V])
    catch C:R:St -> [{M,Fn,A,_}|_] = St, io:format("~w:~w@~w:~w/~w~n", [C,R,M,Fn,if is_list(A) -> length(A); true -> A end]) end.
