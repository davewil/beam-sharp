#!/usr/bin/env bash
# Verifier's extra probes for ticket 60 (not by the brief's author). Usage: 60-extra.sh [variant]
# Each case is compiled in its own world: Shop.Orders (as authored) + that one caller.
. "$(cd "$(dirname "$0")/../probes" && pwd)/env.sh"
v=${1:-v60a}
export BSC_EBIN=$PROBE_HOME/variants/$v/ebin
case_(){ # name modpath using callexpr
  local name=$1 mod=$2 use=$3 call=$4 W=$(mktemp -d) O=$(mktemp -d)
  mkdir -p $W/Shop/Orders; cp $root/artifacts/probes/src60/Shop/Orders/orders.bs $W/Shop/Orders/
  local dir=$W/$(echo $mod | tr . /); mkdir -p $dir
  printf 'module %s\nusing %s\npublic int Invoice(int qty)\nInvoice(q) -> %s\n' "$mod" "$use" "$call" > $dir/c.bs
  printf '%-34s ' "$name"
  if out=$($BSC --src-root $W -o $O $dir/c.bs 2>&1) && [ -z "$out" ]; then echo accepted; else echo refused; printf '%s\n' "$out" | sed "s#$W/##;s/^/      | /" | head -3; fi
  rm -rf $W $O
}
case_ "control Shop.Billing (author's)"   Shop.Billing   Shop         'Orders.RecomputeTotal(q)'
case_ "Zed.Billing = same, other prefix"   Zed.Billing    Shop         'Orders.RecomputeTotal(q)'
case_ "Zed.Billing calls PUBLIC Place"     Zed.Billing    Shop         'Orders.Place(q)'
case_ "Zed.Billing using Shop.Orders, unq" Zed.Billing    Shop.Orders  'RecomputeTotal(q)'
case_ "Shop.Billing using Shop.Orders, unq" Shop.Billing  Shop.Orders  'RecomputeTotal(q)'
case_ "Shop.Deep.Inner (3 seg, inside)"    Shop.Deep.Inner Shop        'Orders.RecomputeTotal(q)'
case_ "Zed.Deep.Inner (3 seg, outside)"    Zed.Deep.Inner  Shop        'Orders.RecomputeTotal(q)'
case_ "ShopX.Billing (prefix lookalike)"   ShopX.Billing  Shop         'Orders.RecomputeTotal(q)'
