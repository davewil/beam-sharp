#!/usr/bin/env bash
#
# THE CHECKER MUST SEE A LIST'S LENGTH — IN BOTH DIRECTIONS.
#
# Ticket 54: `Shape([])` beside `Shape([a, b, ..])` was proved exhaustive and
# crashed on `[7]`, because a cons pattern was subtracted as *non-empty*
# whatever its prefix. The same root ran the other way too: a closed-length
# clause subtracted nothing at all, so `[]`, `[]`+`[a]`, and `[]`+`[a]`+`[a, b]`
# left the identical residual.
#
# THE TWO DIRECTIONS HAVE ONE ROOT AND GET FIXED INDEPENDENTLY. That is the
# whole reason this gate exists and the whole reason its self-test builds two
# defects rather than one — a fix that removes the crash and leaves the closed
# form invisible is a fix that hides the other half, and it would pass a
# one-stub control.
#
# WHY A GATE AND NOT A `<!-- check: -->` BLOCK IN LANGUAGE.md. Measured: `bsc`
# exits 0 on a module whose only diagnostic is a warning. A doc block asserts
# that a block compiles, so it cannot distinguish "compiles clean" from
# "compiles with a warning" — and probe 3 below is the *absence* of a warning.
# No doc block can express it.
#
# The three probes are asserted on the DIAGNOSTIC, never on the exit code. A
# residual that merely refuses is candidate 1; a residual that names `[n]` is
# the decision ticket 54 actually took.
#
# THE ELEMENT IS SPELLED `n` AND NOT `int`. Corrected 2026-08-27 when F29 landed.
# This gate asserted `Shape([int])`, and `int` is lowercase in pattern position —
# so that head bound a VARIABLE NAMED int, and only compiled correctly because
# `list<int>` already constrains the element. F29's `OpenList` fixture was filed
# on exactly that, and the head is now `Shape([n])`: an honest binder.
#
# What this gate measures is untouched. Ticket 54's decision is the LENGTH
# distinction — `[n]` is a list of exactly one and `[n, ..]` is one or more — and
# the self-test's under-subtracting stub still separates them. Only the element's
# spelling moved.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

# ---------------------------------------------------------------------------
# judge — the whole of the gate's opinion, in one place.
#
# Reads P1.out, P2.out, P3.out from a directory and prints one line per
# violation. Kept as a function taking a directory so --self-test can point it
# at fixtures and exercise THIS code path rather than a copy of it.
# ---------------------------------------------------------------------------
judge() {
  local dir="$1"
  local p1 p2 p3
  p1="$(cat "$dir/P1.out")"
  p2="$(cat "$dir/P2.out")"
  p3="$(cat "$dir/P3.out")"

  # PROBE 1 — over-subtraction, which is the crash.
  #
  #   Shape([])         -> :empty
  #   Shape([a, b, ..]) -> :many
  #
  # A two-element prefix matches lists of length >= 2, so a one-element list
  # matches nothing. Two assertions, and the second is the one that separates
  # this decision from a cheaper one: refusing is not enough, the residual has
  # to NAME the missing case as `[n]`.
  if grep -q 'syntax error\|illegal characters' <<<"$p1"; then
    echo "probe 1: did not compile, so nothing was measured. it said:"
    sed 's/^/           /' <<<"$p1"
  elif ! grep -q 'not exhaustive' <<<"$p1"; then
    echo "probe 1: [] + [a, b, ..] was accepted as exhaustive — it crashes on [7]"
  elif ! grep -qF 'Shape([n]) ->' <<<"$p1"; then
    echo "probe 1: reported inexhaustive but did not name the missing case as [n]."
    echo "         the residual has to be a clause you can paste. it said:"
    sed 's/^/           /' <<<"$p1"
  fi

  # PROBE 2 — under-subtraction, and the probe that keeps this gate honest.
  #
  #   Shape([])         -> :empty
  #   Shape([a])        -> :one
  #   Shape([a, b, ..]) -> :many
  #
  # Exactly-one, plus exactly-nothing, plus two-or-more, is every list. A
  # checker that credits a closed spine with nothing never reaches empty here.
  #
  # THIS IS THE PROBE A FIRES-ON-EVERYTHING CHECK FAILS. Probes 1 and 3 both
  # demand that something be reported or not reported about a *broken* clause
  # set; this one demands silence about a correct one.
  if [ -n "$p2" ]; then
    echo "probe 2: [] + [a] + [a, b, ..] is every list, and the compiler complained:"
    sed 's/^/           /' <<<"$p2"
  fi

  # PROBE 3 — symptom five, which no doc block can assert.
  #
  #   Shape([])         -> :empty
  #   Shape([a, b, ..]) -> :many
  #   Shape([a, ..])    -> :one
  #
  # Clause 3 is the ONLY clause matching a one-element list. Before ticket 54
  # the compiler called it unreachable while `erlc` stayed silent and the
  # program returned `:one` — a correct clause told it was dead. A fleet
  # implementing from the spec deletes it.
  #
  # AND THE ABSENCE IS ASSERTED AGAINST A CLEAN COMPILE, NOT AGAINST SILENCE.
  # Measured while building this gate: before the marker grammar landed, P3 did
  # not parse, so there was no `unreachable` in its output and this probe went
  # GREEN over a module that had never been checked. That is the vacuous pass
  # `check-no-silent-skip.sh` exists for, one level up — a probe asserting that
  # something is absent passes for free the moment the run dies earlier. So the
  # requirement is that P3 compiles CLEAN, and `unreachable` is named separately
  # because it is the symptom worth its own sentence.
  if grep -q 'unreachable' <<<"$p3"; then
    echo "probe 3: clause 3 matches [7] and nothing before it does, but it was"
    echo "         called unreachable. the compiler is telling a correct program"
    echo "         it is wrong. it said:"
    sed 's/^/           /' <<<"$p3"
  elif [ -n "$p3" ]; then
    echo "probe 3: [] + [a, b, ..] + [a, ..] should compile clean, and did not."
    echo "         an absent warning proves nothing if the run died first. it said:"
    sed 's/^/           /' <<<"$p3"
  fi
}

# ---------------------------------------------------------------------------
# --self-test
#
# TWO DEFECTS, NOT ONE, AND A CORRECT CONTROL BESIDE THEM.
#
#   OVER   every cons subtracts all non-empty lists, whatever its prefix and
#          whether or not it is closed. This is the compiler as ticket 54 found
#          it. It fails probes 1 and 3 — and PASSES probe 2.
#
#   UNDER  a cons subtracts nothing at all. The obvious over-correction from
#          fixing the crash by refusing to credit anything. It fails probes 1
#          and 2 — and PASSES probe 3.
#
#   GOOD   the decided behaviour. Must pass all three.
#
# The two stubs fail on DIFFERENT probes, and the gate is only believed if it
# catches each one AND lets each one's other probe through. A check that fired
# on everything would catch both stubs, pass the naive half of this control, and
# be worthless — which is `check-shell.sh`'s lesson from ticket 15, written at a
# severity where the tree was already clean.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  fail=0

  # --- OVER --------------------------------------------------------------
  mkdir -p "$CTL/over"
  : > "$CTL/over/P1.out"                     # silent: the crash goes unreported
  : > "$CTL/over/P2.out"                     # silent: correct, by accident
  cat > "$CTL/over/P3.out" <<'OUT'
P3/P3.bs:5: warning: clause 3 of Shape is unreachable
  every value it matches is matched by an earlier clause.
OUT
  over="$(judge "$CTL/over" || true)"
  grep -q '^probe 1:' <<<"$over" || { echo "SELF-TEST FAILED: probe 1 missed the over-subtracting stub — the crash"; fail=1; }
  grep -q '^probe 3:' <<<"$over" || { echo "SELF-TEST FAILED: probe 3 missed the over-subtracting stub — the false unreachable"; fail=1; }
  if grep -q '^probe 2:' <<<"$over"; then
    echo "SELF-TEST FAILED: probe 2 fired on the over-subtracting stub, which it should pass."
    echo "                  a probe that fires on everything proves nothing."
    fail=1
  fi

  # --- UNDER -------------------------------------------------------------
  mkdir -p "$CTL/under"
  cat > "$CTL/under/P1.out" <<'OUT'
P1/P1.bs:2: error: Shape is not exhaustive
  no clause matches:
    Shape([n, ..]) -> ...
OUT
  cat > "$CTL/under/P2.out" <<'OUT'
P2/P2.bs:2: error: Shape is not exhaustive
  no clause matches:
    Shape([n, ..]) -> ...
OUT
  : > "$CTL/under/P3.out"                    # nothing subtracted, so nothing is unreachable
  under="$(judge "$CTL/under" || true)"
  grep -q '^probe 1:' <<<"$under" || { echo "SELF-TEST FAILED: probe 1 accepted a residual of [n, ..] where the answer is [n]"; fail=1; }
  grep -q '^probe 2:' <<<"$under" || { echo "SELF-TEST FAILED: probe 2 missed the under-subtracting stub — the invisible closed clause"; fail=1; }
  if grep -q '^probe 3:' <<<"$under"; then
    echo "SELF-TEST FAILED: probe 3 fired on the under-subtracting stub, which it should pass."
    echo "                  a probe that fires on everything proves nothing."
    fail=1
  fi

  # --- GOOD --------------------------------------------------------------
  mkdir -p "$CTL/good"
  cat > "$CTL/good/P1.out" <<'OUT'
P1/P1.bs:2: error: Shape is not exhaustive
  no clause matches:
    Shape([n]) -> ...
OUT
  : > "$CTL/good/P2.out"
  : > "$CTL/good/P3.out"
  good="$(judge "$CTL/good" || true)"
  if [ -n "$good" ]; then
    echo "SELF-TEST FAILED: the gate rejected the decided behaviour:"
    sed 's/^/                  /' <<<"$good"
    fail=1
  fi

  # --- BROKEN ------------------------------------------------------------
  #
  # NOTHING COMPILES. This control is here because the gate failed it: on the
  # first real run, before the marker grammar existed, `[a, b, ..]` did not
  # parse — and probe 3, which asserts that no `unreachable` warning appears,
  # found no warning in a parse error and reported GREEN over a module that had
  # never been checked. Two of three probes were vacuous and the gate still
  # looked like it was working, because probe 1 happened to be red anyway.
  #
  # A probe that asserts an ABSENCE must assert it against a run that happened.
  mkdir -p "$CTL/broken"
  for f in P1 P2 P3; do
    cat > "$CTL/broken/$f.out" <<OUT
$f/$f.bs:7: error: syntax error before: ']'
OUT
  done
  broken="$(judge "$CTL/broken" || true)"
  for n in 1 2 3; do
    grep -q "^probe $n:" <<<"$broken" || {
      echo "SELF-TEST FAILED: probe $n went green over a module that did not compile."
      echo "                  an absent diagnostic is not a passing measurement."
      fail=1
    }
  done

  if [ "$fail" -eq 0 ]; then
    echo "self-test: caught both defects on different probes, passed each one's other"
    echo "           probe, passed the correct control, and refused a run that never"
    echo "           compiled — the gate discriminates and does not pass vacuously"
    exit 0
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
if [ ! -x "$BSC" ]; then
    echo "building bsc..." >&2
    (cd "$HERE" && rebar3 escriptize >/dev/null)
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/P1" "$WORK/P2" "$WORK/P3"

cat > "$WORK/P1/P1.bs" <<'BS'
module P1

public atom Shape(list<int> xs)

Shape([])         -> :empty
Shape([a, b, ..]) -> :many
BS

cat > "$WORK/P2/P2.bs" <<'BS'
module P2

public atom Shape(list<int> xs)

Shape([])         -> :empty
Shape([a])        -> :one
Shape([a, b, ..]) -> :many
BS

cat > "$WORK/P3/P3.bs" <<'BS'
module P3

public atom Shape(list<int> xs)

Shape([])         -> :empty
Shape([a, b, ..]) -> :many
Shape([a, ..])    -> :one
BS

# The probes are named P1/P2/P3 but the function is `Shape` in all three, so the
# residual assertion in probe 1 can be anchored on the head it must print.
for p in P1 P2 P3; do
  # Captured, not piped: a probe that reports a diagnostic exits non-zero, and
  # that is the expected shape for probe 1 rather than a failure of the gate.
  ( cd "$WORK" && "$BSC" --src-root . "$p" ) > "$WORK/$p.out" 2>&1 || true
done

violations="$(judge "$WORK" || true)"

if [ -n "$violations" ]; then
  echo "the checker does not see a list's length"
  echo
  printf '%s\n' "$violations"
  echo
  echo "ticket 54 and compiler/features/F20-list-length.md carry the decision."
  exit 1
fi

echo "  ok         [] + [a, b, ..] names the missing case as [n]"
echo "  ok         [] + [a] + [a, b, ..] is exhaustive and silent"
echo "  ok         a clause that matches [7] is not called unreachable"
echo
echo "the checker sees a list's length, in both directions"
