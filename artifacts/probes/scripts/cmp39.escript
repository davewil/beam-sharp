#!/usr/bin/env escript
%% cmp39 DIR : compare erl vs bs instruction lists for every hot function (names normalised), print first difference
main([D]) ->
  F = fun(Mod) -> {beam_file,_,_,_,_,Fs}=beam_disasm:file(D++"/"++Mod++".beam"), Fs end,
  E = F("bench_erl"), B = F("Day01"),
  Pairs = [{wrap,'Wrap',1},{hit,'Hit',1},{spin,'Spin',4},{sign,'Sign',1},{size_,'Size',1},{clicks,'Clicks',3}],
  [begin
     [CE]=[C||{function,N,A,_,C}<-E,N=:=En,A=:=Ar], [CB]=[C||{function,N,A,_,C}<-B,N=:=Bn,A=:=Ar],
     Norm=fun(C)-> lists:flatten(io_lib:format("~p",[C])) end,
     Strip=fun(T)-> lists:foldl(fun(Re,A)-> re:replace(A,Re,"",[global,{return,list}]) end, T, ["\\{label,[0-9]+\\},?","\\{line,[0-9]+\\},?","\\{f,[0-9]+\\}","\\{label,[0-9]+\\}"]) end,
     N1=Strip(re:replace(Norm(CE),"bench_erl|'?(wrap|hit|spin|sign|size_|clicks)'?","M",[global,{return,list}])),
     N2=Strip(re:replace(Norm(CB),"'?Day01'?|'?(Wrap|Hit|Spin|Sign|Size|Clicks)'?","M",[global,{return,list}])),
     io:format("~-8s ~p instrs vs ~p; identical-modulo-labels-lines-names=~p~n",[En,length(CE),length(CB), re:replace(N1,"\\s+","",[global,{return,list}])=:=re:replace(N2,"\\s+","",[global,{return,list}])])
   end || {En,Bn,Ar} <- Pairs].
