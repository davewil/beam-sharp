#!/usr/bin/env escript
%% disasm_count.escript DIR -- is_integer / is_float / get_map_elements-on-Kind TESTS that survive in the
%% BEAM bytecode (not the abstract code), split by exported vs local function.
main([Dir]) ->
    Beams = filelib:wildcard(filename:join(Dir, "**/*.beam")),
    R = lists:foldl(fun(B, Acc) ->
        {ok, {_, [{abstract_code, {raw_abstract_v1, Forms}}]}} = beam_lib:chunks(B, [abstract_code]),
        Ex = lists:append([E || {attribute, _, export, E} <- Forms]),
        {beam_file, _, _, _, _, Fs} = beam_disasm:file(B),
        lists:foldl(fun({function, N, A, _, Is}, Ac) ->
            V = case lists:member({N, A}, Ex) of true -> pub; false -> priv end,
            Cnt = length([I || I = {test, is_integer, _, _} <- Is]),
            maps:update_with(V, fun(X) -> X + Cnt end, Cnt, Ac)
        end, Acc, [F || F = {function, N, _, _, _} <- Fs, N =/= module_info]) end, #{}, Beams),
    io:format("surviving is_integer tests in bytecode: exported=~p local=~p~n",
              [maps:get(pub, R, 0), maps:get(priv, R, 0)]).
