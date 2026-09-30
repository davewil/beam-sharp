#!/usr/bin/env bash
# P2: the program `private` cannot express: a helper two sibling modules share.
# Shop.Ledger.Round must be `public` (exported) for Shop.Billing to call it;
# today that also lets Web.Checkout, which has no business with it, call it.
cd "$(dirname "$0")"; export BSC_EBIN=${BSC_EBIN:-/tmp/bsc-build-60/ebin}
echo '--- Shop.Billing (intended caller) -> Bill(103)'
./_bsc.sh --src-root fx -o /tmp/p2out fx/Shop/Billing Bill 103; echo "exit=$?"
echo '--- Web.Checkout (unintended caller) -> Total(103)'
./_bsc.sh --src-root fx -o /tmp/p2out fx/Web/Checkout Total 103; echo "exit=$?"
echo '--- Web.NoUsing: qualified call with NO using line -> is `using` the only door?'
./_bsc.sh --src-root fx -o /tmp/p2out fx/Web/NoUsing Total 103; echo "exit=$?"
