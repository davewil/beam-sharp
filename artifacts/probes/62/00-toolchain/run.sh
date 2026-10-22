#!/usr/bin/env bash
# Records toolchain versions and proves the scratch bsc builds and compiles Shop under OTP 25.
. "$(dirname "$0")/../lib.sh"
erl -noshell -eval 'io:format("OTP ~s (erts ~s)~n",[erlang:system_info(otp_release),erlang:system_info(version)]),halt().'
elixir --version | tail -1
/tmp/claude-0/gleamx/gleam --version
/tmp/claude-0/elmi/node_modules/.bin/elm --version
BSC=$(build_bsc plain) || exit 1
echo "bsc built: $BSC"
compile_shop "$BSC" "$SCRATCH/shop-ebin"; ls "$SCRATCH/shop-ebin"/*.beam
erl -noshell -pa "$SCRATCH/shop-ebin" -eval "io:format(\"exports: ~p~n\",['Shop':module_info(exports)]),halt()."
