#!/usr/bin/env bash
# Ticket 60: the callee-side-by-path rule (Go's `internal/`), prototyped at add_import (bs_check.erl).
# Four importers (the 4th names the Internal NAMESPACE, not the module) of Shop.Pricing.Internal.Rates: its parent Shop.Pricing (allowed), a descendant of the
# parent Shop.Pricing.Sub (allowed), and an unrelated sibling Shop.Reports (refused).
# Usage: BSC=<bsc from variant_internal_segment.patch> bash p4_internal_prototype.sh   (BSC unpatched shows the control)
set -u; here=$(cd "$(dirname "$0")" && pwd); BSC=${BSC:?}
for m in Pricing Pricing/Sub Reports Vians; do
  printf '%-18s ' "Shop/$m"; "$BSC" --src-root "$here/prog" "$here/prog/Shop/$m" 2>&1 | head -2 | tr '\n' ' '; echo "(exit ${PIPESTATUS[0]})"
done
echo "--- runtime sanity: the allowed path still runs"; "$BSC" --src-root "$here/prog" "$here/prog/Shop/Pricing" Charge :standard 2 2>&1 | head -2
