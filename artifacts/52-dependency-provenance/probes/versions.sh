#!/bin/sh
echo "erlang OTP release: $(erl -noshell -eval 'io:format("~s ~s",[erlang:system_info(otp_release), erlang:system_info(version)]),halt().')"
elixir --version | tail -1
echo "elm: $(elm --version)"
echo "gleam: not installed (install denied by sandbox); not probed"
echo "bsc: NOT runnable here (needs OTP 28 leex TokenLoc); no bsc probe exists"
echo "mix: $(mix --version | tail -1)"
uname -sr
