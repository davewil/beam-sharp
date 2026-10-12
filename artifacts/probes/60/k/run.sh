#!/usr/bin/env bash
# 60/k : the ZERO-GRAMMAR spelling: a module whose path has an `Internal` segment (Go's rule, probe j) is nameable only
# from the subtree rooted at that segment's parent. Same tree as probe b, but the directory is named Internal; no keyword.
here=$(cd "$(dirname "$0")" && pwd)
bsc=$("$here/../proto/build.sh") || exit 1
out=$(mktemp -d); w=$(mktemp -d); trap 'rm -rf "$out" "$w"' EXIT
mkdir -p "$w/Shop/Orders/Internal/Recompute" "$w/Shop/Orders/Tests" "$w/Shop/Billing" "$w/Tools/Rogue"
cp "$here/../b/src/Shop/Orders/Recompute/Sum.bs" "$w/Shop/Orders/Internal/Recompute/Sum.bs"
sed -i 's/Shop.Orders.Recompute/Shop.Orders.Internal.Recompute/' "$w/Shop/Orders/Internal/Recompute/Sum.bs"
for f in Shop/Orders/Total.bs Shop/Orders/Tests/Check.bs Shop/Billing/Charge.bs Tools/Rogue/Peek.bs; do
  sed 's/Shop.Orders.Recompute/Shop.Orders.Internal.Recompute/' "$here/../b/src/$f" > "$w/$f"; done
cd "$w"; find . -name '*.bs' | sort
t () { echo "== $1"; shift; "$bsc" -o "$out" --src-root . "$@" 2>&1; echo "exit=$?"; }
t "Shop.Orders" Shop/Orders
t "Shop.Orders.Tests" Shop/Orders/Tests
t "Shop.Billing" Shop/Billing
t "Tools.Rogue" Tools/Rogue
