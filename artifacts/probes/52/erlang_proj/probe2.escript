#!/usr/bin/env escript
%% Does xref flag a call to a module that exists nowhere (an Elixir lib not on the path)?
main(_) ->
    code:add_path("ebin"),
    {ok,_} = xref:start(s),
    xref:set_default(s,[{warnings,false}]),
    {ok,_} = xref:add_directory(s,"ebin"),
    io:format("modules analysed: ~p~n", [xref:q(s, "AM")]),
    io:format("myapp calls: ~p~n", [xref:analyze(s, {module_call, myapp})]),
    io:format("undefined_function_calls (dir only): ~p~n", [xref:analyze(s, undefined_function_calls)]),
    
    ok.
