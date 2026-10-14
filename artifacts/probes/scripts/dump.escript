#!/usr/bin/env escript
main([F]) -> {ok,Forms}=file:consult(F),
  [io:format("~s",[erl_pp:form(X)]) || X <- Forms, element(1,X)=:=function, element(3,X)=/=bs@type_atoms].
