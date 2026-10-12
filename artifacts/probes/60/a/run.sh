#!/usr/bin/env bash
# 60/a : today, any module can name any PUBLIC function of any other module, wherever it sits in the tree.
# Control: a PRIVATE function is refused (F12). Needs only env.sh sourced.
here=$(cd "$(dirname "$0")" && pwd)
bsc="${BSC:-$here/../../../../compiler/_build/default/bin/bsc}"
out=$(mktemp -d); trap 'rm -rf "$out"' EXIT
cd "$here/src"
echo "== 1. Tools.Rogue (sibling tree) calls PUBLIC Shop.Orders.RecomputeTotal via using"
"$bsc" -o "$out" --src-root . Tools/Rogue; echo "exit=$?"; ls "$out"
echo "== 2. Tools.Rogue RUN: Peek([1,2,3])"
"$bsc" -o "$out" --src-root . Tools/Rogue Peek "[1,2,3]"; echo "exit=$?"
echo "== 3. CONTROL: Tools.Report names PRIVATE Shop.Orders.Recompute qualified"
"$bsc" -o "$out" --src-root . Tools/Report; echo "exit=$?"
echo "== 4. Shop.Billing (a 'friend' by intent) compiles too: nothing distinguishes it"
"$bsc" -o "$out" --src-root . Shop/Billing; echo "exit=$?"
echo "== 5. bsc --api Shop/Orders: the published surface; a public cross-module helper is indistinguishable from client API"
"$bsc" --api --src-root . Shop/Orders; echo "exit=$?"
echo "== 6. a test-shaped module (ordinary B#, 24 s7) in a THIRD tree calling the public helper: also accepted"
mkdir -p "$out/t/Tests/Orders"; printf 'module Tests.Orders\n\nusing Shop.Orders\n\npublic int Check(list<int> xs)\nCheck(xs) -> RecomputeTotal(xs)\n' > "$out/t/Tests/Orders/Check.bs"
cp -r Shop "$out/t/"; (cd "$out/t" && "$bsc" -o "$out/o2" --src-root . Tests/Orders; echo "exit=$?")
echo "== 7. caller side TODAY: qualified call without a using line is refused (the caller-declared dependency list already exists)"
cd "$here/src"; "$bsc" -o "$out" --src-root . Tools/NoUsing; echo "exit=$?"
