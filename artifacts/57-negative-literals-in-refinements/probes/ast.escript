#!/usr/bin/env escript
%% usage: ast.escript EBIN  -- reads source from stdin, prints parse tree
main([Ebin]) ->
    code:add_patha(Ebin),
    {ok, Bin} = file:read(standard_io, 1000000),
    Src = lists:flatten(io_lib:format("~s", [Bin])),
    {ok, Toks, _} = bs_lexer:string(Src),
    io:format("~p~n", [bs_parser:parse(Toks)]).
