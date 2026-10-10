#!/usr/bin/env escript
%% pp.escript FILE.abstr [Name...] -- pretty-print the functions of an emitted .abstr
main([F | Names]) ->
    {ok, Forms} = file:consult(F),
    [io:format("~s", [erl_pp:form(X)]) || {function, _, N, _, _} = X <- Forms,
        Names =:= [] orelse lists:member(atom_to_list(N), Names)].
