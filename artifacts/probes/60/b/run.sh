#!/usr/bin/env bash
# 60/b : checker delta prototype (module-level `internal` = subtree of the module's parent path).
# Uses the PATCHED bsc built by ../proto/build.sh (a copy; the repo compiler is untouched).
here=$(cd "$(dirname "$0")" && pwd)
bsc=$("$here/../proto/build.sh") || exit 1
out=$(mktemp -d); trap 'rm -rf "$out"' EXIT
cd "$here/src"
t () { echo "== $1"; shift; "$bsc" -o "$out" --src-root . "$@" 2>&1; echo "exit=$?"; }
t "Shop.Orders (parent of internal Shop.Orders.Recompute): allowed" Shop/Orders
t "Shop.Orders.Tests (descendant of Shop.Orders): allowed -- tests inside the subtree see it" Shop/Orders/Tests
t "Shop.Billing (sibling subtree): refused" Shop/Billing
t "Tools.Rogue (other tree): refused" Tools/Rogue
t "Tools.Spy via NAMESPACE import 'using Vault' then Hidden.Open: shape of the refusal" Tools/Spy
