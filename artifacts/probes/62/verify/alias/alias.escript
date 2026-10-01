#!/usr/bin/env escript
%% usage: alias.escript Abstr Mode  -> prints byte sizes (debug_info) base/alias/dup
main([F]) ->
  {ok, Forms0} = file:consult(F),
  Base = size_of(Forms0),
  Exps = lists:append([E || {attribute,_,export,E} <- Forms0]),
  Pub = [{N,A} || {N,A} <- Exps, N =/= 'bs@type_atoms'],
  Alias = fun(N) -> list_to_atom(string:lowercase(atom_to_list(N))) end,
  %% forwarding alias
  Fwd = [{function,0,Alias(N),A,[{clause,0,[{var,0,list_to_atom("V"++integer_to_list(I))}||I<-lists:seq(1,A)],[],
          [{call,0,{atom,0,N},[{var,0,list_to_atom("V"++integer_to_list(I))}||I<-lists:seq(1,A)]}]}]} || {N,A} <- Pub],
  F1 = [case X of {attribute,L,export,E} -> {attribute,L,export,E++[{Alias(N),A}||{N,A}<-Pub]}; _ -> X end || X <- Forms0] ++ Fwd,
  %% duplicate body
  Dup = [begin {function,L,_,_,Cl} = lists:keyfind(N,3,[X||X={function,_,_,_,_}<-Forms0]), {function,L,Alias(N),A,Cl} end || {N,A} <- Pub],
  F2 = [case X of {attribute,L,export,E} -> {attribute,L,export,E++[{Alias(N),A}||{N,A}<-Pub]}; _ -> X end || X <- Forms0] ++ Dup,
  io:format("~p base=~p alias=~p (+~.1f%) dup=~p (+~.1f%)~n",[length(Pub),Base,size_of(F1),(size_of(F1)-Base)*100/Base,size_of(F2),(size_of(F2)-Base)*100/Base]).
size_of(Forms) -> {ok,_,B} = compile:forms(Forms,[debug_info,return_errors,nowarn_unused_function,nowarn_missing_spec_documented]), byte_size(B).
