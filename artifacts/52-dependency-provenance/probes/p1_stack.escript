#!/usr/bin/env escript
main([Dir]) ->
    true = code:add_patha(Dir),
    R = try {ok, 'Dep':'ViaExDep'(<<"hi">>)}
        catch C:E:St -> {C, E, hd(St)} end,
    io:format("~p~n", [R]),
    io:format("code:which('Elixir.ExDep') = ~p~n", [code:which('Elixir.ExDep')]).
