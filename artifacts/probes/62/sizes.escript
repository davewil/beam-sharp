#!/usr/bin/env escript
%% usage: sizes.escript BEAM  -> prints one line: total stripped exports ExpT Code Dbgi AtU8 nspecs
main([F]) ->
    {ok, Bin} = file:read_file(F),
    {ok, M, Chunks} = beam_lib:all_chunks(F),
    Sz = fun(Id) -> case lists:keyfind(Id, 1, Chunks) of {_, B} -> byte_size(B); false -> 0 end end,
    {ok, {M, [{debug_info, {debug_info_v1, Backend, Data}}]}} = beam_lib:chunks(F, [debug_info]),
    {ok, Fs} = Backend:debug_info(erlang_v1, M, Data, []),
    Specs = length([x || {attribute, _, spec, _} <- Fs]),
    {ok, {_, StrippedBin}} = beam_lib:strip(Bin),
    code:load_binary(M, F, Bin),
    NExp = length(M:module_info(exports)),
    io:format("total=~p stripped=~p exports=~p ExpT=~p Code=~p Dbgi=~p AtU8=~p LocT=~p Attr=~p specs=~p~n",
              [byte_size(Bin), byte_size(StrippedBin), NExp, Sz("ExpT"), Sz("Code"), Sz("Dbgi"), Sz("AtU8"), Sz("LocT"), Sz("Attr"), Specs]).
