#!/usr/bin/env bash
# CLAIM: at HEAD no module can be refused for naming another (the who-half is unbuilt); a callee-side rule keyed on
#   directory path ("a module with an `Internal` path segment may be named only from the prefix before it and
#   below") needs ~30 lines at add_import and refuses the right callers and no others.
# REFUTED IF: HEAD refuses any of the four variants (exit != 0) -- then the gap is not there;
#   or the patched compiler exits 0 on an outsider_*/sibling_* variant; or exits != 0 on `ok` / `namespace_ok`. (`namespace_import` has Report and Sneak in ONE module, so it is expected red under the patch.)
# CONTROLS: `ok` (descendant, Shop-wide-internal from sibling, outsider using a PUBLIC module) must be green under BOTH.
. "$(dirname "$0")/env.sh"; D="$(cd "$(dirname "$0")" && pwd)"
PB=$("$D/60_build_patched.sh" | tail -1); [ -x "$PB" ] || { echo "patched build failed"; exit 1; }
echo "patch size: $(grep -c '^+[^+]' $D/60_internal.patch) added, $(grep -c '^-[^-]' $D/60_internal.patch) removed lines (bs_check.erl + bs_diag.erl)"
t() { # variant label compiler module fn arg
  ( cd "$D/60_shop/$1" && out=$("$3" --src-root . $4 $5 "$6" 2>&1); echo "[$2] $1 $4 -> exit $? | $(echo "$out" | head -1)" ); }
for pair in "head:$BSC" "patched:$PB"; do L=${pair%%:*}; C=${pair#*:}
  t ok $L $C Shop/Billing Invoice "[100,200]"
  t ok $L $C Audit Report "[100,200]"
  t outsider_orders_internal $L $C Audit Report "[1]"
  t sibling_orders_internal $L $C Shop/Billing Invoice "[1]"
  t outsider_shop_internal $L $C Audit Report "[1]"
  t namespace_ok $L $C Audit Report "[1,2]"
  t namespace_import $L $C Audit Sneak "[1,2]"
done
