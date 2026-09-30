#!/usr/bin/env escript
main([Ebin|_]) ->
    code:add_patha(Ebin), code:add_patha("tebin"),
    Mods = [list_to_atom(filename:basename(F, ".beam")) || F <- filelib:wildcard("tebin/*_tests.beam")],
    R = eunit:test(Mods, []),
    io:format("RESULT ~p over ~p modules~n", [R, length(Mods)]).
