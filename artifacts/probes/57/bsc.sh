#!/bin/sh
# bsc.sh EBIN ARGS...  -- run the hand-built bsc from EBIN
ebin=$1; shift
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
mkdir -p /tmp/p57cwd && cd /tmp/p57cwd  # bsc writes .abstr/.beam into the cwd
exec erl -noshell -pa "$ebin" -eval 'bsc:main(init:get_plain_arguments()), halt().' -extra "$@"
