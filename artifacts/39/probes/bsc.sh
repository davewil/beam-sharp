#!/usr/bin/env bash
# bsc wrapper: runs the hand-built compiler (see 00-build-bsc.sh)
B=/home/user/beam-sharp/artifacts/39/build
exec erl -noshell -pa $B/ebin -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra "$@"
