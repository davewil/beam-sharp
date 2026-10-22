#!/usr/bin/env bash
# Records the toolchain this brief was measured on.
erl -noshell -eval 'io:format("OTP ~s erts ~s~n",[erlang:system_info(otp_release),erlang:system_info(version)]),halt().'
elixir --version | tail -1
/tmp/claude-0/gleamx/gleam --version
/tmp/claude-0/elmi/node_modules/.bin/elm --version
rebar3 --version
