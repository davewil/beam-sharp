#!/usr/bin/env bash
# 60/i : unit = subtree, but the SUBTREE IS NAMED by the callee (`within Shop`), not derived from the parent path.
here=$(cd "$(dirname "$0")" && pwd)
bsc=$("$here/../proto/build.sh") || exit 1
out=$(mktemp -d); w=$(mktemp -d); trap 'rm -rf "$out" "$w"' EXIT
cp -r "$here/../b/src/." "$w"
printf 'module Shop.Orders.Recompute\n\nwithin Shop\n' > "$w/Shop/Orders/Recompute/index.bs"
cd "$w"
t () { echo "== $1"; shift; "$bsc" -o "$out" --src-root . "$@" 2>&1; echo "exit=$?"; }
t "Shop.Orders (under Shop)" Shop/Orders
t "Shop.Billing (under Shop; refused by parent-derived 'internal' in probe b)" Shop/Billing
t "Shop.Orders.Tests (under Shop)" Shop/Orders/Tests
t "Tools.Rogue (outside Shop)" Tools/Rogue
