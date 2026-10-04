#!/bin/sh
# How Erlang/OTP declares provenance: the .app `applications` key (read by the application
# controller at START), rebar.config deps (build), xref (post-compile, optional). Sources cited are
# the real OTP 28 files installed in /opt/otp28.
. "$(dirname "$0")/env.sh"
O=/opt/otp28/lib/erlang/lib
echo "== OTP's own .app files: the dependency list is the 'applications' key"
grep -n "applications" $O/kernel-10.3/ebin/kernel.app $O/sasl-4.3/ebin/sasl.app $O/crypto-5.6/ebin/crypto.app $O/inets-9.4/ebin/inets.app
echo "== xref's documented default library path (tools-4.1.2/src/xref.erl:1160): a dependency is invisible unless asked for"
sed -n 1158,1161p $O/tools-4.1.2/src/xref.erl
rm -rf $W/rcons && cp -r $FIX/rcons $W/rcons && cd $W/rcons
echo "== fixture rcons: calls crypto without listing it; lists a nonexistent app; calls an Elixir module"
cat -n src/rcons.app.src | sed -n 6,8p
echo "== rebar3 compile: does it object to the undeclared crypto use or the nonexistent listed app?"
/tmp/tc/rebar3 compile 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | tail -4; echo "exit=$?"
echo "== rebar3 xref (post-compile): which of the three problems does it find?"
/tmp/tc/rebar3 xref 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | tail -6
echo "== run time: the application controller refuses to start an app whose listed dependency is absent"
erl -noshell -pa _build/default/lib/rcons/ebin -eval '
io:format("  ensure_all_started(rcons) = ~p~n", [application:ensure_all_started(rcons)]),
io:format("  rcons:h(<<1>>) works anyway (crypto was never listed): ~p~n", [catch byte_size(rcons:h(<<1>>))]),
halt().' 2>&1 | head -9
