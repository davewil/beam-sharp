#!/bin/sh
# p08/erlang: what does an .erl SOURCE say about the apps it needs, and what does erlc check?
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
cd "$(dirname "$0")"; T=$(mktemp -d)
L=/tmp/otp/lib/erlang/lib
echo "## 1. OTP's own ssl: apps its .app declares vs how many times ssl_cipher.erl mentions crypto"
grep -n "applications" $L/ssl-11.7.7/ebin/ssl.app
echo "ssl_cipher.erl calls to crypto: $(grep -c 'crypto:' $L/ssl-11.7.7/src/ssl_cipher.erl); lines naming an application (-include_lib/-application): "
grep -n "^-include_lib\|^-application" $L/ssl-11.7.7/src/ssl_cipher.erl
echo "## 2. erlc on a call into a module that exists nowhere (a.erl)"
erlc -o $T a.erl; echo "erlc rc=$?"
echo "## 3. erlc on -include_lib naming an absent application (b.erl)"
erlc -o $T b.erl; echo "erlc rc=$?"
echo "## 4. erlc on -include_lib naming a present one, then absent from path (c.erl)"
erlc -o $T c.erl; echo "erlc rc=$? (public_key on default path)"
echo "## 5. runtime: start ssl with its declared dependency 'crypto' removed from the code path"
cat > $T/s.escript <<'X'
#!/usr/bin/env escript
main(_) ->
    [code:del_path(P) || P <- code:get_path(), string:find(P, "/crypto-") =/= nomatch],
    io:format("ensure_all_started(ssl) -> ~p~n", [application:ensure_all_started(ssl)]).
X
escript $T/s.escript
