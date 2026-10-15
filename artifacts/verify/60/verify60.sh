#!/usr/bin/env bash
# Verifier's own probes for brief 60. Builds STOCK (from repo source, control) and PATCHED bsc in a scratch dir,
# then runs fixtures through both. Writes nothing into the repo. Usage: ./verify60.sh
. /home/user/beam-sharp/artifacts/probes/env.sh
H=/home/user/beam-sharp/artifacts/probes
T=$(mktemp -d /tmp/verify60build.XXXXXX)
for v in stock patched; do mkdir $T/$v; cp -r $REPO/compiler $T/$v/compiler; rm -rf $T/$v/compiler/_build
  [ $v = patched ] && ( cd $T/patched && patch -s -p1 < $H/60_internal.patch )
  ( cd $T/$v/compiler && rebar3 escriptize >/dev/null 2>&1 ) || { echo "build $v failed"; exit 1; }; done
S=$T/stock/compiler/_build/default/bin/bsc; P=$T/patched/compiler/_build/default/bin/bsc
echo "diffstat stock-source vs patched-source:"; diff -ru $T/stock/compiler/src $T/patched/compiler/src | grep -c '^+[^+]' | sed 's/^/  added lines (incl blank+): /'; diff -ru $T/stock/compiler/src $T/patched/compiler/src | grep -c '^-[^-]' | sed 's/^/  removed lines: /'
diff -ru $T/stock/compiler/src $T/patched/compiler/src | grep '^+' | grep -v '^+++' | grep -c '^+$' | sed 's/^/  of which blank: /'
F=$T/fx; O=$T/out; mkdir -p $O
mk() { mkdir -p "$F/$1/$(dirname $2)"; cat > "$F/$1/$2"; }
run() { # fixture module fn arg
  for c in stock:$S patched:$P; do L=${c%%:*}; B=${c#*:}; rm -rf $O/$1.$L; mkdir -p $O/$1.$L
    r=$(cd $F/$1 && $B --src-root . -o $O/$1.$L $2 $3 "$4" 2>&1); echo "  [$L] exit $? | $(echo "$r" | head -1)"; done; }
H1='module Common.Internal
public int Fmt(int n)
Fmt(n) -> n + 100'
echo "=== E1 shared helper between two NON-nested top-level modules (Billing, Inventory), helper placed at Common.Internal"
mk e1 Common/Internal/F.bs <<<"$H1"
mk e1 Billing/B.bs <<<'module Billing
using Common.Internal
public int Bill(int n)
Bill(n) -> Fmt(n)'
echo "  Billing -> Common.Internal:"; run e1 Billing Bill 1
echo "=== E1b same, helper hoisted to root-level 'Internal' (module Internal.Fmt): is it protected at all?"
mk e1b Internal/F.bs <<<'module Internal
public int Fmt(int n)
Fmt(n) -> n + 100'
mk e1b Audit/A.bs <<<'module Audit
using Internal
public int Go(int n)
Go(n) -> Fmt(n)'
echo "  Audit (unrelated) -> root Internal:"; run e1b Audit Go 1
echo "=== E1c shared helper hoisted to common ancestor App.Internal; App.Billing + App.Inventory use it (plausible layout)"
mk e1c App/Internal/F.bs <<<'module App.Internal
public int Fmt(int n)
Fmt(n) -> n + 100'
mk e1c App/Billing/B.bs <<<'module App.Billing
using App.Internal
public int Bill(int n)
Bill(n) -> Fmt(n)'
mk e1c App/Inventory/I.bs <<<'module App.Inventory
using App.Internal
public int Stock(int n)
Stock(n) -> Fmt(n)'
mk e1c Outside/O.bs <<<'module Outside
using App.Internal
public int Go(int n)
Go(n) -> Fmt(n)'
echo "  App.Billing:"; run e1c App/Billing Bill 1; echo "  App.Inventory:"; run e1c App/Inventory Stock 1; echo "  Outside (must be refused patched only):"; run e1c Outside Go 1
echo "=== E2 test modules: sibling-in-tree (Shop.Orders.Tests) vs parallel test tree (Tests.Shop.Orders) naming Shop.Orders.Internal"
mk e2 Shop/Orders/Internal/R.bs <<<'module Shop.Orders.Internal
public int Rt(int n)
Rt(n) -> n * 2'
mk e2 Shop/Orders/Tests/T.bs <<<'module Shop.Orders.Tests
using Shop.Orders.Internal
public int T(int n)
T(n) -> Rt(n)'
mk e2 Tests/Shop/Orders/T.bs <<<'module Tests.Shop.Orders
using Shop.Orders.Internal
public int T(int n)
T(n) -> Rt(n)'
echo "  Shop.Orders.Tests (in tree):"; run e2 Shop/Orders/Tests T 2; echo "  Tests.Shop.Orders (parallel tree):"; run e2 Tests/Shop/Orders T 2
echo "=== E3 nesting: a/Internal/b/Internal/c named from a.Internal.Other (Go uses the LAST internal element)"
mk e3 A/Internal/Other/O.bs <<<'module A.Internal.Other
using A.Internal.B.Internal.C
public int Go(int n)
Go(n) -> Cc(n)'
mk e3 A/Internal/B/Internal/C/C.bs <<<'module A.Internal.B.Internal.C
public int Cc(int n)
Cc(n) -> n'
echo "  A.Internal.Other -> A.Internal.B.Internal.C (Go would refuse: not under A/internal/B):"; run e3 A/Internal/Other Go 1
echo "=== E4 segment-spelling hole: Shop.InternalTools.Internal.Secret (a real Internal segment after a longer name starting with Internal)"
mk e4 Shop/InternalTools/Internal/S.bs <<<'module Shop.InternalTools.Internal
public int Sec(int n)
Sec(n) -> n'
mk e4 Audit/A.bs <<<'module Audit
using Shop.InternalTools.Internal
public int Go(int n)
Go(n) -> Sec(n)'
echo "  Audit -> Shop.InternalTools.Internal (should be refused by the rule's intent):"; run e4 Audit Go 1
echo "=== E5 lenient/--api mode on an outsider (LSP/doc path): does the rule skip?"
(cd $F/e1 && echo "  patched --api Billing:" && $P --src-root . --api Billing 2>&1 | head -3)
echo "=== E6 option C for the 24 s2 case: a B# test module naming Orders and calling the private RecomputeTotal"
mkdir -p $F/e6/Orders $F/e6/OrdersTest
cp $H/60_orders/Orders/*.bs $F/e6/Orders/
mk e6 OrdersTest/T.bs <<<'module OrdersTest
using Orders
public int T(list<int> l)
T(l) -> RecomputeTotal(l, 0)'
echo "  stock bsc (no rule at all), test calls private helper:"; r=$(cd $F/e6 && $S --src-root . -o $O OrdersTest T "[1,2]" 2>&1); echo "  exit $? | $(echo "$r"|head -3)"
echo "=== E7 control: prebuilt \$BSC vs stock rebuilt from source agree on proto outsider fixture?"
for b in $BSC $S; do (cd $H/60_shop/outsider_orders_internal && r=$($b --src-root . -o $O Audit Report "[1]" 2>&1); echo "  $(basename $(dirname $(dirname $(dirname $(dirname $b)))))/..: exit $? | $r"); done
