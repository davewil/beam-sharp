#!/usr/bin/env bash
# P4: F15 says a directory holding .bs files IS a module, so Shop/Orders/Internal/ is its own
# module 'Shop.Orders.Internal' beside 'Shop.Orders'. Is anything stopping a sibling subtree
# (Shop.Reports) from naming it today?
cd "$(dirname "$0")"; export BSC_EBIN=${BSC_EBIN:-/tmp/bsc-build-60/ebin}
rm -rf /tmp/p4out; mkdir -p /tmp/p4out
echo '--- Shop.Orders (owner; has a nested Internal/ module) Gross(100)'
./_bsc.sh --src-root fx -o /tmp/p4out fx/Shop/Orders Gross 100; echo "exit=$?"
ls /tmp/p4out
echo '--- Shop.Reports (a sibling subtree) names Shop.Orders.Internal: Peek(100)'
./_bsc.sh --src-root fx -o /tmp/p4out fx/Shop/Reports Peek 100; echo "exit=$?"
