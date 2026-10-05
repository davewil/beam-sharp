#!/usr/bin/env bash
# CLAIM (ticket 41 section 5 diagram): a directory INSIDE a module is a source-only SUB-MODULE of it (`Shop/Orders/Internal/`).
# F15.11 says the opposite: classification is per directory, so a nested directory holding .bs is its OWN module.
# This decides whether `Shop.Orders.Internal` can exist as a module path at all (candidate A depends on it).
# REFUTED (the 41 diagram, i.e. nested dir = sub-module of the parent) IF `bsc Shop/Orders/Internal` compiles as its own
# module 'Shop.Orders.Internal' AND `bsc Shop/Orders` does not absorb its files.
. "$(dirname "$0")/lib.sh"
build_variant base >/dev/null || exit 1
B=$(bsc_of base); T="$WORK/p17"; rm -rf "${T:?}"; mkdir -p "$T/Shop/Orders/Internal" "$T/Shop/Billing"; cd "$T" || exit 1
cat > Shop/Orders/Total.bs <<'EOT'
module Shop.Orders

public int Total(int n)
Total(n) -> n + 1
EOT
cat > Shop/Orders/Internal/Helper.bs <<'EOT'
module Shop.Orders.Internal

public int Help(int n)
Help(n) -> n * 2
EOT
cat > Shop/Billing/Bill.bs <<'EOT'
module Shop.Billing

using Shop.Orders.Internal

public int Bill(int n)
Bill(n) -> Help(n)
EOT
rm -rf o; mkdir o
echo '$ bsc --src-root . -o o Shop/Orders        (the parent module, with a nested directory that holds .bs)'
"$B" --src-root . -o o Shop/Orders; r1=$?; echo "exit=$r1"; ls o
echo '$ bsc --src-root . -o o Shop/Orders/Internal'
"$B" --src-root . -o o Shop/Orders/Internal; r2=$?; echo "exit=$r2"; ls o
echo '$ bsc --src-root . -o o Shop/Billing 4   (a cousin names Shop.Orders.Internal)'
"$B" --src-root . -o o Shop/Billing Bill 4; r3=$?; echo "exit=$r3"; ls o
[ $r1 -eq 0 ] && [ $r2 -eq 0 ] && [ $r3 -eq 0 ] && [ -f o/Shop.Orders.beam ] && [ -f o/Shop.Orders.Internal.beam ]
verdict "nested-dir-is-its-own-module (F15.11); 41-section-5 sub-module diagram REFUTED if CONFIRMED" $?
