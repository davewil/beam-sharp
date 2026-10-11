#!/usr/bin/env bash
# Thin runner for the reference compiler that forwards --flags intact.
# (The scratchpad `bsc` wrapper uses `erl -run`, which lets erl swallow a leading --src-root.)
S=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad
source "$S/env.sh"
EBIN="${BSC_EBIN:-$S/bsc-ebin}"
exec erl -noshell -pa "$EBIN" -eval 'bsc:main(init:get_plain_arguments())' -extra "$@"
