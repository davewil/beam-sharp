#!/usr/bin/env bash
# usage: bsc.sh [EBIN=dir via env] args...  -- runs bsc with args that may start with '-'
EBIN=${BSC_EBIN:-/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/bsc-ebin}
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
exec erl -noshell -pa "$EBIN" -eval 'erlang:halt(bsc:status(init:get_plain_arguments(), standalone))' -extra "$@"
