#!/bin/bash
# Probe 02 (b): can a forged value reach a private function through an exported one?
# Compile one module with the REAL current bsc (tag test on every record parameter, int kind
# test on exported only) and drive it from a hand-written Erlang caller that skips every bsc
# check. For each path print what happens and where.
cd "$(dirname "$0")"; . ./lib.sh; . ./fixtures.sh
W=$(mktemp -d); write_forge_fixture $W; mkdir -p $W/out
bs_build $W/Forge $W/out || exit 1
echo "=== emitted guards (current bsc) ==="; abstr $W/out/Forge.beam | grep -v "^$"
cp forge_drive.erl $W/drive.erl
erlc -o $W $W/drive.erl && erl -noshell -pa $W/out -pa $W -eval 'drive:main(), halt().'
