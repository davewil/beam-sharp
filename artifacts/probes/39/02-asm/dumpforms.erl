%% Writes the abstract forms of an Elixir .beam (from its debug_info chunk) as an .erl-ish term file
-module(dumpforms).
-export([main/1]).
main([Beam, Out]) ->
    {ok, {_, [{debug_info, {debug_info_v1, Backend, Data}}]}} = beam_lib:chunks(Beam, [debug_info]),
    {ok, Forms} = Backend:debug_info(erlang_v1, 'Elixir.BenchEx', Data, []),
    ok = file:write_file(Out, [io_lib:format("~p.~n", [F]) || F <- Forms]),
    halt().
