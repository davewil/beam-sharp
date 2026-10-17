%% usage: erl -noshell -pa ELIXIR_EBIN -run dump main X.beam OUT.S
%% Recovers the debug-info forms from an Elixir-compiled beam and recompiles
%% them to a 'S' listing (the same shape erlc -S writes).
-module(dump_elixir).
-export([main/1]).
main([Beam, Out]) ->
    {ok, {_, [{abstract_code, {_, Forms}}]}} = beam_lib:chunks(Beam, [abstract_code]),
    {ok, M, Listing} = compile:forms(Forms, ['S', binary]),
    {_, _, _, Fs, _} = Listing,
    Flat = lists:append([[{function, N, A, E} | Is] || {function, N, A, E, Is} <- Fs]),
    ok = file:write_file(Out, [io_lib:format("~p.~n", [T]) || T <- Flat]),
    io:format("~p~n", [M]),
    halt().
