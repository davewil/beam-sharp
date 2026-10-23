#!/usr/bin/env escript
main([F]) -> {ok,{_,[{abstract_code,{_,AC}}]}}=beam_lib:chunks(F,[abstract_code]), [io:format("~s~n",[erl_pp:form(X)]) || X={function,_,_,_,_} <- AC].
