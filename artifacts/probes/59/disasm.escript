#!/usr/bin/env escript
%% usage: disasm.escript FILE.abstr FunName
%% Prints beam_disasm code of FunName with the private TAG test as emitted, then stripped,
%% plus Code-chunk size (no debug_info) of the whole module in both forms.
main([F, Name]) ->
    {ok, Forms} = file:consult(F),
    Exports = lists:append([L || {attribute,_,export,L} <- Forms]),
    Forms1 = [strip(X, Exports) || X <- Forms],
    [show(Tag, Fs, list_to_atom(Name)) || {Tag, Fs} <- [{"AS EMITTED", Forms}, {"TAG TEST STRIPPED", Forms1}]].

show(Tag, Forms, Name) ->
    {ok,_,Bin,_} = compile:forms(Forms, [binary, return]),
    {ok,{_,[{"Code",Code}]}} = beam_lib:chunks(Bin,["Code"]),
    {beam_file,_,_,_,_,Fs} = beam_disasm:file(Bin),
    io:format("~n=== ~s: whole-module beam ~w bytes, Code chunk ~w bytes~n", [Tag, byte_size(Bin), byte_size(Code)]),
    [begin io:format("function ~w/~w~n", [N,A]), [io:format("  ~p~n",[I]) || I <- Is] end
     || {function,N,A,_,Is} <- Fs, N =:= Name].

strip({function,L,N,A,Cs}, Exports) ->
    case lists:member({N,A},Exports) of
        true -> {function,L,N,A,Cs};
        false -> {function,L,N,A,[{clause,CL,Ps,[[T||T<-G,not is_tag(T)]||G<-Gs,[T||T<-G,not is_tag(T)]=/=[]],B}||{clause,CL,Ps,Gs,B}<-Cs]}
    end;
strip(X,_) -> X.
is_tag({op,_,'=:=',{call,_,{remote,_,{atom,_,erlang},{atom,_,map_get}},[{atom,_,'Kind'},_]},{atom,_,_}}) -> true;
is_tag(_) -> false.
