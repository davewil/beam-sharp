#!/usr/bin/env escript
%% Probe 7c: the in-repo corpus names modules outside OTP 25's kernel/stdlib: are they on THIS machine's code path?
%% EXPECTED (before run): json -> non_existing (OTP 25 predates it), epgsql -> non_existing (third-party), lists/erlang -> found.
main(_) -> [io:format("~-8w ~p~n", [M, code:which(M)]) || M <- [json, epgsql, lists, erlang]].
