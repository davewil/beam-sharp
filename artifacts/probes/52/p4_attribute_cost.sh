#!/usr/bin/env bash
# P4: bytes a -bs_requires attribute adds to a real emitted module, and does it survive?
set -u; . "$(dirname "$0")/common.sh"
REPO=$(cd "$HERE/../../.." && pwd)
cp -r $REPO/compiler/examples/Interop $WORK/Interop
(cd $WORK && $BSC Interop >/dev/null 2>&1; ls Interop.abstr Interop.beam)
echo "control: bsc's own Interop.beam = $(stat -c %s $WORK/Interop.beam) bytes"
escript "$HERE/attr_cost.escript" $WORK/Interop.abstr
