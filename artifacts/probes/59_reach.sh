#!/usr/bin/env bash
# 59_reach.sh -- CAN a wrongly-tagged record reach a PRIVATE function through an EXPORTED one,
# and which guard stops it?
#
# Claim under test (ticket 59, "It is not [a defect]"): "a forged record can reach a private
# function by being passed through an exported one, which 18 s4's function-local analysis is
# explicitly designed not to trace".
# Method: one B# module G (59_reach/G/g.bs) with a private Priv(Order) and exported functions that
# reach it directly / via a record field / list / tuple / union / ValidateAs. Compiled under
#   HEAD (tag test on every record fn), EXP (tag test exported only = control with the private
#   test removed), ALL (every guard on every fn). Each beam is handed forged maps from escript.
# REFUTED if: under EXP, ViaNested/ViaList/ViaTuple with an Invoice-tagged inner value still raise
#   function_clause (then the private test was dead weight). CONFIRMED if EXP returns `ok 5`
#   for them while HEAD raises.
set -u
cd "$(dirname "$0")"; . ./env.sh; . ./59_lib.sh
T=$(mktemp -d "${TMPDIR:-/tmp}/p59reach.XXXXXX")
for V in HEAD EXP ALL; do
  var=BSC_$V; mkdir -p "$T/$V"
  (cd 59_reach && "${!var}" --src-root . -o "$T/$V" G) || { echo "compile failed under $V"; exit 1; }
  echo "=== $V : emitted guards ==="; ./59_guards.escript "$T/$V/G.beam"
  echo "--- $V : forged calls ---";    ./59_forge.escript "$T/$V"
  echo
done
echo "=== diff HEAD vs EXP forged calls (lines that CHANGE when the private tag test is removed) ==="
diff <(./59_forge.escript "$T/HEAD") <(./59_forge.escript "$T/EXP") && echo "(none)"
