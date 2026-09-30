#!/usr/bin/env escript
%% p05: cost of a compile-time presence check = code:which/1 per distinct foreign module.
%% Measures the worst case (module absent: every path entry is searched) and the present case,
%% 30 repeats each, reports median/min/max in microseconds.  Code path size printed.
main(_) ->
    io:format("code path entries: ~p   (OTP ~s)~n", [length(code:get_path()), erlang:system_info(otp_release)]),
    Absent = [list_to_atom("nope_" ++ integer_to_list(I)) || I <- lists:seq(1, 14)],
    Present = [lists, maps, ets, file, binary, string, gen_server, erlang],
    report("14 distinct ABSENT modules (the corpus has 14 distinct foreign modules)", fun() -> [code:which(M) || M <- Absent] end),
    report("8 PRESENT modules", fun() -> [code:which(M) || M <- Present] end),
    report("1 absent module", fun() -> code:which(nope_1) end),
    report("full check incl. .app scan for 8 present modules",
           fun() -> [begin P = code:which(M), case P of
                                 _ when is_list(P) -> filelib:wildcard(filename:join(filename:dirname(P), "*.app"));
                                 _ -> P end end || M <- Present] end).
report(Label, F) ->
    Ts = lists:sort([begin {T, _} = timer:tc(F), T end || _ <- lists:seq(1, 30)]),
    io:format("~-78s median ~6b us  min ~6b  max ~6b~n", [Label, lists:nth(15, Ts), hd(Ts), lists:last(Ts)]).
