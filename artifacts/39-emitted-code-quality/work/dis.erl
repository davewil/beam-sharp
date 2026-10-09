-module(dis).
-export([main/1]).
main([F]) ->
    {beam_file, M, _Ex, _Attr, _CI, Fs} = beam_disasm:file(F),
    io:format("MODULE ~p~n", [M]),
    [begin io:format("~n--- ~p/~p (~p instrs)~n", [N, A, length(Is)]), [io:format("  ~p~n",[I]) || I <- Is] end
     || {function, N, A, _, Is} <- Fs],
    halt().
