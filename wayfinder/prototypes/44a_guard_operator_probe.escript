#!/usr/bin/env escript
%%% Is the `and` / `andalso` short-circuit difference OBSERVABLE in a guard?
%%% Probe for beam-sharp ticket 08 amendment (guard conjunction spelling).
%%% Uses `10 div X` with X=0, which genuinely raises badarith — unlike a term
%%% comparison, which never raises in Erlang because atoms sort after numbers.

main(_) ->
    io:format("OTP ~s~n", [erlang:system_info(otp_release)]),

    io:format("~n=== GUARD context, X = 0 (second operand would raise badarith) ===~n"),
    io:format("  `,`       : ~p~n", [g_comma(0)]),
    io:format("  `and`     : ~p~n", [g_and(0)]),
    io:format("  `andalso` : ~p~n", [g_andalso(0)]),

    io:format("~n=== EXPRESSION context, X = 0 (same two operands) ===~n"),
    io:format("  `and`     : ~p~n", [e_and(0)]),
    io:format("  `andalso` : ~p~n", [e_andalso(0)]),

    io:format("~n=== positive control, X = 2 ===~n"),
    io:format("  guard `,` : ~p   guard `and` : ~p~n", [g_comma(2), g_and(2)]),
    ok.

%% --- guard context: does an raising operand change the OUTCOME? ---
g_comma(X)   when X =/= 0, (10 div X) > 1        -> matched;
g_comma(_)   -> fell_through.

g_and(X)     when (X =/= 0) and ((10 div X) > 1) -> matched;
g_and(_)     -> fell_through.

g_andalso(X) when (X =/= 0) andalso ((10 div X) > 1) -> matched;
g_andalso(_) -> fell_through.

%% --- expression context: the difference should be visible here ---
e_and(X) ->
    try (X =/= 0) and ((10 div X) > 1) of R -> R
    catch C:E -> {raised, C, E} end.

e_andalso(X) ->
    try (X =/= 0) andalso ((10 div X) > 1) of R -> R
    catch C:E -> {raised, C, E} end.
