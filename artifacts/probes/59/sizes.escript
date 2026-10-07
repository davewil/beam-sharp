#!/usr/bin/env escript
%% usage: sizes.escript FILE.abstr -- module bytes (with and without debug_info) and Code-chunk bytes
%% for: as emitted | private tag test stripped | private int test added (widened)
main([F]) ->
    {ok, Forms0} = file:consult(F),
    E = lists:append([L || {attribute,_,export,L} <- Forms0]),
    Vs = [{emitted, Forms0}, {stripped, [strip(X,E)||X<-Forms0]}, {widened,[widen(X,E,Forms0)||X<-Forms0]}],
    io:format("~-9s ~14s ~14s ~12s ~s~n",["variant","beam+dbginfo","beam","Code chunk","Inner / IInner disasm instrs"]),
    [begin
       {ok,_,B1,_} = compile:forms(Fs,[debug_info,binary,return]),
       {ok,_,B2,_} = compile:forms(Fs,[binary,return]),
       {ok,{_,[{"Code",C}]}} = beam_lib:chunks(B2,["Code"]),
       {beam_file,_,_,_,_,Fns} = beam_disasm:file(B2),
       N = fun(Nm) -> hd([length(Is)||{function,X,_,_,Is}<-Fns,X=:=Nm]) end,
       io:format("~-9s ~14w ~14w ~12w ~w / ~w~n",[V,byte_size(B1),byte_size(B2),byte_size(C),N('Inner'),N('IInner')])
     end || {V,Fs} <- Vs].
strip({function,L,N,A,Cs}, Ex) ->
    case lists:member({N,A},Ex) of
        true -> {function,L,N,A,Cs};
        false -> {function,L,N,A,[{clause,CL,Ps,[G1||G<-Gs,G1<-[[T||T<-G,not is_tag(T)]],G1=/=[]],B}||{clause,CL,Ps,Gs,B}<-Cs]}
    end;
strip(X,_) -> X.
is_tag({op,_,'=:=',{call,_,{remote,_,{atom,_,erlang},{atom,_,map_get}},[{atom,_,'Kind'},_]},{atom,_,_}}) -> true;
is_tag(_) -> false.
widen({function,L,N,A,Cs}, Ex, All) ->
    case lists:member({N,A},Ex) of
        true -> {function,L,N,A,Cs};
        false ->
            Spec = [Ts || {attribute,_,spec,{{N1,A1},[{type,_,'fun',[{type,_,product,Ts},_]}]}} <- All, N1 =:= N, A1 =:= A],
            Ints = case Spec of [Ts0] -> [I || {I,{type,_,integer,[]}} <- lists:zip(lists:seq(1,length(Ts0)),Ts0)]; _ -> [] end,
            T = [{call,0,{remote,0,{atom,0,erlang},{atom,0,is_integer}},[V]} || I <- Ints, {var,_,_}=V <- [lists:nth(I,hd([Ps||{clause,_,Ps,_,_}<-Cs]))]],
            {function,L,N,A,[{clause,CL,Ps,case Gs of [] when T=/=[] -> [T]; [] -> []; _ -> [T++G||G<-Gs] end,B}||{clause,CL,Ps,Gs,B}<-Cs]}
    end;
widen(X,_,_) -> X.
