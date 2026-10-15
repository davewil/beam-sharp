#!/usr/bin/env escript
%% 59_guards.escript BEAM_FILE  -- print, per function in the emitted abstract code,
%% whether it is exported and whether any clause GUARD carries the record tag test
%% (erlang:map_get('Kind', V) =:= Tag), erlang:is_integer/1, or erlang:is_float/1.
%% Reads the abstract_code chunk, so what is printed is what was emitted, not what a
%% source comment says.
main([Beam]) ->
    {ok, {_, [{abstract_code, {_, Forms}}]}} = beam_lib:chunks(Beam, [abstract_code]),
    Exports = lists:append([L || {attribute, _, export, L} <- Forms]),
    [begin
         Pub = lists:member({N, A}, Exports),
         Gs = [G || {clause, _, _, Gss, _} <- Cs, G <- lists:append(Gss)],
         Tag = has(Gs, fun tag/1),
         HeadTag = lists:any(fun({clause, _, Ps, _, _}) -> walk(Ps, fun headtag/1) end, Cs),
         Int = has(Gs, fun(T) -> bif(T, is_integer) end),
         Flt = has(Gs, fun(T) -> bif(T, is_float) end),
         io:format("~-16s ~-8s tag_guard=~-3s tag_in_head=~-3s is_integer=~-3s is_float=~-3s~n",
                   [lists:flatten(io_lib:format("~s/~p", [N, A])), if Pub -> "exported"; true -> "private" end,
                    yn(Tag), yn(HeadTag), yn(Int), yn(Flt)])
     end || {function, _, N, A, Cs} <- Forms, N =/= module_info,
            not lists:prefix("bs@", atom_to_list(N))].
yn(true) -> "Y"; yn(false) -> "n".
has(Gs, F) -> lists:any(fun(G) -> walk(G, F) end, Gs).
walk(T, F) -> F(T) orelse (is_tuple(T) andalso lists:any(fun(X) -> walk(X, F) end, tuple_to_list(T)))
                  orelse (is_list(T) andalso lists:any(fun(X) -> walk(X, F) end, T)).
tag({op, _, '=:=', {call, _, {remote, _, {atom, _, erlang}, {atom, _, map_get}}, [{atom, _, 'Kind'}, _]}, _}) -> true;
tag(_) -> false.
headtag({map_field_exact, _, {atom, _, 'Kind'}, _}) -> true;
headtag(_) -> false.
bif({call, _, {remote, _, {atom, _, erlang}, {atom, _, B}}, _}, B) -> true;
bif(_, _) -> false.
