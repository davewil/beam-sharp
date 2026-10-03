#!/bin/sh
# usage: bsc-run.sh EBIN args...   (same as scratchpad bsc.sh but with a chosen ebin)
EBIN=$1; shift
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
exec erl -noshell -pa "$EBIN" -eval 'bsc:main(init:get_plain_arguments()), halt().' -extra "$@"
