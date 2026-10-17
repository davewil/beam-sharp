%% PROTOTYPE for ticket 52 — not repo code. The whole compile-time check a
%% `using :Mod { ... }` could get: is the module reachable on the code path?
%% Called from bs_check:check_dir1/3 with the module's decls. Prints a
%% diagnostic and continues (the policy question — error vs warning — is the
%% ticket's, not this probe's).
-module(bs_probe52).
-export([check/1]).

check(Decls) ->
    T0 = erlang:monotonic_time(nanosecond),
    Missing = [{L, M} || {foreign, L, M, _} <- Decls, code:which(M) =:= non_existing],
    T1 = erlang:monotonic_time(nanosecond),
    [io:format(standard_error,
               "probe52: line ~p: using ~p: module not on the code path~n", [L, M])
     || {L, M} <- Missing],
    io:format(standard_error, "probe52: check of ~p foreign module(s) took ~p ns~n",
              [length([x || {foreign, _, _, _} <- Decls]), T1 - T0]),
    ok.
