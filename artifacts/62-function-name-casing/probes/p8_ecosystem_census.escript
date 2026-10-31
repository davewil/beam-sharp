#!/usr/bin/env escript
%% Probe 8: how common is an uppercase-initial exported function name in the
%% installed OTP 25 + Elixir 1.14 beams?  (precedent / tooling-friction census)
%% Run: escript p8_ecosystem_census.escript
%% Fails (exit 1) if fewer than 1000 modules were read (vacuous census).
main(_) ->
    Beams = filelib:wildcard("/usr/lib/erlang/lib/*/ebin/*.beam") ++ filelib:wildcard("/usr/lib/elixir/lib/*/ebin/*.beam"),
    Res = lists:foldl(fun(F, {Mods, Fns, Up, Ex}) ->
        case beam_lib:chunks(F, [exports]) of
            {ok, {M, [{exports, E}]}} ->
                U = [{M, N, A} || {N, A} <- E, is_uppercase_initial(N)],
                {Mods + 1, Fns + length(E), Up + length(U), Ex ++ U};
            _ -> {Mods, Fns, Up, Ex}
        end end, {0, 0, 0, []}, Beams),
    {Mods, Fns, Up, Ex} = Res,
    io:format("beams read: ~p~nexports total: ~p~nexports with uppercase initial: ~p~n", [Mods, Fns, Up]),
    io:format("modules defining them: ~p~n", [lists:usort([M || {M,_,_} <- Ex])]),
    io:format("first 12: ~p~n", [lists:sublist(Ex, 12)]),
    halt(case Mods >= 1000 of true -> 0; false -> 1 end).
%% Elixir compiles each macro `m` to an export named 'MACRO-m'; those are the compiler's, not authored PascalCase.
is_uppercase_initial(N) -> case atom_to_list(N) of "MACRO-" ++ _ -> false; [C|_] when C >= $A, C =< $Z -> true; _ -> false end.
