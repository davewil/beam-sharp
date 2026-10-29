#!/usr/bin/env escript
%% usage: cmp.escript A.beam B.beam  -> compares beam_disasm instruction lists, with and without {tr,..} stripped; dumps Type chunk size.
main([A, B]) ->
    {IA, IB} = {instrs(A), instrs(B)},
    io:format("~s: ~p instrs;  ~s: ~p instrs~n", [A, count(IA), B, count(IB)]),
    io:format("identical as-is (incl. type annotations): ~p~n", [IA =:= IB]),
    io:format("identical after dropping {tr,..} annotations: ~p~n", [strip(IA) =:= strip(IB)]),
    io:format("{tr,..} operands: ~p vs ~p~n", [ntr(IA), ntr(IB)]),
    io:format("Type chunk bytes: ~p vs ~p~n", [chunk(A), chunk(B)]).
instrs(F) ->
    {beam_file, M, _, _, _, Fs} = beam_disasm:file(F),
    %% normalise the module name and per-function ordering is kept
    norm(Fs, M).
norm(T, M) when is_atom(T), T =:= M -> mod;
norm(T, M) when is_tuple(T) -> list_to_tuple([norm(E, M) || E <- tuple_to_list(T)]);
norm(L, M) when is_list(L) -> [norm(E, M) || E <- L];
norm(T, _) -> T.
count(Fs) -> lists:sum([length(element(5, F)) || F <- Fs]).
strip({tr, R, _}) -> R;
strip(T) when is_tuple(T) -> list_to_tuple([strip(E) || E <- tuple_to_list(T)]);
strip(L) when is_list(L) -> [strip(E) || E <- L];
strip(T) -> T.
ntr(T) -> length(find(T)).
find({tr, _, _}) -> [x];
find(T) when is_tuple(T) -> lists:append([find(E) || E <- tuple_to_list(T)]);
find(L) when is_list(L) -> lists:append([find(E) || E <- L]);
find(_) -> [].
chunk(F) ->
    {ok, Bin} = file:read_file(F),
    {ok, _, Cs} = beam_lib:all_chunks(Bin),
    case lists:keyfind("Type", 1, Cs) of {_, B} -> byte_size(B); false -> none end.
