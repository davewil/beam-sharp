#!/usr/bin/env escript
%% usage: measure.escript File.beam   -> prints size, export count, chunk sizes, load time, call overhead
main([F]) ->
    {ok, Bin} = file:read_file(F),
    {ok, _, Chunks} = beam_lib:all_chunks(F),
    Sz = fun(Id) -> case lists:keyfind(Id, 1, Chunks) of {_, B} -> byte_size(B); false -> 0 end end,
    {ok, {M, [{exports, Ex}]}} = beam_lib:chunks(F, [exports]),
    %% load time: median of 5 batches of 500 loads
    Batch = fun() ->
        {T, _} = timer:tc(fun() -> lists:foreach(fun(_) ->
                    code:purge(M), code:delete(M), code:purge(M),
                    {module, M} = code:load_binary(M, F, Bin) end, lists:seq(1, 500)) end),
        T / 500 end,
    Ls = lists:sort([Batch() || _ <- lists:seq(1, 5)]),
    io:format("file_bytes=~p exports=~p ExpT=~p AtU8=~p Code=~p Dbgi=~p Line=~p FunT=~p load_us_median=~.1f load_us_min=~.1f~n",
              [byte_size(Bin), length(Ex), Sz("ExpT"), Sz("AtU8"), Sz("Code"), Sz("Dbgi"), Sz("Line"), Sz("FunT"),
               lists:nth(3, Ls), hd(Ls)]).
