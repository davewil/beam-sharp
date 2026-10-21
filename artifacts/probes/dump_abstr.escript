#!/usr/bin/env escript
%% Pretty-print a bsc .abstr file as Erlang source, functions only (drops spec/file noise with -f FUN).
main([F|Funs]) ->
    {ok, Forms} = file:consult(F),
    Keep = [Fm || Fm <- Forms, case Fm of
              {function,_,N,_,_} -> Funs =:= [] orelse lists:member(atom_to_list(N), Funs);
              _ -> false end],
    [io:format("~s~n", [erl_pp:form(Fm)]) || Fm <- Keep].
