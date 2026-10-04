#!/bin/bash
# Option B prototype (/tmp/c60b, built from HEAD sources + patch 08_caller_declares.patch):
# the CALLER says what it may depend on:  `allow Shop.Orders`  (a closed list of subtrees its `using` lines may name).
export PATH=/opt/otp28/bin:$PATH
HERE=$(cd "$(dirname "$0")" && pwd)
B=/tmp/c60b/_build/default/bin/bsc
rm -rf /tmp/t24b && cp -r "$HERE/tree24" /tmp/t24b && cd /tmp/t24b
python3 - <<'PY'
p='Shop/OrdersTests/OrdersTests.bs'; s=open(p).read(); s=s[:s.index('public int T2')]; open(p,'w').write(s)
PY
echo "## 1. the test module as an agent writes it (no allow line): names Totals freely -- the callee is unprotected"
$B -o /tmp/o60v --src-root . Shop/OrdersTests T1; echo "exit=$?"
echo "## 2. the same module after its AUTHOR adds the line  allow Shop.Orders  (Shop.Orders.Totals is under it, so still fine)"
sed -i 's/^module Shop.OrdersTests$/module Shop.OrdersTests\nallow Shop.Orders/' Shop/OrdersTests/OrdersTests.bs
$B -o /tmp/o60w --src-root . Shop/OrdersTests T1; echo "exit=$?"
echo "## 3. author narrows it to the client API only: allow list names a module that is not Totals"
sed -i 's/^allow Shop.Orders$/allow Shop.Orders.Api/' Shop/OrdersTests/OrdersTests.bs
$B -o /tmp/o60x --src-root . Shop/OrdersTests T1; echo "exit=$?"
echo "## 4. the agent deletes the allow line to make the test compile:"
sed -i '/^allow /d' Shop/OrdersTests/OrdersTests.bs
$B -o /tmp/o60y --src-root . Shop/OrdersTests T1; echo "exit=$?"
