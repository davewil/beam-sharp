#!/usr/bin/env escript
main(_) ->
    io:format("erlc:~n"),
    R = compile:file("src/myapp.erl", [{outdir,"ebin"}, return, warn_unused_vars, debug_info]),
    io:format("  compile result: ~p~n", [element(1,R)]),
    io:format("  (any warning about 'Elixir.NoSuchLibrary'? see tuple: ~p)~n", [tl(tuple_to_list(R))]),
    code:add_path("ebin"),
    io:format("xref:~n"),
    {ok,_} = xref:start(s),
    xref:set_default(s,[{warnings,false}]),
    {ok,_} = xref:add_directory(s,"ebin"),
    io:format("  undefined_function_calls: ~p~n", [xref:analyze(s, undefined_function_calls)]),
    io:format("application:ensure_all_started(myapp):~n  ~p~n", [application:ensure_all_started(myapp)]),
    ok.
