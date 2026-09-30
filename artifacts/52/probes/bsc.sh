#!/usr/bin/env bash
# Runs the repo's compiler (built by build-bsc.sh) on OTP 25.  Usage: bsc.sh [bsc args]
B=${BSC_EBIN:-/tmp/bsc52/ebin}
exec erl -noshell -pa "$B" -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra "$@"
