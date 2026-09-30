#!/usr/bin/env bash
# run the locally built bsc: bsc.sh ARGS...  (build first with build_bsc.sh)
exec erl +pc unicode -noshell -pa ${B:-/tmp/bsc57}/ebin -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra "$@"
