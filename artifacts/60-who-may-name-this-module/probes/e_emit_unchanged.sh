#!/usr/bin/env bash
# Probe (e): does the friend rule change what is EMITTED? (ticket 18 sec.5: enforcement can only be on the caller side.)
# .beam bytes are not reproducible between two identical compiles (control below), so compare the .abstr dump.
PROTO=${PROTO:-/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/60/proto}
HERE=$(cd "$(dirname "$0")" && pwd); W=$(mktemp -d); cp -r "$HERE/proj_e" $W/p; cd $W/p
mkdir $W/a $W/b $W/c
BSC_EBIN=$PROTO/ebin_A $HERE/bsc2 -o $W/a --src-root . Shop/Reports
mv Shop/Orders/Friends.bs $W/Friends.bs.hold
BSC_EBIN=$PROTO/ebin_base $HERE/bsc2 -o $W/b --src-root . Shop/Reports
BSC_EBIN=$PROTO/ebin_base $HERE/bsc2 -o $W/c --src-root . Shop/Reports
echo "--- CONTROL: two compiles of the same source, .beam md5 (expected to DIFFER if beams are not reproducible)"; md5sum $W/b/*.beam $W/c/*.beam | sed "s|$W/||"
echo "--- .abstr md5: A with the friend file (a/) vs unmodified compiler without it (b/, c/)"; md5sum $W/a/*.abstr $W/b/*.abstr $W/c/*.abstr | sed "s|$W/||"
echo "--- Shop.Orders.abstr differs a/ vs b/ only by the extra source file's file attribute:"
diff <(tr ',' '\n' < $W/a/Shop.Orders.abstr) <(tr ',' '\n' < $W/b/Shop.Orders.abstr) | head -8
rm -rf $W
