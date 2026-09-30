-module(probe12).
-export([main/1]).
main([]) ->
    [show(M, N) || {M, N} <- [{bench_erl, spin}, {bench_gleam, spin}, {'Elixir.BenchEx', spin}, {'Day01', 'Spin'}]],
    halt().
show(M, SpinName) ->
    Path = code:which(M),
    {ok, {_, [{compile_info, CI}]}} = beam_lib:chunks(Path, [compile_info]),
    {beam_file, _, _, _, _, Fs} = beam_disasm:file(Path),
    [{function, _, _, _, Code}] = [F || {function, N, 4, _, _} = F <- Fs, N =:= SpinName],
    Calls = [C || C <- Code, is_tuple(C), lists:member(element(1, C), [call, call_last, call_only])],
    io:format("~-16s options=~p~n   Spin/4: ~p instrs, ~p local calls~n",
              [M, proplists:get_value(options, CI), length(Code), length(Calls)]).
