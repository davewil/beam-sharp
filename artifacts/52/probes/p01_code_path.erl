%% p01: what does the code server know with and without ERL_LIBS?
%% run: escript p01_code_path.erl     (and again with ERL_LIBS=/usr/lib/elixir/lib)
-module(p01_code_path).
main(_) ->
    io:format("ERL_LIBS=~p~n", [os:getenv("ERL_LIBS")]),
    [io:format("code:which(~p) = ~p~n", [M, code:which(M)])
     || M <- [lists, erlang, init, 'Elixir.String', 'Elixir.Enum', 'Elixir.Req', lits]],
    io:format("code:lib_dir(elixir) = ~p~n", [code:lib_dir(elixir)]),
    io:format("code:lib_dir(stdlib) = ~p~n", [code:lib_dir(stdlib)]),
    io:format("code:lib_dir(erts) = ~p~n", [code:lib_dir(erts)]).
