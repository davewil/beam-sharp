#!/bin/sh
# Probe 60/09: ticket 24 §2's consumer. `RecomputeTotal/1` was "unclassified" because every function was exported.
# After F12 (private by default), what does the boundary an agent-written test loop reads (`bsc --api`) show?
BSC=/tmp/claude-0/-home-user-beam-sharp/41c7fa9e-39c6-543b-8f3d-dee4a7daa0ba/scratchpad/bsc.sh
cd "$(dirname "$0")"
SRC=../01_tree/src
echo "== --api of Acme.Billing (public Charge, private Round)"
$BSC --src-root $SRC --api $SRC/Acme/Billing; echo "exit=$?"
echo "== --api of Acme.Billing.Ledger (public Post: the helper Billing wants to keep to itself)"
$BSC --src-root $SRC --api $SRC/Acme/Billing/Ledger; echo "exit=$?"
