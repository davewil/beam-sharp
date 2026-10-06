#!/usr/bin/env bash
# PROBE 60j -- ticket 60 (ENG-242). Claim (a STALENESS check on the ticket's consumer paragraph):
# ticket 24 §2 / ticket 22 describe `RecomputeTotal/1` landing `unclassified` because visibility was
# undecided. F12 later made private the default, so (J1) an unmarked helper is absent from `bsc --api`
# and (J2) is refused as a callee from another module. What `--api` still cannot separate is a PUBLIC
# function that exists for a sibling module (J3): that is the residue ticket 60 can still serve.
# Control: marking the helper `public` makes it appear (J1 goes red if --api ignored visibility).
set -uo pipefail
: "${BSC:?}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/src/Orders" "$W/src/Billing" "$W/src/Peek"
cat > "$W/src/Orders/Orders.bs" <<'E'
module Orders
public int Total(int n)
Total(n) -> RecomputeTotal(n)
int RecomputeTotal(int n)
RecomputeTotal(n) -> n * 2
public int ForBilling(int n)
ForBilling(n) -> n + 1
E
printf 'module Billing\nusing Orders\npublic int B(int n)\nB(n) -> ForBilling(n)\n' > "$W/src/Billing/Billing.bs"
printf 'module Peek\nusing Orders\npublic int P(int n)\nP(n) -> RecomputeTotal(n)\n' > "$W/src/Peek/Peek.bs"
echo "--- J1 bsc --api Orders (RecomputeTotal unmarked => private by default)"
"$BSC" --src-root "$W/src" --api "$W/src/Orders" 2>&1
echo "--- J1 control: mark it public"
sed -i 's/^int RecomputeTotal/public int RecomputeTotal/' "$W/src/Orders/Orders.bs"
"$BSC" --src-root "$W/src" --api "$W/src/Orders" 2>&1
sed -i 's/^public int RecomputeTotal/int RecomputeTotal/' "$W/src/Orders/Orders.bs"
echo "--- J2 a test-like module naming the helper"
"$BSC" --src-root "$W/src" -o "$W/o" "$W/src/Peek" 2>&1 | sed "s|$W/src/||" | head -2; echo "exit=${PIPESTATUS[0]}"
echo "--- J3 ForBilling is public only for Billing, yet --api cannot say so (it appears like Total)"
"$BSC" --src-root "$W/src" --api "$W/src/Orders" 2>&1 | grep -c "ForBilling"
