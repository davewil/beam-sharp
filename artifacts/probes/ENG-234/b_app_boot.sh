#!/usr/bin/env bash
# (b) What an .app records, and when an absent listed application is noticed.
set -u; D=$(mktemp -d); cd "$D"; mkdir -p ebin
cat > ebin/me.app <<'X'
{application, me, [{description,"x"},{vsn,"1"},{modules,[]},{applications,[kernel,stdlib,req_absent]}]}.
X
echo "## compile time: erlc reads no .app; nothing to run. Boot time:"
erl -noshell -pa ebin -eval 'io:format("~p~n",[application:ensure_all_started(me)]), halt().'
echo "## app listed but ERL_LIBS has it -> ok? (fake req_absent app)"
mkdir -p libs/req_absent/ebin
echo '{application, req_absent, [{description,"y"},{vsn,"0.0.1"},{modules,[]},{applications,[kernel,stdlib]}]}.' > libs/req_absent/ebin/req_absent.app
ERL_LIBS=$PWD/libs erl -noshell -pa ebin -eval 'io:format("~p~n",[application:ensure_all_started(me)]), halt().'
