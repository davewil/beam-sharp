#!/usr/bin/env escript
%% usage: p3_census.escript <otp-lib-dir> <elixir-lib-dir>
%% For every application in both trees, read its .app `modules` list and ask: is the app name DERIVABLE from a module name?
main([OtpLib, ExLib]) ->
    Apps = apps(OtpLib) ++ apps(ExLib),
    %% OTP-style: module atom whose name equals the app, or app-name prefix
    Otp = [{A, M} || {A, Ms, lib_otp} <- Apps, M <- Ms],
    OtpEq = [1 || {A, M} <- Otp, atom_to_list(A) =:= atom_to_list(M)],
    OtpPre = [1 || {A, M} <- Otp, lists:prefix(atom_to_list(A) ++ "_", atom_to_list(M)) orelse A =:= M],
    io:format("OTP: ~p modules in ~p apps~n", [length(Otp), length([x || {_, _, lib_otp} <- Apps])]),
    io:format("  module name == app name: ~p (~.1f%)~n", [length(OtpEq), 100*length(OtpEq)/length(Otp)]),
    io:format("  module name == app or app_ prefix: ~p (~.1f%)~n", [length(OtpPre), 100*length(OtpPre)/length(Otp)]),
    Ex = [{A, M} || {A, Ms, lib_ex} <- Apps, M <- Ms, lists:prefix("Elixir.", atom_to_list(M))],
    Guess = fun(M) -> "Elixir." ++ Rest = atom_to_list(M),
                      Seg = hd(string:split(Rest, ".")), list_to_atom(underscore(Seg)) end,
    Guess2 = fun(M) -> "Elixir." ++ Rest = atom_to_list(M), list_to_atom(string:lowercase(hd(string:split(Rest, ".")))) end,
    Ok = fun(A, M) -> Guess(M) =:= A orelse Guess2(M) =:= A end,
    Hits = [{A, M} || {A, M} <- Ex, Ok(A, M)],
    Miss = [{A, M, Guess(M)} || {A, M} <- Ex, not Ok(A, M)],
    io:format("Elixir.*: ~p modules in ~p apps; first segment, snake_case OR lowercased, == app: ~p (~.1f%)~n",
              [length(Ex), length(lists:usort([A || {A,_} <- Ex])), length(Hits), 100*length(Hits)/length(Ex)]),
    ByApp = lists:foldl(fun({A,_,_}, Acc) -> maps:update_with(A, fun(N) -> N+1 end, 1, Acc) end, #{}, Miss),
    io:format("  misses by app: ~p~n", [lists:sort(maps:to_list(ByApp))]),
    io:format("  sample misses: ~p~n", [lists:sublist([{M, wrongly, G} || {_, M, G} <- Miss], 6)]),
    %% names that cannot even be spelled as a B# identifier-free atom guess
    Odd = [A || {A, _, _} <- Apps, not is_plain(A)],
    io:format("apps whose name is not [a-z_]+: ~p~n", [Odd]).

underscore(S) -> lists:flatten(un(S, true)).
un([], _) -> [];
un([C|T], First) when C >= $A, C =< $Z ->
    Pre = case First of true -> []; false -> case T of [N|_] when N >= $a -> "_"; _ -> [] end end,
    [Pre, C + 32 | un(T, false)];
un([C|T], _) -> [C | un(T, false)].
is_plain(A) -> lists:all(fun(C) -> (C >= $a andalso C =< $z) orelse C =:= $_ end, atom_to_list(A)).

apps(Lib) ->
    Kind = case string:find(Lib, "elixir/lib") of nomatch -> lib_otp; _ -> lib_ex end,
    lists:append([case filelib:wildcard(filename:join([D, "ebin", "*.app"])) of
          [F] -> {ok, [{application, A, Props}]} = file:consult(F),
                 [{A, proplists:get_value(modules, Props, []), Kind}];
          _ -> [] end || D <- filelib:wildcard(filename:join(Lib, "*"))]).
