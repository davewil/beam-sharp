#!/bin/bash
# P6: Option C (callee lists its `friend`s). Patched vs unpatched bsc; then the edit-the-callee friction; then a typo'd friend.
. "$(dirname "$0")/lib60.sh"
R=$(mktemp -d); tree_c $R
M="Acme/Orders Acme/Orders/Sub Acme/Billing Acme/Reports"
run() { local ebin=$1; shift; for m in "$@"; do
  printf '%-22s ' $m; out=$(BSC_EBIN=$ebin cc $R $m | grep -v 'Warning: function' | cut -c1-200); [ -z "$out" ] && echo accepted || { echo REFUSED; echo "$out" | sed 's/^/      | /' | head -4; }; done; }
echo "=== CONTROL, unpatched bsc, tree WITHOUT the friend line: every caller accepted (the refusals below are the option's doing)"
grep -v '^friend' $R/Acme/Pricing/a.bs > $R/p.tmp; cp $R/Acme/Pricing/a.bs $R/p.orig; cp $R/p.tmp $R/Acme/Pricing/a.bs
run /tmp/bsbuild/ebin $M
cp $R/p.orig $R/Acme/Pricing/a.bs
echo "=== UNPATCHED bsc WITH the friend line: callee does not parse, dependency unreachable (message is about the missing module, not the keyword)"; run /tmp/bsbuild/ebin Acme/Orders
echo "=== PATCHED bsc, Option C"; run /tmp/bsb_60_c/ebin $M
echo "=== now add a legitimate caller: Acme.Reports needs 'friend Acme.Reports' written into the CALLEE"
sed -i 's/^friend Acme.Orders$/friend Acme.Orders\nfriend Acme.Reports/' $R/Acme/Pricing/a.bs
run /tmp/bsb_60_c/ebin Acme/Reports Acme/Billing
echo "=== typo in the friend list: 'friend Acme.Ordres' (no check that the named module exists)"
sed -i 's/^friend Acme.Orders$/friend Acme.Ordres/' $R/Acme/Pricing/a.bs
run /tmp/bsb_60_c/ebin Acme/Orders Acme/Reports
rm -rf $R
