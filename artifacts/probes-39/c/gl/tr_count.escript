#!/usr/bin/env escript
-mode(compile).
main([F]) ->
    {beam_file, _, _, _, _, Fs} = beam_disasm:file(F),
    C = fun Cnt({tr,_,_}) -> 1; Cnt(T) when is_tuple(T) -> lists:sum([Cnt(E) || E <- tuple_to_list(T)]);
            Cnt(L) when is_list(L) -> lists:sum([Cnt(E) || E <- L]); Cnt(_) -> 0 end,
    io:format("~p~n", [[{N, A, C(I)} || {function, N, A, _, I} <- Fs, N =:= spin orelse N =:= wrap]]).
