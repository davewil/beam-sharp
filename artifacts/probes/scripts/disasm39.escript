#!/usr/bin/env escript
%% disasm39 DIR : instruction streams of spin loops; counts {tr,..} typed operands per module
main([D]) ->
  lists:foreach(fun({Mod,Fn,Ar}) ->
    {beam_file,_,_,_,_,Fs} = beam_disasm:file(D++"/"++Mod++".beam"),
    [{function,_,_,_,Code}] = [F || F={function,N,A,_,_} <- Fs, atom_to_list(N)=:=Fn, A=:=Ar],
    Txt = lists:flatten(io_lib:format("~p",[Code])),
    Tr = length(string:split(Txt,"tr",all))-1,
    io:format("~-14s ~-6s instrs=~p tr_operands=~p~n",[Mod,Fn,length(Code),Tr]) end,
   [{"bench_erl","spin",4},{"Day01","Spin",4}]).
