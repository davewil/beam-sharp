#!/usr/bin/env bash
# P6: P2's shared helper moved to Shop.Internal.Ledger, under the Option B prototype build.
# (attempt 1 ran against fx/, where an unrelated violating module Shop.Reports is loaded transitively by `using Shop`; kept as p6.attempt1-fixture-polluted.out. Now runs against the minimal fx6/.)
# Intended caller Shop.Billing2 must pass; outsider Web.Checkout2 must be refused;
# the namespace-tier door (`using Shop` then Internal.Ledger.Round) must be shut too.
cd "$(dirname "$0")"; export BSC_EBIN=/tmp/bsc-build-60b/ebin
[ -d $BSC_EBIN ] || ./p5_option_b_prototype.sh >/dev/null 2>&1
rm -rf /tmp/p6out; mkdir -p /tmp/p6out
echo '--- Shop.Billing2 -> Bill(103) (expect 100)';   ./_bsc.sh --src-root fx6 -o /tmp/p6out fx6/Shop/Billing2 Bill 103; echo "exit=$?"
echo '--- Web.Checkout2 -> Total(103) (expect refusal)'; ./_bsc.sh --src-root fx6 -o /tmp/p6out fx6/Web/Checkout2 Total 103; echo "exit=$?"
echo '--- Web.Ns: namespace tier, `using Shop` + Internal.Ledger.Round (expect refusal)'; ./_bsc.sh --src-root fx6 -o /tmp/p6out fx6/Web/Ns Total 103; echo "exit=$?"
