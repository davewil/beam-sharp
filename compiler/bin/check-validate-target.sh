#!/usr/bin/env bash
#
# F18 / ENG-347 — `ValidateAs<T>` REFUSES A TARGET WHOSE MEMBERS NO CLAUSE HEAD
# CAN TELL APART.
#
# Ticket 70 kept `list<map<string, int>> | list<map<string, binary>>` legal to
# DECLARE and put the objection in the advice. `ValidateAs<T>` over that type
# walked the term, worked out at run time which member arrived, and returned a
# type with nowhere to record the answer. The refusal is at the obligation site
# only: the declaration check (`discriminable/4`) is unchanged.
#
# THE PROBE IS A COMPILE, NOT `--api`. `ValidateAs<T>` is an expression, and
# `bsc --api` reads declarations only: a module whose body `ValidateAs<term>`
# refuses prints an API at exit 0, measured 2026-09-13. So this gate has one
# site where check-collapse.sh has two.
#
# WHY THREE REFUSALS. V1 is the ticket's own program. V2 writes `Any`'s pair
# inside the bracket, where no declaration pass looks, so reusing the
# declaration predicate at the obligation site catches V2 and nothing else —
# that is the `reachability` stub, the plausible fix that leaves the ticket's
# program compiling. V3 is the same defect in a tuple slot instead of a list.
#
# WHY THE ACCEPTS RUN THE FUNCTION. An accept asserted as an absence passes on
# a program that stopped compiling for an unrelated reason, so each one is
# asserted as the exact value `bsc` prints back. V5 is F18.18's pair, told apart
# by an `is_integer` guard on its first slot; V6 is `list<int> | list<atom>`,
# told apart by a guard on the first element; V7 differs only in its second
# slot and is told apart there.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

# Copied from `bs_diag:message/1`'s `validate_indiscriminable` clause.
MARK="validates into a union whose members no clause head can tell apart"

REFUSE="V1 V2 V3"
ACCEPT="V4 V5 V6 V7"

expected_value() {
  case "$1" in
    V4) echo '(:nums, [])' ;;
    V5) echo '(1, 2)' ;;
    V6) echo '[:a]' ;;
    V7) echo '(1, :a)' ;;
  esac
}

# ---------------------------------------------------------------------------
# judge — the gate's whole opinion, driven by --self-test against fixtures.
# ---------------------------------------------------------------------------
judge() {
  local dir="$1" v out want
  for v in $REFUSE; do
    out="$(cat "$dir/$v.out")"
    case "$out" in
      *"$MARK"*) ;;
      *) echo "$v: a target no clause head can take apart was ACCEPTED (got '$out')" ;;
    esac
  done
  for v in $ACCEPT; do
    out="$(cat "$dir/$v.out")"
    want="$(expected_value "$v")"
    case "$out" in
      *"$MARK"*) echo "$v: a target a clause head CAN take apart was refused (got '$out')" ;;
      "$want") ;;
      *) echo "$v: did not run to '$want' (got '$out') - asserted as a value, so an unrelated breakage lands here" ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# probe — one module per case. A refusal is compiled; an accept is run.
# ---------------------------------------------------------------------------
probe() {
  local dir="$1"
  emit() { # name, decls, return type, body type argument
    local lower
    lower="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
    mkdir -p "$dir/$1"
    { printf 'module %s\n\n' "$1"
      if [ -n "$2" ]; then printf '%s\n\n' "$2"; fi
      printf 'public %s Decode(term t)\n' "$3"
      printf 'Decode(t) -> ValidateAs<%s>(t)\n' "$4"
    } > "$dir/$1/$lower.bs"
  }
  emit V1 $'type Batch<T> = list<map<string, T>>\ntype Payload = Batch<int> | Batch<binary>' \
       'result<Payload, ValidationError>' 'Payload'
  emit V2 '' 'term' 'map<string, int> | map<string, binary>'
  emit V3 '' 'term' '(int, map<string, int>) | (int, map<string, binary>)'
  emit V4 $'type Batch<T> = list<map<string, T>>\ntype Payload = (:nums, Batch<int>) | (:text, Batch<binary>)' \
       'result<Payload, ValidationError>' 'Payload'
  emit V5 'type Pair = (int, int) | (atom, atom)' 'result<Pair, ValidationError>' 'Pair'
  emit V6 '' 'term' 'list<int> | list<atom>'
  emit V7 '' 'term' '(int, int) | (int, atom)'
  # Each accept is handed the value it must return: a valid term validates to
  # itself.
  (cd "$dir" &&
     for v in $REFUSE; do "$BSC" "$v" > "$v.out" 2>&1 || true; done &&
     for v in $ACCEPT; do
       "$BSC" "$v" Decode "$(expected_value "$v")" > "$v.out" 2>&1 || true
     done)
}

# ---------------------------------------------------------------------------
# --self-test — three defects and one correct form.
#
#   silent        nothing is refused - the state of master before ENG-347
#   reachability  the declaration predicate reused at the obligation site: V2
#                 is refused, V1 and V3 compile, because a list or a tuple
#                 pattern REACHES both members without separating them
#   cry_wolf      every union target is refused, V4-V7 too
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  fail=0
  ERR="X/x.bs:4:14: error: Decode $MARK"

  stub() { # name, then a verdict per case V1..V7
    local d="$W/$1"; shift
    mkdir -p "$d"
    local i=1 v
    for v in V1 V2 V3 V4 V5 V6 V7; do
      eval "printf '%s' \"\${$i}\"" > "$d/$v.out"
      i=$((i + 1))
    done
  }
  A4="$(expected_value V4)"; A5="$(expected_value V5)"
  A6="$(expected_value V6)"; A7="$(expected_value V7)"
  # What a refused case prints when it is compiled and not refused: nothing.
  C=''

  stub good         "$ERR" "$ERR" "$ERR" "$A4"  "$A5"  "$A6"  "$A7"
  stub silent       "$C"   "$C"   "$C"   "$A4"  "$A5"  "$A6"  "$A7"
  stub reachability "$C"   "$ERR" "$C"   "$A4"  "$A5"  "$A6"  "$A7"
  stub cry_wolf     "$ERR" "$ERR" "$ERR" "$ERR" "$ERR" "$ERR" "$ERR"

  for bad in silent reachability cry_wolf; do
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
  echo "self-test passed: three defects seen, correct form accepted"
  exit 0
fi

[ -x "$BSC" ] || { echo "no built bsc at $BSC - run rebar3 escriptize"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
probe "$W"
out="$(judge "$W")"
if [ -n "$out" ]; then echo "$out"; exit 1; fi
echo "  ok         3 targets no clause head can take apart refused, 4 that one can run unchanged"
