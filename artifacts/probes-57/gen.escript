#!/usr/bin/env escript
main(_) ->
  io:format("yecc: ~p~n",[yecc:file("bs_parser.yrl",[{verbose,false},{report,true}])]),
  io:format("leex: ~p~n",[catch leex:file("bs_lexer.xrl",[])]).
