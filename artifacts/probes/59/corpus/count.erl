-module(count).
-export([main/0]).
%% Probe 59i: over the compiling example corpus (emitted abstract code), per module:
%%  priv_tag  = private functions carrying a record tag test (base emitter)
%%  priv_tag_calls = local call sites (direct or `fun f/N`) targeting those
%%  B_added   = guard tests the "kind/range/float on private" widening ADDS (is_integer|is_float occurrences, B minus base)
main() ->
    Ms = lists:sort([filename:basename(F, ".beam") || F <- filelib:wildcard("base/*.beam")]),
    io:format("~-22s ~5s ~5s ~8s ~14s ~9s ~10s~n", [module, pub, priv, priv_tag, priv_tag_calls, "B_added", "B_calls"]),
    Rows = [row(M) || M <- Ms],
    T = fun(I) -> lists:sum([element(I, R) || R <- Rows]) end,
    io:format("~-22s ~5w ~5w ~8w ~14w ~9w ~10w~n", [total, T(1), T(2), T(3), T(4), T(5), T(6)]),
    halt().
forms(Dir, M) ->
    {ok, {_, [{abstract_code, {_, AC}}]}} = beam_lib:chunks(Dir ++ "/" ++ M ++ ".beam", [abstract_code]), AC.
row(M) ->
    AC = forms("base", M), ACB = forms("B", M),
    Ex = lists:append([E || {attribute, _, export, E} <- AC]),
    Fs = [{N, A, C} || {function, _, N, A, C} <- AC, hd(atom_to_list(N)) =/= $b],  % skip bs@ helpers
    Pub = [F || {N, A, _} = F <- Fs, lists:member({N, A}, Ex)],
    Priv = Fs -- Pub,
    Tagged = [{N, A} || {N, A, C} <- Priv, has_tag(C)],
    Calls = calls_to(Tagged, AC),
    Added = tests(ACB) - tests(AC),
    %% private functions that gain a kind test under B and how many local call sites reach them
    GainedPriv = [{N, A} || {N, A, C} <- [F || {function, _, N0, A0, C0} <- ACB, F <- [{N0, A0, C0}], not lists:member({N0, A0}, Ex), hd(atom_to_list(N0)) =/= $b],
                            kind_count(C) > kind_count(proplists:get_value({N, A}, [{{N1, A1}, C1} || {function, _, N1, A1, C1} <- AC], []))],
    BCalls = calls_to(GainedPriv, AC),
    io:format("~-22s ~5w ~5w ~8w ~14w ~9w ~10w~n", [M, length(Pub), length(Priv), length(Tagged), Calls, Added, BCalls]),
    {length(Pub), length(Priv), length(Tagged), Calls, Added, BCalls}.
has_tag(Clauses) -> lists:any(fun({clause, _, _, Gs, _}) -> contains_kind_tag(Gs) end, Clauses).
contains_kind_tag({call, _, {atom, _, map_get}, [{atom, _, 'Kind'} | _]}) -> true;
contains_kind_tag(T) when is_tuple(T) -> lists:any(fun contains_kind_tag/1, tuple_to_list(T));
contains_kind_tag(L) when is_list(L) -> lists:any(fun contains_kind_tag/1, L);
contains_kind_tag(_) -> false.
kind_count([]) -> 0;
kind_count(Clauses) -> count_calls(Clauses, [is_integer, is_float]).
tests(AC) -> count_calls(AC, [is_integer, is_float]).
count_calls({call, _, {atom, _, F}, _} = T, Names) ->
    (case lists:member(F, Names) of true -> 1; false -> 0 end) + lists:sum([count_calls(E, Names) || E <- tuple_to_list(T), is_tuple(E) orelse is_list(E)]);
count_calls({call, _, {remote, _, {atom, _, erlang}, {atom, _, F}}, _} = T, Names) ->
    (case lists:member(F, Names) of true -> 1; false -> 0 end) + lists:sum([count_calls(E, Names) || E <- tuple_to_list(T), is_tuple(E) orelse is_list(E)]);
count_calls(T, Names) when is_tuple(T) -> lists:sum([count_calls(E, Names) || E <- tuple_to_list(T), is_tuple(E) orelse is_list(E)]);
count_calls(L, Names) when is_list(L) -> lists:sum([count_calls(E, Names) || E <- L, is_tuple(E) orelse is_list(E)]);
count_calls(_, _) -> 0.
%% call sites inside function BODIES (clause bodies only, guards excluded) naming one of Targets
calls_to(Targets, AC) ->
    lists:sum([site_count(Body, Targets) || {function, _, _, _, Cs} <- AC, {clause, _, _, _, Body} <- Cs]).
site_count({call, _, {atom, _, F}, Args} = _T, Ts) ->
    (case lists:any(fun({N, A}) -> N =:= F andalso A =:= length(Args) end, Ts) of true -> 1; false -> 0 end) + site_count(Args, Ts);
site_count({'fun', _, {function, F, A}}, Ts) -> case lists:member({F, A}, Ts) of true -> 1; false -> 0 end;
site_count(T, Ts) when is_tuple(T) -> lists:sum([site_count(E, Ts) || E <- tuple_to_list(T), is_tuple(E) orelse is_list(E)]);
site_count(L, Ts) when is_list(L) -> lists:sum([site_count(E, Ts) || E <- L, is_tuple(E) orelse is_list(E)]);
site_count(_, _) -> 0.
