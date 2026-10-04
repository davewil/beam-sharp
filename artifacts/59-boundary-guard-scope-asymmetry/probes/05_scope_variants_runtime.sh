#!/bin/bash
# Probe 05 (b, e): the SAME forged calls as probe 02, against the three compiler variants.
# Shows, per guard scope, where each forgery crashes (or that it does not).
#   base   = current: tag test everywhere, int kind test exported-only
#   narrow = tag test exported-only too           (the "it is a defect" reading)
#   wide   = int kind/range/float tests on private too (the "unconditional" reading; tag stays)
#   proj   = narrow + 46 s4 projection tests at the exported entry (option C, prototype)
cd "$(dirname "$0")"; . ./lib.sh; . ./fixtures.sh
W=$(mktemp -d); write_forge_fixture $W; cp forge_drive.erl $W/drive.erl; erlc -o $W $W/drive.erl
for v in base narrow wide proj; do
  mkdir -p $W/out-$v
  /tmp/p59/bin/bsc-$v -o $W/out-$v $W/Forge || exit 1
  echo "################################ variant: $v"
  echo "--- private functions as emitted:"; abstr $W/out-$v/Forge.beam | grep -A2 "^'Inner'\|^'Scale'\|^'Big'(N\|^'SumAll'(\[\], " | grep -v "^--$" | head -14
  echo "--- forged calls:"
  erl -noshell -pa $W/out-$v -pa $W -eval 'drive:main(), halt().' | sed -n '/path 2/,/path 5/p' | grep -v "^---"
done
