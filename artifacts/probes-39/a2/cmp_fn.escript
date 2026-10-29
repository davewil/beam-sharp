#!/usr/bin/env escript
-mode(compile).
%% usage: cmp_fn.escript Ref.beam Other.beam fn1 fn2 ...  -> per function: instruction lists equal (with annotations)?
main([A, B | Fns]) ->
    FA = fns(A), FB = fns(B),
    [begin
        IA = get(N, FA), IB = get(N, FB),
        io:format("~-8s ~3w vs ~3w instrs  identical-with-annotations=~p  identical-ignoring-{tr}=~p~n",
                  [N, length(IA), length(IB), IA =:= IB, strip(IA) =:= strip(IB)])
     end || N <- [list_to_atom(F) || F <- Fns]].
fns(F) -> {beam_file, M, _, _, _, Fs} = beam_disasm:file(F),
    [{Name, norm(I, M)} || {function, Name, _, _, I} <- Fs].
get(N, L) -> proplists:get_value(N, L).
norm(T, M) when is_atom(T), T =:= M -> mod;
norm(T, M) when is_tuple(T) -> list_to_tuple([norm(E, M) || E <- tuple_to_list(T)]);
norm(L, M) when is_list(L) -> [norm(E, M) || E <- L];
norm(T, _) -> T.
strip({tr, R, _}) -> R;
strip(T) when is_tuple(T) -> list_to_tuple([strip(E) || E <- tuple_to_list(T)]);
strip(L) when is_list(L) -> [strip(E) || E <- L];
strip(T) -> T.
