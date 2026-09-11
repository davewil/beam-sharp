#!/usr/bin/env bash
#
# A CALL IN A GUARD IS REFUSED IN B#'S VOICE, NEVER IN ERLANG'S.
#
# ENG-256. Probe 63b put a user function call in a guard — `Check(u) when
# IsAdmin(u) == :yes` — and the author was shown the Erlang compiler's own
# report, relayed verbatim under a `compile:` prefix:
#
#     compile: .../guardprobe.bs:21:15: call to local/imported function 'IsAdmin'/1 is illegal in guard
#     %   21| Check(u) when IsAdmin(u) == :yes -> :admin
#
# That text is in no diagnostic term, has no tag, cannot reach `--diagnostics
# term` or `--api` (F16, F17), spells the function as `'IsAdmin'/1`, and leaks
# the Erlang Abstract Format target (ticket 13). The refusal itself is right:
# Erlang admits only its guard BIFs in a guard, and ticket 63 Q4 left that
# inherited. The defect is who says so and how.
#
# WHY SIX REFUSAL PROBES AND NOT ONE. 63d (`wayfinder/prototypes/63d_erlc_leak_sweep/`)
# measured the class: every call form the grammar admits into a guard leaks —
# a local call, the same call in a SWITCH-ARM guard (classified by a different
# walk in `bs_check`, which is how a refusal wired at the clause has missed the
# arm before), a qualified call to a sibling B# module, a foreign call to a
# function that is NOT a guard BIF, a pipe (which lowers to a local call before
# the checker runs), and `ValidateAs<T>(x)`, which leaked the compiler's own
# mangled name `bs@validate@1@r/1`. A gate keyed on 63b's one case would be
# green with five of these still leaking.
#
# WHY TWO CONTROLS. P7 is a foreign call to `:erlang.byte_size`, which IS a
# BEAM guard BIF and compiles today: the plausible-but-wrong fix refuses every
# foreign call in a guard, and P7 is the program that fix breaks. P8 is the
# comparison guard 63b used as its control. Both must compile AND RUN, with
# their value asserted exactly — this repo has shipped a check that asserted
# an absence against a run that never compiled.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

RELAY="compile:"

# ---------------------------------------------------------------------------
# judge — the whole of the gate's opinion, in one place, so --self-test drives
# THIS code path against fixtures rather than a copy of it.
# ---------------------------------------------------------------------------
judge() {
  local dir="$1" p
  # P1-P6: refused, in B#'s voice, with the callee spelled as the author wrote it.
  refused() {
    local n="$1" want="$2" got
    got="$(cat "$dir/P$n.out")"
    case "$got" in
      *"$RELAY"*)
        echo "P$n: the Erlang compiler's report reached the author (got '$got') — a \`$RELAY\` line is the relay in bsc.erl, not a B# diagnostic" ;;
      *"$want"*) ;;
      *) echo "P$n: not refused as '$want' (got '$got')" ;;
    esac
  }
  refused 1 "Check calls IsAdmin in a guard"
  refused 2 "Check calls IsAdmin in a guard"
  refused 3 "Check calls Helper.IsAdmin in a guard"
  refused 4 "Check calls :string.length in a guard"
  refused 5 "Check calls IsAdmin in a guard"
  refused 6 "Check calls ValidateAs in a guard"
  # P7: a foreign GUARD BIF in a guard is legal — inherited from the BEAM, not
  # refused with the rest. EXACT: a diagnostic about this program would name
  # `:long` too.
  p="$(cat "$dir/P7.out")"
  case "$p" in
    ":long") ;;
    *"in a guard"*) echo "P7: a foreign call to a BEAM guard BIF was REFUSED (got '$p') — the fix refused every foreign call, and \`:erlang.byte_size\` is legal in a guard" ;;
    *) echo "P7: the guard-BIF control did not compile and run (got '$p', wanted exactly ':long')" ;;
  esac
  # P8: the comparison control.
  p="$(cat "$dir/P8.out")"
  case "$p" in
    ":admin") ;;
    *) echo "P8: the comparison control did not compile and run (got '$p', wanted exactly ':admin') — the probes above measured nothing" ;;
  esac
}

probe() {
  local dir="$1"
  mkdir -p "$dir/P1" "$dir/P2" "$dir/P3/Helper" "$dir/P4" "$dir/P5" "$dir/P6" "$dir/P7" "$dir/P8"
  # P1 — a local call in a clause guard (63b).
  printf 'module P1\n\npublic atom IsAdmin(int u)\nIsAdmin(1) -> :yes\nIsAdmin(_) -> :no\n\npublic atom Check(int u)\nCheck(u) when IsAdmin(u) == :yes -> :admin\nCheck(_) -> :ordinary\n' > "$dir/P1/p1.bs"
  # P2 — the same call in a switch-arm guard.
  printf 'module P2\n\npublic atom IsAdmin(int u)\nIsAdmin(1) -> :yes\nIsAdmin(_) -> :no\n\npublic atom Check(int u)\nCheck(u) -> u switch {\n    n when IsAdmin(n) == :yes => :admin,\n    _ => :ordinary\n}\n' > "$dir/P2/p2.bs"
  # P3 — a qualified call to a sibling module.
  printf 'module P3.Helper\n\npublic atom IsAdmin(int u)\nIsAdmin(1) -> :yes\nIsAdmin(_) -> :no\n' > "$dir/P3/Helper/helper.bs"
  printf 'module P3\n\npublic atom Check(int u)\nCheck(u) when Helper.IsAdmin(u) == :yes -> :admin\nCheck(_) -> :ordinary\n' > "$dir/P3/p3.bs"
  # P4 — a foreign call to a function that is NOT a guard BIF.
  printf 'module P4\n\nusing :string {\n    int length(binary s)\n}\n\npublic atom Check(binary s)\nCheck(s) when :string.length(s) > 2 -> :long\nCheck(_) -> :short\n' > "$dir/P4/p4.bs"
  # P5 — a pipe, which lowers to a local call before the checker.
  printf 'module P5\n\npublic atom IsAdmin(int u)\nIsAdmin(1) -> :yes\nIsAdmin(_) -> :no\n\npublic atom Check(int u)\nCheck(u) when (u |> IsAdmin()) == :yes -> :admin\nCheck(_) -> :ordinary\n' > "$dir/P5/p5.bs"
  # P6 — the instantiation bracket, which leaked a mangled internal name.
  printf 'module P6\n\npublic atom Check(term t)\nCheck(t) when ValidateAs<int>(t) == (:ok, 1) -> :one\nCheck(_) -> :other\n' > "$dir/P6/p6.bs"
  # P7 — CONTROL: a foreign call to a BEAM guard BIF. Compiles and runs.
  printf 'module P7\n\nusing :erlang {\n    int byte_size(binary b)\n}\n\npublic atom Check(binary b)\nCheck(b) when :erlang.byte_size(b) > 2 -> :long\nCheck(_) -> :short\n' > "$dir/P7/p7.bs"
  # P8 — CONTROL: the comparison guard. Compiles and runs.
  printf 'module P8\n\npublic atom Check(int u)\nCheck(u) when u == 1 -> :admin\nCheck(_) -> :ordinary\n' > "$dir/P8/p8.bs"
  local n
  for n in 1 2 3 4 5 6; do
    "$BSC" --src-root "$dir" "$dir/P$n" > "$dir/P$n.out" 2>&1 || true
  done
  "$BSC" --src-root "$dir" "$dir/P7" Check '"abcd"' > "$dir/P7.out" 2>&1 || true
  "$BSC" --src-root "$dir" "$dir/P8" Check 1 > "$dir/P8.out" 2>&1 || true
}

# ---------------------------------------------------------------------------
# --self-test — six defects and one correct form. A check that fires on
# everything passes the red half and is worthless, so the green half is not
# optional.
#
#   leak         today's text: the Erlang compiler's report, relayed
#   silent       nothing refuses — the six probes compile
#   wrong        refused, but as a different B# diagnostic
#   half         the clause is refused and the switch arm still leaks — the
#                defect a refusal wired only in the clause walk produces
#   bif_refused  every foreign call refused, including the guard BIF (P7)
#   cry_wolf     the comparison control is refused too
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  fail=0
  BODY="  a guard asks a question about the values a clause already
  matched; it cannot call a function. Move the call into the
  body and switch on its answer."
  LOCAL="p1.bs:8:15: error: Check calls IsAdmin in a guard
$BODY"
  ARM="p2.bs:9:12: error: Check calls IsAdmin in a guard
$BODY"
  QUAL="p3.bs:4:21: error: Check calls Helper.IsAdmin in a guard
$BODY"
  FOREIGN="p4.bs:8:15: error: Check calls :string.length in a guard
  only the BEAM's own guard functions may run in a guard, and
  \`:string.length\` is not one of them. Move the call into the
  body and switch on its answer."
  PIPE="p5.bs:8:18: error: Check calls IsAdmin in a guard
$BODY"
  INST="p6.bs:4:15: error: Check calls ValidateAs in a guard
$BODY"
  RAW1="compile: p1.bs:8:15: call to local/imported function 'IsAdmin'/1 is illegal in guard
%    8| Check(u) when IsAdmin(u) == :yes -> :admin
%     |               ^"
  RAW2="compile: p2.bs:9:12: call to local/imported function 'IsAdmin'/1 is illegal in guard"
  RAW3="compile: p3.bs:4:21: illegal guard expression"
  RAW4="compile: p4.bs:8:15: illegal guard expression"
  RAW5="compile: p5.bs:8:18: call to local/imported function 'IsAdmin'/1 is illegal in guard"
  RAW6="compile: p6.bs:4:15: call to local/imported function bs@validate@1@r/1 is illegal in guard"
  SWITCH="p1.bs:8:15: error: Check has a switch in a guard"
  BIFNO="p7.bs:8:15: error: Check calls :erlang.byte_size in a guard"
  CTLNO="p8.bs:4:15: error: Check calls u in a guard"
  stub() {
    mkdir -p "$W/$1"
    printf '%s' "$2" > "$W/$1/P1.out"; printf '%s' "$3" > "$W/$1/P2.out"
    printf '%s' "$4" > "$W/$1/P3.out"; printf '%s' "$5" > "$W/$1/P4.out"
    printf '%s' "$6" > "$W/$1/P5.out"; printf '%s' "$7" > "$W/$1/P6.out"
    printf '%s' "$8" > "$W/$1/P7.out"; printf '%s' "$9" > "$W/$1/P8.out"
  }
  stub good        "$LOCAL" "$ARM"  "$QUAL" "$FOREIGN" "$PIPE" "$INST" ":long" ":admin"
  stub leak        "$RAW1"  "$RAW2" "$RAW3" "$RAW4"    "$RAW5" "$RAW6" ":long" ":admin"
  stub silent      ":admin" ":admin" ":admin" ":long"  ":admin" ":one" ":long" ":admin"
  stub wrong       "$SWITCH" "$SWITCH" "$SWITCH" "$SWITCH" "$SWITCH" "$SWITCH" ":long" ":admin"
  stub half        "$LOCAL" "$RAW2" "$QUAL" "$FOREIGN" "$PIPE" "$INST" ":long" ":admin"
  stub bif_refused "$LOCAL" "$ARM"  "$QUAL" "$FOREIGN" "$PIPE" "$INST" "$BIFNO" ":admin"
  stub cry_wolf    "$LOCAL" "$ARM"  "$QUAL" "$FOREIGN" "$PIPE" "$INST" ":long" "$CTLNO"

  for bad in leak silent wrong half bif_refused cry_wolf; do
    if [ -z "$(judge "$W/$bad")" ]; then
      echo "  x SELF-TEST: '$bad' produced no complaint - the gate cannot see it"; fail=1
    else
      echo "  ok red on $bad"
    fi
  done
  if [ -n "$(judge "$W/good")" ]; then
    echo "  x SELF-TEST: the CORRECT form was rejected -"; judge "$W/good"; fail=1
  else
    echo "  ok green on the correct form"
  fi
  [ "$fail" -eq 0 ] || { echo "self-test FAILED"; exit 1; }
  echo "self-test passed: six defects seen, correct form accepted"
  exit 0
fi

[ -x "$BSC" ] || { echo "no built bsc at $BSC - run rebar3 escriptize"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
probe "$W"
out="$(judge "$W")"
if [ -n "$out" ]; then echo "$out"; exit 1; fi
echo "  ok         every call form in a guard is refused in B#'s voice; a guard BIF and a comparison still run"
