#!/usr/bin/env escript
main([F]) -> {beam_file, _M, Ex, _A, _C, Code} = beam_disasm:file(F),
  io:format("~p~n~p~n", [lists:sort(Ex), Code]).
