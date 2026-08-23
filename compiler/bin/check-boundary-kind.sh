#!/usr/bin/env bash
#
# AN `int` PARAMETER MUST BE AN INTEGER AT THE EXPORTED BOUNDARY.
#
# Ticket 58. `examples/Wire` publishes `-spec 'Classify'(0..255)` and answered
# `:reserved` for `100.5` — a float reaching a parameter whose declared type is
# a range of integers, with no crash, ever. Ticket 18 §1 rule C case (b) decided
# this on 2026-08-13 and §5 refused an opt-out; the rule was simply never in the
# emitter.
#
# THE CASE THAT DECIDES WHETHER THE FIX WORKS IS 100.5, NOT 300.5, and probe 1
# is built on it deliberately. `100.5` reaches the `Classify(>= 9)` clause,
# because `100.5 >= 9` is true. A fix derived from ticket 46's range subtraction
# emits `=< 255` on that clause and nothing more — and `100.5 =< 255` is true as
# well, so `300.5` would begin crashing while `100.5` kept answering `:reserved`.
# A gate written around `300.5` would go green over a defect that had not moved.
# A comparison proves ORDERING; only a type test closes the numeric tower.
#
# WHY THE PROBES ARE ASSERTED IN TWO REGISTERS. Probes 1 and 2 read what the
# program DOES; probes 3 and 4 read what the compiler WROTE. Either alone is
# insufficient and the reason is recorded rather than inferred: a
# `function_clause` proves only that no clause matched, not that this guard is
# why — the BEAM raises the same error for a head that failed for any other
# reason. So the runtime change and the emitted test are asserted separately.
#
# PROBE 1 DOES NOT MATCH ON CRASH TEXT. It asserts that no VALUE came back,
# which is the property ticket 18's outcome 3 is about and which does not depend
# on how a crash happens to be rendered. An absence like that passes for free
# over a module that never compiled — so probe 2 asserts that the very same
# module answers correctly for a valid integer. The absence in probe 1 is
# protected by the presence in probe 2, structurally, and the BROKEN control
# below is what proves it.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

# ---------------------------------------------------------------------------
# judge — the whole of the gate's opinion, in one place.
#
# Reads P1.out, P2.out, P3.abstr and P4.abstr from a directory and prints one
# line per violation. A function over a directory so --self-test drives THIS
# code path with fixtures rather than a copy of it.
# ---------------------------------------------------------------------------
judge() {
  local dir="$1"
  local p1 p2 p3 p4
  p1="$(cat "$dir/P1.out")"
  p2="$(cat "$dir/P2.out")"
  p3="$(cat "$dir/P3.abstr")"
  p4="$(cat "$dir/P4.abstr")"

  # PROBE 1 — the defect itself, at the clause that makes it hard.
  #
  #   Classify(>= 9) -> :reserved      called with 100.5
  #
  # `100.5 >= 9` is true, so before the fix a float walked into a clause whose
  # parameter is declared `0..255` and a value came back.
  if [ -z "$p1" ]; then
    echo "probe 1: nothing was reported at all for Classify(100.5) — neither a value"
    echo "         nor a failure. the probe did not run, so nothing was measured."
  elif grep -q 'reserved' <<<"$p1"; then
    echo "probe 1: Classify(100.5) returned a value, and the parameter is declared"
    echo "         0..255. this is ticket 18's outcome 3 — the type system is a lie."
    sed 's/^/           /' <<<"$p1"
  fi

  # PROBE 2 — the domain still answers, and the probe that keeps this honest.
  #
  # THIS IS THE PROBE A FIRES-ON-EVERYTHING CHECK FAILS. Probe 1 demands that
  # something be refused; this one demands that something be accepted. A guard
  # emitted on every clause regardless, or a compiler that stopped compiling,
  # fails here. It is also what makes probe 1's absence assertion non-vacuous:
  # both probes run the SAME module, so a module that never built cannot pass
  # probe 1 by silence without failing probe 2 by silence.
  if ! grep -q 'reserved' <<<"$p2"; then
    echo "probe 2: Classify(100) is a valid Octet and did not answer :reserved."
    echo "         the guard has closed the door on the domain it defends — or the"
    echo "         module never compiled, in which case probe 1 measured nothing."
    sed 's/^/           /' <<<"$p2"
  fi

  # PROBE 3 — the emitted head, which is what separates this fix from a crash
  # that happened for some other reason.
  #
  # The module has two clauses that do not pin the kind: a relational pattern
  # (a comparison, which orders rather than tests) and a bare variable (which
  # tests nothing at all). Both must carry the type test.
  if ! grep -q 'is_integer' <<<"$p3"; then
    echo "probe 3: no is_integer anywhere in the emitted module, though two clauses"
    echo "         accept an int parameter without pinning its kind. a comparison"
    echo "         proves ordering, not kind."
  fi

  # PROBE 4 — no dead weight, asserted against a compile that HAPPENED.
  #
  # Every clause of P4 is an integer literal, which is ticket 18 §1(a): the head
  # already objects, so nothing is owed. An absent `is_integer` proves nothing
  # if the run died first, so the module's own emitted form is required to be
  # there — `{function` is the shape every compiled module has — before its
  # absence is read as a result. This is `check-list-length.sh`'s probe 3
  # lesson, which went green over a module that never parsed.
  if ! grep -q '{function' <<<"$p4"; then
    echo "probe 4: the literal-clause module produced no emitted function, so the"
    echo "         absence of is_integer below it is not a measurement."
  elif grep -q 'is_integer' <<<"$p4"; then
    echo "probe 4: is_integer emitted on a clause whose pattern is an integer"
    echo "         literal. the head already objects — 18 §1(a) — and a second"
    echo "         test beside it is dead weight on every call."
  fi
}

# ---------------------------------------------------------------------------
# --self-test
#
# THREE STUBS AND TWO CONTROLS, AND THEY FAIL ON DIFFERENT PROBES.
#
#   SILENT   the compiler as ticket 58 found it: no type test anywhere. Fails
#            probes 1 and 3 — and PASSES 2 and 4.
#
#   CRYWOLF  a type test on every clause including the literals. The obvious
#            over-correction. Fails probe 4 — and PASSES 1, 2 and 3.
#
#   RANGE    THE STUB THIS GATE EXISTS FOR, and the one a careless fix
#            produces: ticket 46's range subtraction and nothing else. It emits
#            `=< 255`, so `300.5` crashes and `100.5` still answers `:reserved`.
#            It fails probe 1 — and PASSES 2 and 4. A gate built around `300.5`
#            would call this stub fixed.
#
#   GOOD     the decided behaviour. Must pass all four.
#
#   BROKEN   nothing compiled. Every probe must fire, because a probe that
#            asserts an absence goes green over a run that never happened.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  fail=0

  # A module body that is emitted and carries no type test, and one that does.
  emitted_plain='{function,0,'"'"'Classify'"'"',1,[{clause,47,[{var,47,'"'"'Bs@r1'"'"'}],[[{op,47,'"'"'>='"'"',{var,47,'"'"'Bs@r1'"'"'},{integer,47,9}}]],[{atom,47,reserved}]}]}.'
  emitted_typed='{function,0,'"'"'Classify'"'"',1,[{clause,47,[{var,47,'"'"'Bs@r1'"'"'}],[[{call,47,{atom,47,is_integer},[{var,47,'"'"'Bs@r1'"'"'}]}]],[{atom,47,reserved}]}]}.'

  # --- SILENT ------------------------------------------------------------
  mkdir -p "$CTL/silent"
  echo ':reserved'      > "$CTL/silent/P1.out"    # the float got an answer
  echo ':reserved'      > "$CTL/silent/P2.out"    # the integer got one too
  echo "$emitted_plain" > "$CTL/silent/P3.abstr"  # no test emitted
  echo "$emitted_plain" > "$CTL/silent/P4.abstr"  # correct here, by accident
  silent="$(judge "$CTL/silent" || true)"
  grep -q '^probe 1:' <<<"$silent" || { echo "SELF-TEST FAILED: probe 1 missed the silent stub — the reported defect"; fail=1; }
  grep -q '^probe 3:' <<<"$silent" || { echo "SELF-TEST FAILED: probe 3 missed the silent stub — no test in the emitted head"; fail=1; }
  for n in 2 4; do
    if grep -q "^probe $n:" <<<"$silent"; then
      echo "SELF-TEST FAILED: probe $n fired on the silent stub, which it should pass."
      echo "                  a probe that fires on everything proves nothing."
      fail=1
    fi
  done

  # --- CRYWOLF -----------------------------------------------------------
  mkdir -p "$CTL/crywolf"
  echo 'function_clause' > "$CTL/crywolf/P1.out"
  echo ':reserved'       > "$CTL/crywolf/P2.out"
  echo "$emitted_typed"  > "$CTL/crywolf/P3.abstr"
  echo "$emitted_typed"  > "$CTL/crywolf/P4.abstr"  # dead weight on a literal
  crywolf="$(judge "$CTL/crywolf" || true)"
  grep -q '^probe 4:' <<<"$crywolf" || { echo "SELF-TEST FAILED: probe 4 missed the cry-wolf stub — a test on a literal clause"; fail=1; }
  for n in 1 2 3; do
    if grep -q "^probe $n:" <<<"$crywolf"; then
      echo "SELF-TEST FAILED: probe $n fired on the cry-wolf stub, which it should pass."
      fail=1
    fi
  done

  # --- RANGE -------------------------------------------------------------
  #
  # The stub that motivates this file. Range comparisons only: `300.5` is
  # refused and `100.5` is not, so the reported defect survives the fix.
  mkdir -p "$CTL/range"
  echo ':reserved'      > "$CTL/range/P1.out"     # 100.5 =< 255 is true
  echo ':reserved'      > "$CTL/range/P2.out"
  echo "$emitted_plain" > "$CTL/range/P3.abstr"   # comparisons, no type test
  echo "$emitted_plain" > "$CTL/range/P4.abstr"
  range="$(judge "$CTL/range" || true)"
  grep -q '^probe 1:' <<<"$range" || {
    echo "SELF-TEST FAILED: probe 1 accepted the range-only stub. this is the defect"
    echo "                  the gate exists for: 300.5 crashes, 100.5 does not, and"
    echo "                  ticket 58's own measurement is unchanged."
    fail=1
  }
  for n in 2 4; do
    if grep -q "^probe $n:" <<<"$range"; then
      echo "SELF-TEST FAILED: probe $n fired on the range-only stub, which it should pass."
      fail=1
    fi
  done

  # --- GOOD --------------------------------------------------------------
  mkdir -p "$CTL/good"
  echo 'function_clause' > "$CTL/good/P1.out"
  echo ':reserved'       > "$CTL/good/P2.out"
  echo "$emitted_typed"  > "$CTL/good/P3.abstr"
  echo "$emitted_plain"  > "$CTL/good/P4.abstr"
  good="$(judge "$CTL/good" || true)"
  if [ -n "$good" ]; then
    echo "SELF-TEST FAILED: the gate rejected the decided behaviour:"
    sed 's/^/                  /' <<<"$good"
    fail=1
  fi

  # --- BROKEN ------------------------------------------------------------
  #
  # Nothing compiled. Probes 1 and 4 assert ABSENCES and are the two that go
  # green for free when a run dies early; probes 2 and 3 assert presences and
  # fire on their own. All four are required, so the pairing is what makes the
  # absences safe rather than a comment claiming they are.
  mkdir -p "$CTL/broken"
  : > "$CTL/broken/P1.out"
  : > "$CTL/broken/P2.out"
  echo 'syntax error before: 255' > "$CTL/broken/P3.abstr"
  echo 'syntax error before: 255' > "$CTL/broken/P4.abstr"
  broken="$(judge "$CTL/broken" || true)"
  for n in 1 2 3 4; do
    grep -q "^probe $n:" <<<"$broken" || {
      echo "SELF-TEST FAILED: probe $n went green over a run that never compiled."
      echo "                  an absent diagnostic is not a passing measurement."
      fail=1
    }
  done

  if [ "$fail" -eq 0 ]; then
    echo "self-test: caught three defects on different probes — including the range-only"
    echo "           fix that leaves 100.5 answering — passed each stub's other probes,"
    echo "           passed the decided behaviour, and refused a run that never"
    echo "           compiled. the gate discriminates and does not pass vacuously"
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

mkdir -p "$WORK/src/Gate" "$WORK/src/Lits" "$WORK/out"

# `Octet` is a CLOSED domain, so ticket 12 §2 forbids a catch-all over it and
# every one of these clauses is load-bearing for the fixture to compile at all.
cat > "$WORK/src/Gate/gate.bs" <<'BS'
module Gate

type Octet = int where value >= 0 and value <= 255
type FrameType = :method | :header | :body | :heartbeat | :reserved

public FrameType Classify(Octet)

Classify(1)             -> :method
Classify(2)             -> :header
Classify(3)             -> :body
Classify(8)             -> :heartbeat
Classify(0)             -> :reserved
Classify(>= 4 and <= 7) -> :reserved
Classify(>= 9)          -> :reserved
BS

# Two literals over a two-value domain: closed, exhaustive, and every head
# already objects to a float.
cat > "$WORK/src/Lits/lits.bs" <<'BS'
module Lits

type Bit = int where value >= 0 and value <= 1

public int Only(Bit)

Only(0) -> 10
Only(1) -> 11
BS

# Probes 1 and 2 run the SAME module with different arguments, which is what
# makes probe 1's absence assertion safe. Captured rather than piped: a refused
# call exits non-zero and that is the expected shape, not a gate failure.
( cd "$WORK/src" && "$BSC" --src-root . Gate Classify 100.5 ) > "$WORK/P1.out" 2>&1 || true
( cd "$WORK/src" && "$BSC" --src-root . Gate Classify 100   ) > "$WORK/P2.out" 2>&1 || true

# Probes 3 and 4 read the emitted abstract form, which `bsc` writes beside the
# beam as `.abstr`.
( cd "$WORK/src" && "$BSC" --src-root . -o "$WORK/out" Gate ) > "$WORK/gate.log" 2>&1 || true
( cd "$WORK/src" && "$BSC" --src-root . -o "$WORK/out" Lits ) > "$WORK/lits.log" 2>&1 || true
cp "$WORK/out/Gate.abstr" "$WORK/P3.abstr" 2>/dev/null || cp "$WORK/gate.log" "$WORK/P3.abstr"
cp "$WORK/out/Lits.abstr" "$WORK/P4.abstr" 2>/dev/null || cp "$WORK/lits.log" "$WORK/P4.abstr"

violations="$(judge "$WORK" || true)"

if [ -n "$violations" ]; then
  echo "an int parameter is not an integer at the boundary"
  echo
  printf '%s\n' "$violations"
  echo
  echo "ticket 58 and compiler/features/F24-boundary-kind.md carry the decision;"
  echo "ticket 18 §1 rule C case (b) is where it was taken."
  exit 1
fi

echo "  ok         Classify(100.5) returns no value, at the >= 9 clause"
echo "  ok         Classify(100) still answers :reserved"
echo "  ok         the unpinned clauses carry is_integer"
echo "  ok         a literal clause carries none"
echo
echo "an int parameter is an integer at the boundary"
