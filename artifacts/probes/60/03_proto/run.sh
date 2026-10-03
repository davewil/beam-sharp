#!/bin/sh
# (Attempt 1, run.first-attempt.out, used `Post(c).Amount`, which the grammar does not have, and the namespace
#  short name `Store` where the compiler names it `Internal.Store`. Both were my B# mistakes; no expectation changed.)
# (Attempt 2, run.second-attempt.out: the shell word-split the record argument, Peeker2 named a type it had not imported,
#  and Wide held both the allowed and the refused call in ONE module, so the refusal hid the acceptance. Fixed in the probe.)
# (Attempt 3, run.third-attempt.out: v1 only guarded `using`; case Orders2 showed a qualified TYPE name bypasses it,
#  so v2 adds the type site and the script runs base / v1 / v1+v2.)
# (Attempt 4, run.fourth-attempt.out: Peeker2 wrote `Internal.Ledger` where `using Acme.Billing.Internal` makes the short name `Ledger`;
#  base refused it for MY error, which masked whether base accepts the namespace route. Fixed.)
# (Attempt 6 adds the Acme.Internal.Shared cases: the subtree unit cannot say "Orders yes, Reports no". Attempt 5 = run.fifth-attempt.out.)
# Probe 60/03: PROTOTYPE of option A (`Internal` path segment) in bs_check:add_import/7
# (the caller of add_module_import/3 here; the repo's own arity is 3, ticket 60 says /5 from an
# older commit). Runs the SAME tree through the unmodified compiler (base) and the patched one (proto).
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
W=/tmp/claude-0/-home-user-beam-sharp/41c7fa9e-39c6-543b-8f3d-dee4a7daa0ba/scratchpad/proto60
[ -d $W/proto2/ebin ] || ./build.sh >/dev/null 2>&1
run() { V=$1; shift; erl -noshell -pa $W/$V/ebin -eval 'bsc:main(init:get_plain_arguments()), halt().' -extra --src-root src "$@" 2>&1; echo "exit=$?"; }
case_() { # label module fn arg
  for V in base proto proto2; do echo "-- [$V] $1"; run $V src/$2 "$3" "$4"; done; }
case_ "Billing (the parent) uses its own Internal.Ledger: accepted either way"   Acme/Billing Charge 41
case_ "Billing.Reconcile (a descendant of the parent) uses it: accepted either way" Acme/Billing/Reconcile Run 41
case_ "Orders (outsider) uses only Billing's public face: accepted"             Acme/Orders Total 41
case_ "Orders passes the internal TYPE through Billing's public Open/Amt, never importing it" Acme/Orders Opened 41
case_ "Orders2 NAMES the internal type qualified, no using of its module" Acme/Orders2 Direct "{ Kind = :'Acme.Billing.Internal.Ledger.Entry', Amount = 5 }"
case_ "Peeker (outsider) says using Acme.Billing.Internal.Ledger: REFUSED by proto" Acme/Peeker Peek 41
case_ "Peeker2 (outsider) imports the Internal NAMESPACE: REFUSED by proto"     Acme/Peeker2 Peek 41
case_ "Wide imports namespace Acme.Pay, calls the non-internal Core.Get" Acme/Wide UseCore 7
case_ "Wide2 imports the same namespace, calls Internal.Store.Put (outsider)"                              Acme/Wide2 UseStore 7
# The unit is a SUBTREE: Acme/Internal is visible to everything under Acme, wanted or not.
case_ "Acme.Orders3 uses Acme.Internal.Shared (wanted)"                         Acme/Orders3 Use 1
case_ "Acme.Reports3 uses Acme.Internal.Shared (NOT wanted, but it is under Acme: cannot be refused)" Acme/Reports3 Use 1
case_ "Other.Thing (outside Acme) uses Acme.Internal.Shared: refused"           Other/Thing Use 1
