#!/usr/bin/env escript
%% pp.escript FILE.abstr  : pretty-print the emitted Erlang forms bsc wrote
main([F]) ->
    {ok, Forms} = file:consult(F),
    [io:put_chars(erl_pp:form(X)) || X <- Forms, element(1, X) =/= attribute orelse element(3, X) =/= file].
