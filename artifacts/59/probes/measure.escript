#!/usr/bin/env escript
%% measure.escript DIR  -- over every .beam under DIR: module count, file bytes,
%% Code-chunk bytes, and how many PUBLIC / PRIVATE functions carry each boundary-guard kind.
main([Dir]) ->
    Beams = filelib:wildcard(filename:join(Dir, "**/*.beam")),
    Rows = [row(B) || B <- Beams],
    Sum = fun(K) -> lists:sum([maps:get(K, R, 0) || R <- Rows]) end,
    io:format("modules=~p file_bytes=~p code_bytes=~p~n", [length(Rows), Sum(file), Sum(code)]),
    io:format("functions: public=~p private=~p~n", [Sum(pub), Sum(priv)]),
    [io:format("  ~-9s public=~p private=~p~n", [K, Sum({K, pub}), Sum({K, priv})])
     || K <- [tag, int, float]],
    io:format("  private functions whose name is taken as a value (fun Name/N): ~p~n", [Sum(escapes)]).
row(B) ->
    {ok, {_, [{abstract_code, {raw_abstract_v1, Forms}}, {"Code", Code}]}} =
        beam_lib:chunks(B, [abstract_code, "Code"]),
    Exports = lists:append([E || {attribute, _, export, E} <- Forms]),
    Fs = [{N, A, Cs} || {function, _, N, A, Cs} <- Forms, N =/= module_info, N =/= 'bs@type_atoms'],
    Tagged = fun(Cs, Pred) -> lists:any(fun({clause, _, _, G, _}) -> contains(G, Pred) end, Cs) end,
    Tag = fun(T) -> case T of {call, _, {atom, _, map_get}, [{atom, _, 'Kind'}, _]} -> true;
                              {call, _, {remote, _, {atom, _, erlang}, {atom, _, map_get}}, [{atom, _, 'Kind'}, _]} -> true;
                              _ -> false end end,
    Int = fun(T) -> case T of {call, _, {atom, _, is_integer}, _} -> true;
                              {call, _, {remote, _, {atom, _, erlang}, {atom, _, is_integer}}, _} -> true; _ -> false end end,
    Flt = fun(T) -> case T of {call, _, {atom, _, is_float}, _} -> true;
                              {call, _, {remote, _, {atom, _, erlang}, {atom, _, is_float}}, _} -> true; _ -> false end end,
    Funs = lists:usort(collect_local_funs(Forms)),
    Base = #{file => filelib:file_size(B), code => byte_size(Code)},
    lists:foldl(fun({N, A, Cs}, M) ->
        V = case lists:member({N, A}, Exports) of true -> pub; false -> priv end,
        M1 = maps:update_with(V, fun(X) -> X + 1 end, 1, M),
        M2 = lists:foldl(fun({K, P}, Acc) ->
                 case Tagged(Cs, P) of true -> maps:update_with({K, V}, fun(X) -> X + 1 end, 1, Acc); false -> Acc end
             end, M1, [{tag, Tag}, {int, Int}, {float, Flt}]),
        case V =:= priv andalso lists:member({N, A}, Funs) of
            true -> maps:update_with(escapes, fun(X) -> X + 1 end, 1, M2);
            false -> M2 end
    end, Base, Fs).
contains(T, P) when is_tuple(T) -> P(T) orelse lists:any(fun(E) -> contains(E, P) end, tuple_to_list(T));
contains(L, P) when is_list(L) -> lists:any(fun(E) -> contains(E, P) end, L);
contains(_, _) -> false.
collect_local_funs(T) when is_tuple(T) ->
    case T of {'fun', _, {function, N, A}} when is_atom(N), is_integer(A) -> [{N, A}];
              _ -> lists:append([collect_local_funs(E) || E <- tuple_to_list(T)]) end;
collect_local_funs(L) when is_list(L) -> lists:append([collect_local_funs(E) || E <- L]);
collect_local_funs(_) -> [].
