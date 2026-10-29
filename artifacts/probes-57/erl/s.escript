#!/usr/bin/env escript
main(_) ->
  {ok,T,_}=erl_scan:string("g(X) when X >= -5 -> a. p(-5) -> b. q(X) when X >= 2 - 7 -> c. r(X) when X >= - -5 -> d."),
  Fs = split(T),
  [begin {ok,F}=erl_parse:parse_form(Fm), io:format("~p~n",[F]) end || Fm <- Fs],
  {ok,e,Core}=compile:file("e.erl",[to_core,binary,return_errors,no_copt]) , 
  io:format("-- unoptimised core (no_copt) written~n"),
  file:write_file("core_nocopt.txt", io_lib:format("~s",[core_pp:format(Core)])),
  {ok,e,Core2}=compile:file("e.erl",[to_core,binary]) , 
  file:write_file("core_default.txt", io_lib:format("~s",[core_pp:format(Core2)])).
split(Ts) -> split(Ts,[],[]).
split([],[],A) -> lists:reverse(A);
split([{dot,_}=D|R],C,A) -> split(R,[],[lists:reverse([D|C])|A]);
split([T|R],C,A) -> split(R,[T|C],A).
