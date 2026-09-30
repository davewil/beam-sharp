#!/usr/bin/env escript
%% usage: asm.escript File.beam  -- prints the BEAM assembly (compile:forms to_asm) of the abstract code, minus the bs@type_atoms helper
main([F]) ->
    {ok,{_,[{abstract_code,{_,Forms}}]}} = beam_lib:chunks(F,[abstract_code]),
    {ok,_,{Mod,Exp,Attr,Fns,Lbls}} = compile:noenv_forms(Forms,[to_asm,binary,report_errors,no_inline]),
    io:format("module ~p exports ~p~n",[Mod,Exp]),
    lists:foreach(fun({function,N,A,E,Is}) when N =/= 'bs@type_atoms' ->
        io:format("~n-- ~p/~p (entry label ~p)~n",[N,A,E]),
        [io:format("  ~p~n",[I]) || I <- Is]; (_) -> ok end, Fns).
