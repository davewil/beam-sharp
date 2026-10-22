#!/usr/bin/env bash
# Probe 02: Option A (callee-implicit, by directory name `Internal`) -- same B# programs under
# (1) the unmodified reference compiler (OTP-25 port) and (2) the scratch prototype patch.
HERE=$(cd "$(dirname "$0")" && pwd)
BASE=$("$HERE/../common/build-bsc.sh" /tmp/claude-0/ws60base 2>/dev/null | tail -1)
PROTO=$("$HERE/../common/build-bsc.sh" /tmp/claude-0/ws60a "$HERE/../common/proto-a-internal-dir.patch" 2>/dev/null | tail -1)
cd "$HERE"; OUT=$(mktemp -d)
for who in "$BASE:BASE (unmodified)" "$PROTO:PROTOTYPE A"; do
  BSC=${who%%:*}; echo "################ ${who#*:}"
  for m in Shop/Orders Shop/Orders/Pricing Shop/Orders/Tests Shop/Billing Shop/OrdersExtra Shop/Reports; do
    echo "--- bsc --src-root src src/$m"
    "$BSC" -o "$OUT/x" --src-root src "src/$m" 2>&1; echo "exit=$?"
  done
done
echo "################ namespace-tier import (src-ns): Callers.Via does using-Shop then Orders.Internal.Recompute(5)"
for who in "$BASE:BASE (unmodified)" "$PROTO:PROTOTYPE A"; do
  BSC=${who%%:*}; echo "--- ${who#*:}"
  "$BSC" -o "$OUT/y" --src-root src-ns src-ns/Callers/Via Go 5 2>&1; echo "exit=$?"
done
