-module(esc).
-export([main/1]).
%% Run as an escript, exactly where bsc runs: what do the code-server calls say
%% about a module that lives INSIDE the escript archive?
main(_) ->
    io:format("  code:which(esc)        = ~p~n", [code:which(esc)]),
    io:format("  code:lib_dir(esc)      = ~p~n", [code:lib_dir(esc)]),
    io:format("  code:which(bs_check)   = ~p~n", [code:which(bs_check)]),
    io:format("  code:ensure_loaded(esc)= ~p~n", [code:ensure_loaded(esc)]),
    io:format("  prov-style app_of(esc) = ~p~n", [case code:which(esc) of
                F when is_list(F) -> lists:sublist(lists:reverse(filename:split(F)), 3);
                O -> O end]),
    io:format("  application:load(esc) = ~p~n", [application:load(esc)]),
    io:format("  [ERL_LIBS inherited by the escript] code:lib_dir(greeter) = ~p~n", [code:lib_dir(greeter)]),
    io:format("  [ERL_LIBS inherited by the escript] code:which('Elixir.Greeter') = ~p~n", [code:which('Elixir.Greeter')]).
