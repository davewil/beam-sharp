#!/usr/bin/env bash
# Probe 62-03: a dependency-free Gleam project actually RUNS B#'s PascalCase exports.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BSC=/home/user/beam-sharp/compiler/_build/default/bin/bsc
EX=/home/user/beam-sharp/compiler/examples
W=$(mktemp -d); mkdir -p $W/lib/shop/ebin
$BSC --src-root $EX -o $W/lib/shop/ebin $EX/Shop >/dev/null 2>&1
cp -r "$HERE/caller" $W/caller
cd $W/caller
echo "--- gleam build (no ERL_LIBS)"; gleam build 2>&1 | tail -5
echo "--- gleam run with ERL_LIBS pointing at the B# ebin"
ERL_LIBS=$W/lib gleam run 2>&1 | tail -12
echo "--- gleam run WITHOUT ERL_LIBS (expected: undef)"
gleam run 2>&1 | tail -6
echo "--- generated erlang for the externals"
find build -name "caller.erl" | head -1 | xargs cat | head -40
rm -rf $W
