#!/usr/bin/env bash
# Probe 1 - what exists today. Is there any way to say WHO may name a module?
# Run: p1_baseline.sh BSC_DIR   (BSC_DIR from build-bsc.sh)
set -u
here=$(cd "$(dirname "$0")" && pwd); bsc=$1/bsc; t=$here/tree
echo "== 1a Reports reaches into Shop.Billing.Ledger (the subtree-internal helper)"
$bsc --src-root $t $t/Shop/Reports Restate 5 2>&1 | head -5
echo "== 1b Reports2 calls Shop.Billing's PRIVATE Secret (existing rule: private = module-only)"
$bsc --src-root $t $t/Shop/Reports2 Peek 5 2>&1 | head -5
echo "== 1c the legitimate edge: Billing -> Ledger"
$bsc --src-root $t $t/Shop/Billing Charge 5 2 2>&1 | head -5
echo "== 1d is there any construct in the checker/parser that spells 'who'?"
grep -n -i -E "internal|friend|sealed|visible_to" $here/../../../compiler/src/bs_parser.yrl $here/../../../compiler/src/bs_lexer.xrl $here/../../../compiler/src/bs_check.erl | grep -v "^.*%%" | head -5 || true
echo "(grep hits above are only prose/identifier hits; empty = none)"
