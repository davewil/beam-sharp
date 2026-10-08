#!/bin/bash
# P4: Option A (path-derived: an `Internal` path segment limits naming to the parent subtree). Same tree, patched vs unpatched bsc.
. "$(dirname "$0")/lib60.sh"
R=$(mktemp -d); tree_a $R
run() { local ebin=$1; shift; for m in "$@"; do
  printf '%-22s ' $m; out=$(BSC_EBIN=$ebin cc $R $m | grep -v 'Warning: function' | cut -c1-200); [ -z "$out" ] && echo accepted || { echo REFUSED; echo "$out" | sed 's/^/      | /' | head -4; }; done; }
echo "=== UNPATCHED bsc (baseline)"; run /tmp/bsbuild/ebin Acme/Orders Acme/Orders/Sub Acme/Billing_ok Acme/Billing_bad
echo "=== PATCHED bsc, Option A"; run /tmp/bsb_60_a/ebin Acme/Orders Acme/Orders/Sub Acme/Billing_ok Acme/Billing_bad
echo "=== namespace imports (Billing_bad removed first: 'using Acme' compiles every module under Acme, so a refused sibling would mask the result)"
rm -rf $R/Acme/Billing_bad
echo "-- unpatched"; run /tmp/bsbuild/ebin Ext/Billing_ns Ext/Billing_ns_bad
echo "-- patched";   run /tmp/bsb_60_a/ebin Ext/Billing_ns Ext/Billing_ns_bad
echo "=== run the allowed ones under the patched bsc (expect 3*... values)"
BSC_EBIN=/tmp/bsb_60_a/ebin cc $R Acme/Billing_ok Due 5 | grep -v Warning
BSC_EBIN=/tmp/bsb_60_a/ebin cc $R Ext/Billing_ns Due 5 | grep -v Warning
rm -rf $R
