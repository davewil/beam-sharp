#!/bin/sh
# Records which toolchain facts the rest of the probes depend on.
. "$(dirname "$0")/env.sh"
echo "== OTP 28 (bsc side)"; erl -noshell -eval 'io:format("~s~n",[erlang:system_info(otp_release)]),halt().'
echo "== Elixir on OTP 28 PATH (expect boot failure: 1.14 beams from OTP24)"
(cd $W && elixir --version 2>&1 | head -2)
echo "== Elixir on system OTP 25 (used ONLY to BUILD the Elixir fixture)"
(PATH=/usr/bin:/bin elixir --version 2>&1 | tail -1)
echo "== Gleam"; /tmp/tc/gleam --version
echo "== rebar3"; /tmp/tc/rebar3 version 2>&1 | head -1
echo "== Elm"; elm --version
echo "== bsc runs"; $BSC 2>&1 | head -3
