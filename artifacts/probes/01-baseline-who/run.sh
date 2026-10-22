#!/usr/bin/env bash
# Probe 01: what the reference compiler does TODAY about "who may name this module".
# Runs on a scratch OTP-25 port of bsc (see ../common/build-bsc.sh). Prints raw output.
HERE=$(cd "$(dirname "$0")" && pwd)
BSC=$("$HERE/../common/build-bsc.sh" /tmp/claude-0/ws60base 2>/dev/null | tail -1)
OUT=$(mktemp -d); cd "$HERE"
for c in PublicCall PrivateCall InternalCall NoUsing; do
  echo "=== Callers/$c  (bsc --src-root src src/Callers/$c Go 5)"
  "$BSC" -o "$OUT/$c" --src-root src "src/Callers/$c" Go 5 2>&1; echo "exit=$?"
done
echo "=== --api of Shop.Orders (does it list the private helper?)"
"$BSC" --src-root src --api src/Shop/Orders 2>&1; echo "exit=$?"
echo "=== --api of Shop.Orders.Internal"
"$BSC" --src-root src --api src/Shop/Orders/Internal 2>&1; echo "exit=$?"
