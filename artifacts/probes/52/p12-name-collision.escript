#!/usr/bin/env escript
%% P12: how often is an application's name also a module's name? (matters only for a brace-less `using :app` spelling)
%% Positive set: OTP apps (installed OTP 25). Control: Elixir apps, whose modules are spelled 'Elixir.X' and so cannot collide.
main(_) ->
    Otp = [filename:basename(D) || D <- filelib:wildcard("/usr/lib/erlang/lib/*")],
    OtpApps = [{list_to_atom(hd(string:split(B, "-"))), D} || {B, D} <- lists:zip(Otp, filelib:wildcard("/usr/lib/erlang/lib/*"))],
    Ex = [{list_to_atom(filename:basename(D)), D} || D <- filelib:wildcard("/usr/lib/elixir/lib/*")],
    report("OTP 25", OtpApps), report("Elixir 1.14", Ex).
report(L, Apps) ->
    Same = [A || {A, D} <- Apps, filelib:is_file(filename:join([D, "ebin", atom_to_list(A) ++ ".beam"]))],
    io:format("~s: ~p apps, ~p have a module with the app's own name: ~w~n", [L, length(Apps), length(Same), lists:sort(Same)]).
