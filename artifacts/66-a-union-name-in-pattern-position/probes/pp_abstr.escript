#!/usr/bin/env escript
%% Pretty-print a .abstr file (a file of dot-terminated forms) as Erlang source.
main([F]) ->
    {ok, Forms} = file:consult(F),
    io:format("~s~n", [[erl_pp:form(Fm) || Fm <- Forms]]).
