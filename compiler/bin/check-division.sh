#!/usr/bin/env bash
#
# `/` LOWERS TO `div`, NEVER TO ERLANG'S `/` — AND ONLY A PROVABLE ZERO IS REFUSED.
#
# Ticket 38 decided two things that fail in opposite directions, which is why
# this gate has four probes and its self-test builds three defects.
#
# THE EMISSION. `/` on two `int`s is truncated integer division, and emission
# maps it to Erlang's `div` and *never* its `/`, which is float division. The
# failure is silent in the worst way: `7 / 2` under Erlang's `/` is `3.5`, a
# FLOAT where the signature promised `int`, and nothing in the type system sees
# it because the emitter is downstream of the checker. Measured on OTP 28:
# `-7 div 2` is `-3`, `-7 / 2` is `-3.5`. So the probe asserts the VALUE and
# gets the emission for free — there is no way to pass it while emitting `/`.
#
# THE PRECONDITION, AND THE FACT THAT THERE ISN'T ONE. A divisor needs no proof
# that it is non-zero: `Mean(total, count) -> total / count` compiles, and a
# zero at run time crashes, which is ticket 12's stance rather than a gap. Only
# a divisor the compiler *proves* is zero is refused. That rule fails two ways —
# not firing at all, and firing on every literal divisor — and a gate that
# checked only the first would pass a compiler that refused `n / 2`. Hence P4,
# and hence the third self-test stub.
#
# WHY A GATE AND NOT ONLY EUNIT. The eunit suite asserts the same values and
# would catch the emission defect. This exists for the pair of rules in P3/P4,
# which are a DIAGNOSTIC's presence and its absence: this repo has twice shipped
# a check that asserted an absence against a run that never compiled, so the
# absence half is asserted against a compile that is otherwise clean.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

# ---------------------------------------------------------------------------
# judge — the whole of the gate's opinion, in one place. Takes a directory so
# --self-test drives THIS code path against fixtures rather than a copy of it.
# ---------------------------------------------------------------------------
judge() {
  local dir="$1" p1 p2 p3 p4
  p1="$(cat "$dir/P1.out")"; p2="$(cat "$dir/P2.out")"
  p3="$(cat "$dir/P3.out")"; p4="$(cat "$dir/P4.out")"

  [ "$p1" = "-3" ] || \
    echo "P1: -7 / 2 gave '$p1', wanted -3 — a float means the emitter reached for Erlang's /"
  [ "$p2" = "-1" ] || \
    echo "P2: -7 % 2 gave '$p2', wanted -1 — the remainder must be signed by the dividend"
  ## Matched on the USER-VISIBLE message, not the internal tag. The eunit suite
  ## already asserts the tag; what a gate is for is the text a person reads, and
  ## the first draft of this line grepped for `divide_by_zero` and went red
  ## against a compiler that was refusing the program correctly.
  case "$p3" in
    *"is always zero"*) ;;
    *) echo "P3: a provably zero divisor was not refused (got '$p3')" ;;
  esac
  case "$p4" in
    *error*) echo "P4: the zero check fired on a NON-zero literal divisor (got '$p4')" ;;
    *) ;;
  esac
}

## Each module gets a directory of its own NAME, not a shared `src/`: F15 makes a
## module's declaration and its path the same name written twice, so `module G`
## under `src/` is refused before any of this gate's opinions are reached. The
## first draft did exactly that and every probe reported the path diagnostic
## instead of a quotient — which the gate caught, correctly, by going red.
probe() {
  local dir="$1"
  mkdir -p "$dir/G" "$dir/Z" "$dir/H"
  printf 'module G\n\npublic int Slash(int a, int b)\nSlash(a, b) -> a / b\n\npublic int Pct(int a, int b)\nPct(a, b) -> a %% b\n' > "$dir/G/G.bs"
  printf 'module Z\n\npublic int Go(int n)\nGo(n) -> n / 0\n' > "$dir/Z/Z.bs"
  printf 'module H\n\npublic int Go(int n)\nGo(n) -> n / 2\n' > "$dir/H/H.bs"
  "$BSC" "$dir/G/G.bs" Slash -7 2 > "$dir/P1.out" 2>&1 || true
  "$BSC" "$dir/G/G.bs" Pct   -7 2 > "$dir/P2.out" 2>&1 || true
  "$BSC" "$dir/Z/Z.bs" Go     1   > "$dir/P3.out" 2>&1 || true
  "$BSC" "$dir/H/H.bs" Go     8   > "$dir/P4.out" 2>&1 || true
}

# ---------------------------------------------------------------------------
# --self-test — three defects and one correct form. A check that fires on
# everything passes the red half and is worthless, so the green half is not
# optional. The third stub is the CRY-WOLF: a rule that refuses every literal
# divisor satisfies P3 and is still wrong.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  fail=0
  stub() {
    mkdir -p "$W/$1"
    printf '%s' "$2" > "$W/$1/P1.out"; printf '%s' "$3" > "$W/$1/P2.out"
    printf '%s' "$4" > "$W/$1/P3.out"; printf '%s' "$5" > "$W/$1/P4.out"
  }
  stub good      "-3"   "-1" "error: the right-hand side of \`/\` in Go is always zero" "4"
  stub float_div "-3.5" "-1" "error: the right-hand side of \`/\` in Go is always zero" "4"
  stub no_check  "-3"   "-1" "crashed: error:badarith"                                 "4"
  stub cry_wolf  "-3"   "-1" "error: the right-hand side of \`/\` in Go is always zero" \
                             "error: the right-hand side of \`/\` in Go is always zero"

  for bad in float_div no_check cry_wolf; do
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
  echo "self-test passed: three defects seen, correct form accepted"
  exit 0
fi

[ -x "$BSC" ] || { echo "no built bsc at $BSC - run rebar3 escriptize"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
probe "$W"
out="$(judge "$W")"
if [ -n "$out" ]; then echo "$out"; exit 1; fi
echo "  ok         / lowers to div, % is signed by the dividend, only a provable zero is refused"
