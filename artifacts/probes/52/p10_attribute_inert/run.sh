#!/bin/sh
# p10: does anything in OTP read a custom `-bs_needs` attribute, vs the .app `applications` key?
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
T=$(mktemp -d); cd $T; mkdir ebin
cat > dm.erl <<'X'
-module(dm).
-export([f/0]).
-bs_needs([crypto]).
f() -> ok.
X
erlc -o ebin dm.erl
cat > ebin/dm.app <<'X'
{application, dm, [{description,"d"},{vsn,"1"},{modules,[dm]},{registered,[]},{applications,[kernel,stdlib]}]}.
X
cat > t.escript <<'X'
#!/usr/bin/env escript
main(_) ->
    code:add_patha("ebin"),
    io:format("1. attribute only (.app lists kernel,stdlib): ensure_all_started(dm) -> ~p~n", [application:ensure_all_started(dm)]),
    io:format("   crypto started? ~p~n", [lists:keymember(crypto, 1, application:which_applications())]),
    application:stop(dm), application:unload(dm),
    %% now the .app lists an absent app instead (what a bsc-emitted .app would do)
    file:write_file("ebin/dm.app", "{application, dm, [{description,\"d\"},{vsn,\"1\"},{modules,[dm]},{registered,[]},{applications,[kernel,stdlib,req]}]}.\n"),
    io:format("2. .app lists absent app req: ensure_all_started(dm) -> ~p~n", [application:ensure_all_started(dm)]),
    io:format("   dm:f() still callable (module loads fine): ~p~n", [dm:f()]).
X
escript t.escript
