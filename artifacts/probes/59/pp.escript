#!/usr/bin/env escript
%% usage: pp.escript FILE.abstr  -- prints the emitted functions as Erlang source
main([F]) -> {ok,Fs}=file:consult(F),
  [io:format("~s~n",[erl_pp:form(X)]) || X <- Fs, element(1,X)==function, element(3,X)=/=bs@type_atoms].
