#!/usr/bin/env bash
#
# F31 / ENG-272 — A DECLARED FAILURE CHANNEL MUST SURVIVE NORMALISATION.
#
# Ticket 15 §1 refused `option<atom>` AT THE DECLARATION and F18 built the
# predicate at the `ValidateAs<T>` obligation site only. `bs_diag.erl:280` says
# so out loud — "ticket 15 §1's collapse, met at an instantiation rather than at
# a declaration" — and that sentence was the whole gap. Ticket 49 accepted the
# valve's shape-C exposure ON THE GROUNDS that this refusal exists, and
# `PRELUDE.md:108` records `ToExistingAtom` as owed for the same reason. Two
# documents leaned on a check the compiler did not have.
#
# WHY ELEVEN SHAPES AND NOT ONE. 15 §1 names its own wrong implementation:
# "stated as absorption by an atom top it would cover only `option<atom>` and an
# implementer would write the cofinite check alone". Two measured cases defeat
# that implementation and both are here as controls:
#
#     S4  option<option<int>>             ->  :nothing | int    no atom top anywhere
#     S8  result<(atom, binary), binary>  ->  (atom, binary)    a TUPLE-shape collision
#
# S9 is the third control and it defeats a different wrong implementation: one
# keyed on the SPELLING `option<...>`. A hand-written `type M = atom | :nothing`
# is the same type, and it is the spelling `ToExistingAtom` is written in.
#
# WHY THE ACCEPTS ASSERT A SIGNATURE AND NOT AN ABSENCE. This repo has shipped a
# check that asserted a message was missing against a run that never compiled.
# Every accepting shape here is asserted as the EXACT `--api` line it must
# produce, so a shape that stops compiling for an unrelated reason goes red
# instead of passing quietly. S10 in particular must stay legal: it is ticket
# 48's `Map.Fetch` shape, chosen BECAUSE it does not collapse.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

MARK="the failure channel does not survive normalisation"

# The shapes that must be REFUSED, and the shapes that must be ACCEPTED with the
# exact signature each one normalises to. Kept as two lists so the judge cannot
# accidentally treat a missing file as a pass.
REFUSE="S3 S4 S5 S7 S8 S9"
ACCEPT="S1 S2 S6 S10 S11"

expected_sig() {
  case "$1" in
    S1)  echo ':nothing | int Go(int)' ;;
    S2)  echo ':false | :nothing | :true Go(int)' ;;
    S6)  echo 'int | (:error, binary) Go(int)' ;;
    S10) echo ':absent | (:ok, term) Go(int)' ;;
    S11) echo 'atom | (:error, binary) Go(int)' ;;
  esac
}

# ---------------------------------------------------------------------------
# judge — the whole of the gate's opinion in one place, so --self-test drives
# THIS code path against fixtures rather than a copy of it.
# ---------------------------------------------------------------------------
judge() {
  local dir="$1" s out want
  for s in $REFUSE; do
    out="$(cat "$dir/$s.out")"
    case "$out" in
      *"$MARK"*) ;;
      *) echo "$s: a collapsing declaration was ACCEPTED (got '$out')" ;;
    esac
  done
  for s in $ACCEPT; do
    out="$(cat "$dir/$s.out")"
    want="$(expected_sig "$s")"
    case "$out" in
      *"$MARK"*) echo "$s: a SURVIVING failure channel was refused (got '$out')" ;;
      *"$want"*) ;;
      *) echo "$s: did not compile to '$want' (got '$out') - asserted as a signature, not as an absence, so an unrelated breakage lands here" ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# probe — one module per shape. The declared type is a function RETURN, which is
# the position ENG-272 measured; the five declaration forms are covered by
# `collapse_tests.erl`, because a gate that walked all five would be asserting
# the same predicate five times over.
# ---------------------------------------------------------------------------
probe() {
  local dir="$1"
  emit() { # name, return-type, extra-decl
    mkdir -p "$dir/$1"
    { printf 'module %s\n\n' "$1"
      if [ -n "$3" ]; then printf '%s\n\n' "$3"; fi
      printf 'public %s Go(int id)\n' "$2"
      printf 'Go(id) -> :nothing\n'
    } > "$dir/$1/$1.bs"
    "$BSC" --api "$dir/$1/$1.bs" > "$dir/$1.out" 2>&1 || true
  }
  emit S1  'option<int>'                    ''
  emit S2  'option<bool>'                   ''
  emit S3  'option<atom>'                   ''
  emit S4  'option<option<int>>'            ''
  emit S5  'option<term>'                   ''
  emit S6  'result<int, binary>'            ''
  emit S7  'result<term, binary>'           ''
  emit S8  'result<(atom, binary), binary>' ''
  emit S9  'M'                              'type M = atom | :nothing'
  emit S10 'F'                              'type F = (:ok, term) | :absent'
  emit S11 'R'                              'type R = atom | (:error, binary)'
}

# ---------------------------------------------------------------------------
# --self-test — four defects and one correct form. A check that fires on
# everything passes the red half and is worthless, so the green half is not
# optional.
#
#   silent        nothing is refused - the state of master before F31
#   atom_top      the cofinite check alone: S3/S5/S7 refused, S4/S8 missed.
#                 This is the wrong fix ticket 15 §1 NAMES, and it is the reason
#                 S4 and S8 are in the roster at all
#   spelling      keyed on `option<...>`/`result<...>`: S9, the hand-written
#                 alias, walks through - and that is `ToExistingAtom`'s spelling
#   cry_wolf      every union with two members is refused, S1/S2/S6/S10/S11 too
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  fail=0
  ERR="X.bs:3: error: \`:nothing\` is absorbed by \`atom\`; $MARK"

  stub() { # name, then a verdict per shape in the order below
    local d="$W/$1"; shift
    mkdir -p "$d"
    local i=1
    for s in S1 S2 S3 S4 S5 S6 S7 S8 S9 S10 S11; do
      eval "printf '%s' \"\${$i}\"" > "$d/$s.out"
      i=$((i + 1))
    done
  }
  A1="$(expected_sig S1)"; A2="$(expected_sig S2)"; A6="$(expected_sig S6)"
  A10="$(expected_sig S10)"; A11="$(expected_sig S11)"
  # The signatures the COLLAPSING shapes produce today, i.e. when not refused.
  C3='atom Go(int)'; C4=':nothing | int Go(int)'; C5='term Go(int)'
  C7='term Go(int)'; C8='(atom, binary) Go(int)'; C9='atom Go(int)'

  stub good     "$A1" "$A2" "$ERR" "$ERR" "$ERR" "$A6" "$ERR" "$ERR" "$ERR" "$A10" "$A11"
  stub silent   "$A1" "$A2" "$C3"  "$C4"  "$C5"  "$A6" "$C7"  "$C8"  "$C9"  "$A10" "$A11"
  stub atom_top "$A1" "$A2" "$ERR" "$C4"  "$ERR" "$A6" "$ERR" "$C8"  "$ERR" "$A10" "$A11"
  stub spelling "$A1" "$A2" "$ERR" "$ERR" "$ERR" "$A6" "$ERR" "$ERR" "$C9"  "$A10" "$A11"
  stub cry_wolf "$ERR" "$ERR" "$ERR" "$ERR" "$ERR" "$ERR" "$ERR" "$ERR" "$ERR" "$ERR" "$ERR"

  for bad in silent atom_top spelling cry_wolf; do
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
  echo "self-test passed: four defects seen, correct form accepted"
  exit 0
fi

[ -x "$BSC" ] || { echo "no built bsc at $BSC - run rebar3 escriptize"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
probe "$W"
out="$(judge "$W")"
if [ -n "$out" ]; then echo "$out"; exit 1; fi
echo "  ok         6 collapsing declarations refused, 5 surviving ones compile unchanged"
