#!/usr/bin/env escript
main([F,Fun]) ->
  {beam_file,_,_,_,_,Code} = beam_disasm:file(F),
  [ [io:format("~p~n",[I]) || I <- Is] || {function,N,_,_,Is} <- Code, atom_to_list(N)=:=Fun orelse Fun=:="all"].
