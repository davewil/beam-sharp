#!/usr/bin/env bash
# Runs the repo's bsc from a scratch build (no rebar3 installed; see brief).
# usage: _bsc.sh [bsc args...]   BSC_EBIN overrides the build dir.
EBIN=${BSC_EBIN:-/tmp/claude-0/-home-user-beam-sharp/2e35dc52-b5e4-5ac3-801c-9c12d8324568/scratchpad/ebin}
exec erl -noshell -pa "$EBIN" -eval 'bsc:main(init:get_plain_arguments())' -extra "$@"
