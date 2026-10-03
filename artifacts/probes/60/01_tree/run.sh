#!/bin/sh
# Probe 60/01: how cross-module names resolve today. Run from anywhere.
# (Attempt 1, run.first-attempt.out, put the bad file in the same directory as the good one;
#  a directory is ONE module, so every file was compiled together and the first error hid the rest.
#  The tree was split into one module per case. No expectation was changed.)
BSC=/tmp/claude-0/-home-user-beam-sharp/41c7fa9e-39c6-543b-8f3d-dee4a7daa0ba/scratchpad/bsc.sh
cd "$(dirname "$0")"
b() { $BSC --src-root src "$@"; echo "exit=$?"; }
echo "== A. Orders: using Acme.Billing.Ledger, calls Post. Nothing declares Ledger internal"; b src/Acme/Orders Total 41
echo "== B. Reports: no using, calls Acme.Billing.Ledger.Post qualified"; b src/Acme/Reports Qual 41
echo "== C. NoUse: no using, calls Acme.Billing.Round qualified"; b src/Acme/NoUse Peek 41
echo "== D. Spy: using Acme.Billing, calls Billing's private Round unqualified"; b src/Acme/Spy Peek 41
echo "== F. diagnostics json for the Spy module"; $BSC --src-root src --diagnostics json src/Acme/Spy Peek 41 2>&1 | head -5
echo "== G. Billing alone, positive control"; b src/Acme/Billing Charge 123
