#!/bin/bash
# How ticket 24's `unclassified` (RecomputeTotal) looks under F12 as built (HEAD), and under the prototype.
export PATH=/opt/otp28/bin:$PATH
HERE=$(cd "$(dirname "$0")" && pwd)
BASE=/tmp/c60/_build/default/bin/bsc; PROTO=/tmp/c60a/_build/default/bin/bsc
rm -rf /tmp/t24 && cp -r "$HERE/tree24" /tmp/t24 && cd /tmp/t24
echo "## 1. HEAD: what the compiler publishes for Shop.Orders (bsc --api)"
$BASE --api --src-root . Shop/Orders 2>&1 | head -12
echo
echo "## 2. HEAD: the test module calls Discount/1 (same-module helper, private by default) -> refused by F12 alone"
$BASE -o /tmp/o60r --src-root . Shop/OrdersTests T2 2>&1 | head -6; echo "exit=${PIPESTATUS[0]}"
echo
echo "## 3. HEAD: delete T2; the test module calls Totals.Recompute (public because Shop.Orders needs it) -> compiles and runs"
python3 - <<'PY'
p='Shop/OrdersTests/OrdersTests.bs'; s=open(p).read(); s=s[:s.index('public int T2')]; open(p,'w').write(s)
PY
$BASE -o /tmp/o60s --src-root . Shop/OrdersTests T1 2>&1 | head -4; echo "exit=${PIPESTATUS[0]}"
echo
echo "## 4. PROTOTYPE: Totals says  within Shop.Orders ; the test module (Shop.OrdersTests) is a SIBLING"
sed -i 's/^module Shop.Orders.Totals$/module Shop.Orders.Totals\nwithin Shop.Orders/' Shop/Orders/Totals/Totals.bs
$PROTO -o /tmp/o60t --src-root . Shop/OrdersTests T1 2>&1 | head -6; echo "exit=${PIPESTATUS[0]}"
echo
echo "## 5. PROTOTYPE: ... and the same test moved INSIDE the subtree as Shop.Orders.Tests (deliberate placement) compiles"
mkdir -p Shop/Orders/Tests && sed 's/Shop.OrdersTests/Shop.Orders.Tests/' Shop/OrdersTests/OrdersTests.bs > Shop/Orders/Tests/Tests.bs
$PROTO -o /tmp/o60u --src-root . Shop/Orders/Tests T1 2>&1 | head -4; echo "exit=${PIPESTATUS[0]}"
echo
echo "## 6. PROTOTYPE: what --api publishes now (does the manifest know Totals is restricted?)"
$PROTO --api --src-root . Shop/Orders/Totals 2>&1 | head -6
echo
echo "## 7. PROTOTYPE: the agent's way round it from the sibling test is to edit the CALLEE (delete the within line) -- a diff in another module's file"
sed -i '/^within /d' Shop/Orders/Totals/Totals.bs
$PROTO -o /tmp/o60aj --src-root . Shop/OrdersTests T1 2>&1 | head -3; echo "exit=${PIPESTATUS[0]}"
