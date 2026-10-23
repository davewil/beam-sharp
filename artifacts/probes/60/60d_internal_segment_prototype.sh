#!/usr/bin/env bash
# PROBE 60d — PROTOTYPE DELTA: how much checker does a caller-side "who may name this" rule cost?
# The rule prototyped (the cheapest spelling, no syntax): a module whose dotted path has an `Internal`
# segment may be named (`using`) only from modules under the path BEFORE that segment.
# Delta = proto_internal_segment.patch (applied to a COPY of compiler/; the repo is not touched).
# Claims under test:
#   (1) every dependency edge passes through add_import/7, so one site suffices (control: pristine bsc accepts all)
#   (2) the rule refuses an outsider and admits the subtree, with a diagnostic
#   (3) it costs ~nothing at compile time (interleaved wall time, spread reported) and ~21 added lines.
# Needs: source env.sh first (rebar3, erl).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cp -r "$REPO/compiler" "$W/proto"; rm -rf "$W/proto/_build"
( cd "$W/proto" && patch -p2 -s < "$HERE/proto_internal_segment.patch" && rebar3 escriptize >/dev/null 2>&1 ) || { echo "BUILD FAILED"; exit 1; }
PROTO="$W/proto/_build/default/bin/bsc"
PRISTINE="$REPO/compiler/_build/default/bin/bsc"
[ -x "$PRISTINE" ] || PRISTINE="${BSC:?set BSC or build compiler/}"
echo "delta: $(grep -c '^+[^+]' "$HERE/proto_internal_segment.patch") lines added, $(grep -c '^-[^-]' "$HERE/proto_internal_segment.patch") removed (comments and blank lines included)"

T="$W/tree"; mkdir -p "$T/Shop/Internal/Calc" "$T/Shop/Orders" "$T/Billing/Invoice" "$T/Shop/Internal/Deep/Leaf"
cat > "$T/Shop/Internal/Calc/Calc.bs" <<'B'
module Shop.Internal.Calc
public int Double(int n)
Double(n) -> n + n
B
cat > "$T/Shop/Internal/Deep/Leaf/Leaf.bs" <<'B'
module Shop.Internal.Deep.Leaf
using Shop.Internal.Calc
public int Quad(int n)
Quad(n) -> Double(Double(n))
B
cat > "$T/Shop/Orders/Orders.bs" <<'B'
module Shop.Orders
using Shop.Internal.Calc
public int Total(int n)
Total(n) -> Double(n)
B
cat > "$T/Billing/Invoice/Invoice.bs" <<'B'
module Billing.Invoice
using Shop.Internal.Calc
public int Total(int n)
Total(n) -> Double(n)
B
mkdir -p "$T/Billing/Direct"
cat > "$T/Billing/Direct/Direct.bs" <<'B'
module Billing.Direct
public int Total(int n)
Total(n) -> Shop.Internal.Calc.Double(n)
B
status() { "$1" --src-root "$T" -o "$W/o.$$" "$T/$2" >/dev/null 2>&1; echo $?; }
say()    { "$1" --src-root "$T" -o "$W/o.$$" "$T/$2" 2>&1; }
show() { printf '  %-34s pristine: %-3s  prototype: %s\n' "$1" "$(status "$PRISTINE" "$2")" "$(status "$PROTO" "$2")"; }
echo "== exit codes (0 = compiled)"
show "Shop.Orders      (under Shop)"      Shop/Orders
show "Shop.Internal.Deep.Leaf (sibling)"  Shop/Internal/Deep/Leaf
show "Billing.Invoice  (outsider)"        Billing/Invoice
echo "== the outsider's diagnostic from the prototype:"
say "$PROTO" Billing/Invoice | sed 's/^/    /'
echo "== claim (1): a QUALIFIED call that skips \`using\` is refused by the PRISTINE compiler too (exit $(status "$PRISTINE" Billing/Direct)):"
say "$PRISTINE" Billing/Direct | head -2 | sed 's/^/    /'
echo "== the same file under the pristine compiler: (exit $(status "$PRISTINE" Billing/Invoice) = accepted, no diagnostic)"

echo "== compile wall time, Shop/Reports + corpus modules, 15 interleaved rounds (ms; median [min..max])"
EX="$REPO/compiler/examples"
tm() { local s e; s=$(date +%s%N); "$1" --src-root "$EX" -o "$W/t" "$EX/$2" >/dev/null 2>&1; e=$(date +%s%N); echo $(( (e-s)/1000000 )); }
for mod in Shop/Reports Shop; do
  a=(); b=()
  tm "$PRISTINE" "$mod" >/dev/null; tm "$PROTO" "$mod" >/dev/null
  for i in $(seq 15); do a+=("$(tm "$PRISTINE" "$mod")"); b+=("$(tm "$PROTO" "$mod")"); done
  sa=($(printf '%s\n' "${a[@]}" | sort -n)); sb=($(printf '%s\n' "${b[@]}" | sort -n))
  printf '  %-14s pristine %s [%s..%s]   prototype %s [%s..%s]\n' "$mod" "${sa[7]}" "${sa[0]}" "${sa[14]}" "${sb[7]}" "${sb[0]}" "${sb[14]}"
done
echo "== the rule's own cost, isolated (1e6 calls of module_visible/3, compiled loop)"
mkdir -p "$W/mv" && erlc +export_all -o "$W/mv" "$W/proto/src/bs_check.erl" 2>/dev/null
cat > "$W/mv/mvbench.erl" <<'E2'
-module(mvbench).
-export([run/0]).
run() ->
    Self = list_to_atom("Shop.Orders"), M = list_to_atom("Shop.Internal.Calc"),
    {U, _} = timer:tc(fun() -> spin(Self, M, 1000000) end),
    io:format("  ~.1f ns per check (allowed caller)~n", [U * 1000 / 1000000]).
spin(_, _, 0) -> ok;
spin(S, M, N) -> bs_check:module_visible(S, M, 1), spin(S, M, N - 1).
E2
erlc -o "$W/mv" "$W/mv/mvbench.erl" && ( cd "$W" && erl -noshell -pa "$W/mv" -eval 'mvbench:run(), halt().' )
