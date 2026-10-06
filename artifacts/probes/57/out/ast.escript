#!/usr/bin/env escript
main([Ebin, Src]) ->
  code:add_patha(Ebin),
  {ok, B} = file:read_file(Src),
  {ok, T, _} = bs_lexer:string(binary_to_list(B)),
  {ok, Decls} = bs_parser:parse(T),
  [io:format("~p~n", [P]) || {type_refined, _, _, _, P} <- Decls].
