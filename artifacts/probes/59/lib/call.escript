#!/usr/bin/env escript
%% usage: call.escript OutDir Module Function 'erlang term.'   -> prints  ok:<value> | <class>:<reason>@<top frame>
main([Dir, M, F, ArgS]) ->
    code:add_patha(Dir),
    {ok, Toks, _} = erl_scan:string(ArgS ++ "."),
    {ok, Arg} = erl_parse:parse_term(Toks),
    Mod = list_to_atom(M), Fun = list_to_atom(F),
    try Mod:Fun(Arg) of
        V -> io:format("ok:~p~n", [V])
    catch C:R:St ->
        [{SM,SF,SA,_}|_] = St,
        io:format("~p:~p@~p:~p/~p~n", [C,R,SM,SF,arity(SA)])
    end.
arity(A) when is_integer(A) -> A;
arity(A) when is_list(A) -> length(A).
