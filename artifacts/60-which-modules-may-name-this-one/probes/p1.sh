#!/usr/bin/env bash
# P1: what the checker enforces today. Control: a private helper is refused; a public helper is open to everyone.
BSC=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/bsc
cd "$(dirname "$0")/p1"
echo "## Reports (a sibling subtree) calls public RecomputeTax -> expect compiles"
$BSC --src-root src src/Shop/Reports Gross "[10,20]"; echo "exit=$?"
echo "## OrdersTest (the 'test boundary' consumer) calls public RecomputeTax -> compiles today: nothing says no"
$BSC --src-root src src/Shop/OrdersTest Probe 50; echo "exit=$?"
echo "## OrdersTest2 calls the private RecomputeTotal -> CONTROL: must be refused"
$BSC --src-root src src/Shop/OrdersTest2 Probe2 "[1,2]"; echo "exit=$?"
echo "## --api of Shop.Orders (what 24 s2 says classifies the boundary)"
$BSC --src-root src --api src/Shop/Orders; echo "exit=$?"
