#!/usr/bin/env bash
# Call-time cost of the guards, hand-written Erlang with bsc's exact guard shapes. 9 runs each of 20M calls.
set -u; HERE="$(cd "$(dirname "$0")" && pwd)"; W=$(mktemp -d)
erlc -o $W "$HERE/bench.erl" && erl -noshell -pa $W -eval 'bench:main(),halt().'
