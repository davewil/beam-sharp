#!/usr/bin/env bash
#
# F30 / ENG-279 — THE VALVE STOPS ON THE FIXED PAIR `(:error, _) | :nothing`.
#
# Ticket 49 settled the set on 2026-08-28; David reaffirmed the build on
# 2026-09-09 after the price was re-measured and found worse than 49 recorded.
# `|?>` short-circuited on `(:error, _)` alone until then, which refused the
# very shape ticket 17 §4 borrowed the operator for.
#
# A REJECTION GATE, NOT A STOPWATCH. Every failure this feature can produce is
# visible in a compile, which is the opposite of F28 — said out loud so the next
# author does not copy the wrong template.
#
# WHY SEVEN MODULES AND NOT TWO. Four of the five defects below pass the
# headline. `param_keyed` passes every positive scenario and fails on nothing
# but V6; `silent_widen` passes every positive scenario and fails on nothing but
# V4. A gate that probed only "does the option chain compile" would be green on
# both, and both are implementations somebody would ship.
#
# WHY THE ACCEPTS ASSERT A SIGNATURE. A shape that stops compiling for an
# unrelated reason must land here as a failure rather than pass quietly, so each
# accepting module is pinned to the exact `--api` line it produces.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

CANNOT_FAIL="is over a value that cannot fail"
CORRECTED="the signature its clauses justify:"

# Only the accepting modules are a list. Each refusal is judged on its own
# terms below — V4 on the corrected signature naming the added member, V5 on
# the wording, V6 on the refusal standing at all — so a loop over a REFUSE list
# would have to be a loop over three different questions.
ACCEPT="V1 V2 V3 V7"

expected_sig() {
  case "$1" in
    V1) echo ':nothing | int Load(int)' ;;
    V2) echo 'int | (:error, atom) Place(int)' ;;
    V3) echo ':nothing | int | (:error, :bad) Go(int)' ;;
    V7) echo 'atom Go(int)' ;;
  esac
}

# ---------------------------------------------------------------------------
# judge — the whole of the gate's opinion in one place, so --self-test drives
# THIS code path against stubbed verdicts rather than a copy of it.
# ---------------------------------------------------------------------------
judge() {
  local dir="$1" v out want
  for v in $ACCEPT; do
    out="$(cat "$dir/$v.out")"
    want="$(expected_sig "$v")"
    case "$out" in
      *"$CANNOT_FAIL"*)
        echo "$v: a valve over a subject carrying one of the pair was REFUSED (got '$out')" ;;
      *"$want"*) ;;
      *) echo "$v: did not compile to '$want' (got '$out')" ;;
    esac
  done

  # V4 — the migration. A short-circuited `:nothing` is returned unchanged, so
  # the valve's type gains it and a return type written before this feature is
  # now wrong. F25 prints the repair; a build that widened the type SILENTLY
  # changes what every caller must handle and is caught here alone.
  out="$(cat "$dir/V4.out")"
  case "$out" in
    *"$CORRECTED"*)
      case "$out" in
        *':nothing'*) ;;
        *) echo "V4: the corrected signature does not name \`:nothing\`, so the migration is a puzzle (got '$out')" ;;
      esac ;;
    *) echo "V4: a return type that omits \`:nothing\` was ACCEPTED, so the widening is silent (got '$out')" ;;
  esac

  # V5 — the meet is with BOTH members now, and the prose is the whole of the
  # diagnostic's usefulness: an author told their type has no `(:error, _)`
  # member learns the wrong thing about what the compiler asked.
  out="$(cat "$dir/V5.out")"
  case "$out" in
    *"$CANNOT_FAIL"*)
      case "$out" in
        *':nothing'*) ;;
        *) echo "V5: refused, but the message names only the error member — the compiler looked for two things and said one (got '$out')" ;;
      esac ;;
    *) echo "V5: a valve over a subject with NEITHER member was accepted (got '$out')" ;;
  esac

  # V6 — SHAPE B, AND THIS IS THE CONTROL. Ticket 49 refused keying the
  # short-circuit on the stage's declared parameter type on a measurement:
  # `binary \ string` is a non-empty residual with no head and no BEAM guard, so
  # a build that reached for the parameter would accept this and then fail to
  # lower it. Nothing else in this roster sees that.
  out="$(cat "$dir/V6.out")"
  case "$out" in
    *"$CANNOT_FAIL"*) ;;
    *) echo "V6: a NARROWING STAGE made an infallible subject fallible — the build keyed on the parameter type (got '$out')" ;;
  esac
}

# ---------------------------------------------------------------------------
# probe — one module per shape.
# ---------------------------------------------------------------------------
probe() {
  local dir="$1"
  # THE VERDICT COMES FROM A COMPILE, NOT FROM `--api`. `--api` is a second
  # declaration pass through `exports_of/1` and never reaches `check/2`, so
  # every refusal in this roster is invisible to it — the first draft of this
  # gate read three accepted signatures where the compiler refuses the program.
  # A module that compiles has nothing to print, so its signature is then read
  # from `--api` and that is what the accepting verdicts are pinned to.
  emit() { # name, body
    mkdir -p "$dir/$1"
    printf '%s' "$2" > "$dir/$1/$1.bs"
    "$BSC" "$dir/$1/$1.bs" > "$dir/$1.compile" 2>&1 || true
    if grep -q 'error:' "$dir/$1.compile"; then
      cp "$dir/$1.compile" "$dir/$1.out"
    else
      "$BSC" --api "$dir/$1/$1.bs" > "$dir/$1.out" 2>&1 || true
    fi
  }

  emit V1 'module V1
type Maybe = int | :nothing
private Maybe Fetch(int id)
Fetch(0) -> :nothing
Fetch(n) -> n
private Maybe Double(int v)
Double(v) -> v * 2
public Maybe Load(int id)
Load(id) -> Fetch(id) |?> Double()
'
  emit V2 'module V2
type Res = int | (:error, atom)
private Res Start(int n)
Start(n) when n > 0  -> n
Start(n) when n <= 0 -> (:error, :bad)
private Res Charge(int v)
Charge(v) -> v * 2
public Res Place(int n)
Place(n) -> Start(n) |?> Charge()
'
  emit V3 'module V3
type Step3 = (:error, :bad) | :nothing | int
private Step3 Step(int id)
Step(1) -> 1
Step(2) -> :nothing
Step(id) -> (:error, :bad)
private int Use(int v)
Use(v) -> v
public Step3 Go(int id)
Go(id) -> Step(id) |?> Use()
'
  emit V4 'module V4
type Step3 = (:error, :bad) | :nothing | int
type Out3  = int | (:error, :bad)
private Step3 Step(int id)
Step(1) -> 1
Step(2) -> :nothing
Step(id) -> (:error, :bad)
private int Use(int v)
Use(v) -> v
public Out3 Go(int id)
Go(id) -> Step(id) |?> Use()
'
  emit V5 'module V5
private int Twice(int v)
Twice(v) -> v * 2
public int Run(int n)
Run(n) -> n |?> Twice()
'
  emit V6 'module V6
private binary Bytes(binary raw)
Bytes(b) -> b
private string Decode(string s)
Decode(s) -> s
public string Run(binary raw)
Run(raw) -> Bytes(raw) |?> Decode()
'
  emit V7 'module V7
type T    = :no | :nothing | :yes
type Rest = :no | :yes
private T Pick(int n)
Pick(1) -> :yes
Pick(2) -> :nothing
Pick(n) -> :no
private atom Name(Rest t)
Name(:no)  -> :saw_no
Name(:yes) -> :saw_yes
public atom Go(int n)
Go(n) -> Pick(n) |?> Name()
'
}

# ---------------------------------------------------------------------------
# --self-test — five defects and one correct form. Each is an implementation
# somebody would ship, and a check that fires on everything passes the red half
# and is worthless, so the green half is not optional.
#
#   error_only    nothing built — the state of master before F30. V1, V3 and V7
#                 are refused because their subjects carry no `(:error, _)`
#   nothing_only  the error arm REPLACED rather than joined. V1 passes and the
#                 whole of F14 breaks, which is why the error chain is a
#                 scenario here and not an assumption
#   param_keyed   the build reached for the stage's declared parameter type.
#                 Passes V1, V3, V4, V5 and V7 and fails on nothing but V6 —
#                 shape B arriving by the back door
#   silent_widen  the return type widens with no diagnostic. Every positive
#                 scenario passes; V4 is the only thing that sees it
#   stale_message the meet changed and `valve_on_infallible` did not. Every
#                 behavioural scenario passes and the author is told the
#                 compiler looked for one member when it looked for two
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  fail=0

  A1="$(expected_sig V1)"; A2="$(expected_sig V2)"
  A3="$(expected_sig V3)"; A7="$(expected_sig V7)"

  # The refusals, in the wording each defect produces.
  INFALL_BOTH="x.bs:1:1: error: this |?> in Run $CANNOT_FAIL
  int has no (:error, _) or :nothing member, so the valve would never stop."
  INFALL_OLD="x.bs:1:1: error: this |?> in Run $CANNOT_FAIL
  int has no (:error, _) member, so the valve would never stop."
  INFALL_BIN="x.bs:1:1: error: this |?> in Run $CANNOT_FAIL
  binary has no (:error, _) or :nothing member, so the valve would never stop."
  INFALL_V1="x.bs:1:1: error: this |?> in Load $CANNOT_FAIL
  :nothing | int has no (:error, _) member, so the valve would never stop."
  CORRECT_V4="x.bs:1:1: error: Go returns a value its signature does not declare
  not covered by the declared return type:
    :nothing
  $CORRECTED
    :nothing | int | (:error, :bad) Go(int)"
  # What V4 says when the `:nothing` arm does not exist: the member reaches the
  # stage instead of short-circuiting, so the complaint is about argument 1.
  ARG_V4="x.bs:1:1: error: argument 1 of Use is not accepted"
  ARG_V2="x.bs:1:1: error: argument 1 of Charge is not accepted"
  SIG_V4='int | (:error, :bad) Go(int)'
  SIG_V6='string Run(binary)'

  stub() { # name, then a verdict per module V1..V7
    local d="$W/$1"; shift
    mkdir -p "$d"
    local i=1 v
    for v in V1 V2 V3 V4 V5 V6 V7; do
      eval "printf '%s' \"\${$i}\"" > "$d/$v.out"
      i=$((i + 1))
    done
  }

  stub good          "$A1"        "$A2"     "$A3"        "$CORRECT_V4" "$INFALL_BOTH" "$INFALL_BIN" "$A7"
  stub error_only    "$INFALL_V1" "$A2"     "$INFALL_V1" "$ARG_V4"     "$INFALL_OLD"  "$INFALL_BIN" "$INFALL_V1"
  stub nothing_only  "$A1"        "$ARG_V2" "$A3"        "$CORRECT_V4" "$INFALL_BOTH" "$INFALL_BIN" "$A7"
  stub param_keyed   "$A1"        "$A2"     "$A3"        "$CORRECT_V4" "$INFALL_BOTH" "$SIG_V6"     "$A7"
  stub silent_widen  "$A1"        "$A2"     "$A3"        "$SIG_V4"     "$INFALL_BOTH" "$INFALL_BIN" "$A7"
  stub stale_message "$A1"        "$A2"     "$A3"        "$CORRECT_V4" "$INFALL_OLD"  "$INFALL_BIN" "$A7"

  for bad in error_only nothing_only param_keyed silent_widen stale_message; do
    if [ -z "$(judge "$W/$bad")" ]; then
      echo "  x SELF-TEST: '$bad' produced no complaint - the gate cannot see it"; fail=1
    else
      echo "  ok red on $bad"
    fi
  done
  if [ -n "$(judge "$W/good")" ]; then
    echo "  x SELF-TEST: the CORRECT set of verdicts was rejected -"; judge "$W/good"; fail=1
  else
    echo "  ok green on the correct form"
  fi
  [ "$fail" -eq 0 ] || { echo "self-test FAILED"; exit 1; }
  echo "self-test passed: five defects seen, correct form accepted"
  exit 0
fi

[ -x "$BSC" ] || { echo "no built bsc at $BSC - run rebar3 escriptize"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
probe "$W"
out="$(judge "$W")"
if [ -n "$out" ]; then echo "$out"; exit 1; fi
echo "  ok         4 valve shapes compile, 3 refusals stand incl. shape B's control"
