#!/usr/bin/env escript
%%! -pa /tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/bsc-build/ebin
main(_) ->
    Q = bs_check:reserved_qualifiers(),
    T = bs_check:reserved_table(),
    io:format("reserved qualifiers (bs_check:reserved_qualifiers/0): ~p~n", [Q]),
    io:format("is_protocol('Enumerable')=~p  is_protocol('Foo')=~p (control)~n",
              [bs_check:is_protocol('Enumerable'), bs_check:is_protocol('Foo')]),
    io:format("operations (rows) in standard_table: ~p~n", [length(T)]),
    [io:format("  ~p: ~p rows~n", [X, length([1 || {Y,_,_} <- T, Y =:= X])]) || X <- Q].
