%% Same census as names.erl, restricted to the modules a beam-sharp author
%% would plausibly declare foreign: stdlib + kernel (ticket 18's census scope).
-module(names2).
-export([main/0]).

main() ->
    Mods = lists:sort(app_mods(stdlib) ++ app_mods(kernel)),
    Exports = [{M, F, A} || M <- Mods,
                            {F, A} <- exports(M),
                            F =/= module_info],
    Names = lists:usort([atom_to_list(F) || {_, F, _} <- Exports]),
    Bad = [N || N <- Names, not is_plain(N)],
    NonRT = [N || N <- Names, is_plain(N), rt(N) =/= N],
    MBad = [M || M <- Mods, not is_plain(atom_to_list(M))],
    MNonRT = [M || M <- Mods, is_plain(atom_to_list(M)),
                   rt(atom_to_list(M)) =/= atom_to_list(M)],
    io:format("stdlib+kernel modules:      ~p~n", [length(Mods)]),
    io:format("exported functions:         ~p~n", [length(Exports)]),
    io:format("distinct function names:    ~p~n", [length(Names)]),
    io:format("names NOT [a-z][a-z0-9_]*:  ~p  ~p~n", [length(Bad), Bad]),
    io:format("plain names failing round-trip: ~p  ~p~n", [length(NonRT), NonRT]),
    io:format("module names NOT plain:     ~p  ~p~n", [length(MBad), MBad]),
    io:format("module names failing round-trip: ~p  ~p~n", [length(MNonRT), MNonRT]),
    ByName = maps:groups_from_list(fun({M, F, _}) -> {M, F} end,
                                   fun({_, _, A}) -> A end, Exports),
    Multi = [{K, lists:sort(V)} || {K, V} <- maps:to_list(ByName), length(V) > 1],
    io:format("name/arity fan-out: ~p of ~p pairs carry >1 arity (~.1f%)~n",
              [length(Multi), maps:size(ByName),
               100 * length(Multi) / maps:size(ByName)]),
    Widest = lists:sublist(lists:reverse(lists:keysort(2,
        [{K, length(V)} || {K, V} <- Multi])), 6),
    io:format("  widest: ~p~n", [Widest]),
    %% Non-contiguous arity sets: a "default arguments" reading is wrong for these
    Gappy = [{K, V} || {K, V} <- Multi, lists:last(V) - hd(V) + 1 =/= length(V)],
    io:format("  arity sets with GAPS (not expressible as defaults): ~p of ~p~n",
              [length(Gappy), length(Multi)]),
    io:format("  e.g. ~p~n", [lists:sublist(Gappy, 6)]),
    ok.

app_mods(App) ->
    _ = application:load(App),
    case application:get_key(App, modules) of
        {ok, Ms} -> Ms;
        _ -> []
    end.

exports(M) ->
    try M:module_info(exports) catch _:_ -> [] end.

is_plain([C | Rest]) when C >= $a, C =< $z ->
    lists:all(fun(X) -> (X >= $a andalso X =< $z)
                        orelse (X >= $0 andalso X =< $9)
                        orelse X =:= $_ end, Rest);
is_plain(_) -> false.

rt(S) -> pascal_to_snake(snake_to_pascal(S)).

snake_to_pascal(S) -> lists:concat([cap(P) || P <- string:split(S, "_", all)]).
cap([]) -> [];
cap([C | R]) -> [string:to_upper(C) | R].

pascal_to_snake(S) ->
    Expanded = lists:flatten([case C >= $A andalso C =< $Z of
                                  true -> [$_, string:to_lower(C)];
                                  false -> [C]
                              end || C <- S]),
    case Expanded of
        [$_ | Rest] -> Rest;
        Other -> Other
    end.
