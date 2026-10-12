#!/usr/bin/env bash
# 60/c : the EXPLICIT-LIST spelling (`friend M`) on the same tree as probe b. Callee lists who may name it; no subtree rule.
here=$(cd "$(dirname "$0")" && pwd)
bsc=$("$here/../proto/build.sh") || exit 1
out=$(mktemp -d); w=$(mktemp -d); trap 'rm -rf "$out" "$w"' EXIT
cp -r "$here/../b/src/." "$w"
printf 'module Shop.Orders.Recompute\n\nfriend Shop.Orders\nfriend Shop.Billing\n' > "$w/Shop/Orders/Recompute/index.bs"
cd "$w"
t () { echo "== $1"; shift; "$bsc" -o "$out" --src-root . "$@" 2>&1; echo "exit=$?"; }
t "Shop.Orders (listed)" Shop/Orders
t "Shop.Billing (listed)" Shop/Billing
t "Shop.Orders.Tests (NOT listed; was allowed under subtree rule)" Shop/Orders/Tests
t "Tools.Rogue (NOT listed)" Tools/Rogue
echo "-- edit cost: callee file now names its callers; every new legitimate caller edits Recompute/index.bs"
