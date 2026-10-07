#!/usr/bin/env escript
%% Print the B# AST of refinements and the pattern for negative literals.
main(_) ->
    code:add_pathsa(filelib:wildcard("/home/user/beam-sharp/compiler/_build/default/lib/*/ebin")),
    code:add_patha("/home/user/beam-sharp/compiler/_build/default/bin"),
    case code:which(bs_parser) of non_existing -> io:format("no bs_parser beam; paths ~p~n",[code:get_path()]); _ -> ok end,
    [show(S) || S <- [
       "type T = int where value >= -5\n",
       "type T = int where value >= 0 - 5\n",
       "type T = int where value >= -(-5)\n",
       "type T = int where value >= 2 + 3\n",
       "type T = int where value >= -0.5\n",
       "module M\npublic atom F(int x)\nF(<= -1) -> :neg\n"]].
show(Src) ->
    {ok, Toks, _} = bs_lexer:string(Src),
    {ok, P} = bs_parser:parse(Toks),
    io:format("~s=> ~p~n~n", [Src, P]).
