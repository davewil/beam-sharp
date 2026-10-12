#!/usr/bin/env bash
# Probe 62-01: every Elixir call spelling, parse level (AST) and run level.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BSC=/home/user/beam-sharp/compiler/_build/default/bin/bsc
EX=/home/user/beam-sharp/compiler/examples
W=$(mktemp -d); mkdir -p $W/ebin
$BSC --src-root $EX -o $W/ebin $EX/Shop >/dev/null 2>&1
BS_EBIN=$W/ebin elixir "$HERE/p.exs" 2>&1
rm -rf $W
