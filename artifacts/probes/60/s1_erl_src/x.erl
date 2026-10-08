-module(x).
-export([main/0]).
main() ->
    {ok,_} = xref:start(s), xref:set_default(s,[{verbose,false},{warnings,false}]),
    {ok,_} = xref:add_directory(s, "."),
    {ok, Use} = xref:analyze(s, {module_use, pricing}),
    io:format("xref {module_use,pricing}: ~p~n", [Use]),
    {ok, Unused} = xref:analyze(s, exports_not_used),
    io:format("exports_not_used: ~p~n", [Unused]),
    xref:stop(s).
