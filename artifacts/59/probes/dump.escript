#!/usr/bin/env escript
%% dump.escript FILE.beam  -- print each function's export status and the
%% guards the emitter put on it, from the beam's debug_info abstract code.
main([Beam]) ->
    {ok, {_, [{abstract_code, {raw_abstract_v1, Forms}}]}} =
        beam_lib:chunks(Beam, [abstract_code]),
    Exports = lists:append([E || {attribute, _, export, E} <- Forms]),
    [begin
         Vis = case lists:member({N, A}, Exports) of true -> "public "; false -> "private" end,
         Gs = [G || {clause, _, _, G, _} <- Cs],
         io:format("~s ~s/~p~n", [Vis, atom_to_list(N), A]),
         [io:format("    guard: ~s~n", [pp_guard(G)]) || G <- Gs, G =/= []]
     end || {function, _, N, A, Cs} <- Forms, N =/= module_info],
    ok.
pp_guard(G) -> string:join([string:trim(lists:flatten(erl_pp:guard(G))) || _ <- [x]], "").
