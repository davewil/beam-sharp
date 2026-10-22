-module(dump).
-export([main/1]).
main([Dir]) ->
    Fs = filelib:wildcard(Dir ++ "/*.beam"),
    [begin
        {ok, {M, [{exports, Ex}]}} = beam_lib:chunks(F, [exports]),
        [io:format("~s\t~s\t~p~n", [M, N, A]) || {N, A} <- lists:sort(Ex), N =/= module_info, N =/= 'bs@type_atoms']
     end || F <- Fs],
    halt().
