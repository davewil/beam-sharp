%%% types.erl -- dump the operand type annotations in a .beam's "Type" chunk and count instructions.
%%% usage: erl -noshell -pa . -run types main file.beam
%%% Uses beam_lib for the Type chunk raw size, and beam_disasm for instruction counts of
%%% hot functions (spin/4, wrap/1). Type annotations themselves are read from the +to_asm .S
%%% (see run.sh) because beam_disasm does not render {tr,...}.
-module(types).
-export([main/1]).
main([F]) ->
    {ok, _, Chunks} = beam_lib:all_chunks(F),
    TypeSz = case lists:keyfind("Type", 1, Chunks) of {_, B} -> byte_size(B); false -> 0 end,
    {beam_file, _, _, _, _, Fs} = beam_disasm:file(F),
    Counts = [{N, A, length([I || I <- Code, element(1, I) =/= label, element(1, I) =/= line])}
              || {function, N, A, _, Code} <- Fs],
    io:format("~s type_chunk_bytes=~p file_bytes=~p~n", [filename:basename(F), TypeSz, filelib:file_size(F)]),
    [io:format("  ~p/~p instrs(excl label/line)=~p~n", [N, A, C])
     || {N, A, C} <- Counts, lists:member(N, [spin, wrap, sign, size_, hit, clicks, tup, cnt])],
    halt().
