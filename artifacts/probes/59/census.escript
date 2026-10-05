#!/usr/bin/env escript
%% census.escript FILE.abstr...  : per file, count functions and the boundary-test conjuncts in them.
%% A "boundary test" = one conjunct of a clause guard of the exact shapes bsc emits:
%%   map_get('Kind',V) =:= Tag   (tag)      erlang:is_integer(V) / is_integer(V) (int kind)   is_float(V)
%% Counted per CLAUSE conjunct; split by exported / private. Also: private functions with >=1 such test.
main(Files) ->
    Rows = [census(F) || F <- Files],
    [io:format("~s ~s~n", [filename:basename(F), fmt(R)]) || {F, R} <- lists:zip(Files, Rows)],
    Tot = lists:foldl(fun(R, A) -> maps:fold(fun(K, V, B) -> B#{K => maps:get(K, B, 0) + V} end, A, R) end, #{}, Rows),
    io:format("TOTAL ~s~n", [fmt(Tot)]).
fmt(R) -> string:join([io_lib:format("~s=~p", [K, maps:get(K, R, 0)]) || K <- [pub_fns, priv_fns, pub_tag, priv_tag, pub_int, priv_int, pub_flt, priv_flt, priv_fns_tested]], " ").
census(F) ->
    {ok, Forms} = file:consult(F),
    Exports = lists:append([Es || {attribute, _, export, Es} <- Forms]),
    lists:foldl(fun({function, _, N, A, Cs}, R) when N =/= bs@type_atoms ->
                        Pub = lists:member({N, A}, Exports),
                        T = lists:sum([count(tag, C) || C <- Cs]), I = lists:sum([count(int, C) || C <- Cs]),
                        Fl = lists:sum([count(flt, C) || C <- Cs]),
                        P = case Pub of true -> pub; false -> priv end,
                        R1 = add(list_to_atom(atom_to_list(P) ++ "_fns"), 1, R),
                        R2 = add(list_to_atom(atom_to_list(P) ++ "_tag"), T, R1),
                        R3 = add(list_to_atom(atom_to_list(P) ++ "_int"), I, R2),
                        R4 = add(list_to_atom(atom_to_list(P) ++ "_flt"), Fl, R3),
                        case not Pub andalso (T + I + Fl) > 0 of true -> add(priv_fns_tested, 1, R4); false -> R4 end;
                   (_, R) -> R end, #{}, Forms).
add(K, V, R) -> R#{K => maps:get(K, R, 0) + V}.
count(Kind, {clause, _, _, Gs, _}) -> lists:sum([conj(Kind, E) || G <- Gs, E <- G]).
conj(tag, {op, _, '=:=', {call, _, {remote, _, {atom, _, erlang}, {atom, _, map_get}}, [{atom, _, 'Kind'}, _]}, _}) -> 1;
conj(int, {call, _, {atom, _, is_integer}, _}) -> 1;
conj(int, {call, _, {remote, _, {atom, _, erlang}, {atom, _, is_integer}}, _}) -> 1;
conj(flt, {call, _, {atom, _, is_float}, _}) -> 1;
conj(flt, {call, _, {remote, _, {atom, _, erlang}, {atom, _, is_float}}, _}) -> 1;
conj(_, _) -> 0.
