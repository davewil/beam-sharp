#!/usr/bin/env escript
%% PROBE 62l — does anything shipped with OTP 28.5 export a function whose name Elixir cannot write unquoted?
%% Reads every .beam under the installed OTP lib/ (the export table via beam_lib, no loading) and counts exported names
%% that are not valid unquoted Elixir call names (start uppercase, or contain chars outside [a-z0-9_] / ? / !).
%% Usage: escript 62l_otp_uppercase_exports.escript <OTP_ROOT>
main([Root]) ->
    Beams = filelib:wildcard(filename:join([Root, "lib", "erlang", "lib", "*", "ebin", "*.beam"])),
    {Total, Odd} = lists:foldl(fun(B, {T, O}) ->
        case beam_lib:chunks(B, [exports]) of
            {ok, {M, [{exports, Ex}]}} ->
                Bad = [{M, F, A} || {F, A} <- Ex, not elixir_ok(atom_to_list(F))],
                {T + length(Ex), Bad ++ O};
            _ -> {T, O}
        end end, {0, []}, Beams),
    Upper = [X || {_, F, _} = X <- Odd, hd(atom_to_list(F)) >= $A, hd(atom_to_list(F)) =< $Z],
    io:format("beams: ~w  exports: ~w~n", [length(Beams), Total]),
    io:format("exports not writable unquoted in Elixir: ~w~n", [length(Odd)]),
    io:format("  of which start with an uppercase letter (the B# case): ~w~n", [length(Upper)]),
    io:format("  first 12 uppercase-initial: ~p~n", [lists:sublist(lists:sort(Upper), 12)]),
    io:format("  modules containing them: ~p~n", [lists:usort([M || {M, _, _} <- Upper])]),
    %% CONTROL: the classifier must flag the B# shapes and pass ordinary names.
    [io:format("  control ~-10s -> ~w~n", [N, elixir_ok(N)]) || N <- ["New", "get_id", "valid?", "fetch!", "GetId", "PKCS-1"]].

elixir_ok(S) -> re:run(S, "^[a-z_][a-zA-Z0-9_]*[?!]?$", [{capture, none}]) =:= match.
