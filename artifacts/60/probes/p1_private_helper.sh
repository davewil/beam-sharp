#!/usr/bin/env bash
# P1: after F12, is ticket 24 §2's `unclassified` helper (RecomputeTotal/1) reachable by a test?
cd "$(dirname "$0")"; export BSC_EBIN=${BSC_EBIN:-/tmp/bsc-build-60/ebin}
echo '--- aggregate compiles and the sibling file reaches the private helper (Apply(3) = 7)'
./_bsc.sh --src-root fx -o /tmp/p1out fx/Shop/Orders Apply 3; echo "exit=$?"
echo '--- a test module in another directory names RecomputeTotal'
./_bsc.sh --src-root fx -o /tmp/p1out fx/Probe/OrdersTest; echo "exit=$?"
echo '--- --api of the aggregate: what does the boundary manifest show?'
./_bsc.sh --src-root fx --api fx/Shop/Orders; echo "exit=$?"
