#!/usr/bin/env bash
#
# A RECORD PATTERN NAMING ITS TYPE SUBTRACTS EXACTLY WHAT THE `Kind` SPELLING DOES.
#
# F22 / ticket 55. `Frame { Type: :method }` is new surface over an old meaning:
# it must narrow the residual by precisely as much as
# `{ Kind: :'Mod.Frame', Type: :method }` narrows it, and no more.
#
# THE TWO DIRECTIONS ARE NOT EQUALLY DANGEROUS, WHICH IS WHY PROBE 2 EXISTS.
# Subtracting too LITTLE is loud: a union that is covered reports inexhaustive,
# somebody reads the diagnostic and fixes it. Subtracting too MUCH is silent —
# the compiler proves a program exhaustive and the BEAM crashes it on a member
# no clause matches. That is ticket 54's shape, and ticket 54 sat in a green
# suite of 449 tests.
#
# SO THE GATE ASSERTS A CLEAN COMPILE AND A REFUSAL, NOT ONE OR THE OTHER.
# Probe 1 requires the covering program to compile with rc 0 AND say nothing;
# probe 2 requires the partial program to be refused by name. A gate holding
# only probe 2 passes on a compiler that refuses everything. A gate holding only
# probe 1 passes on a compiler that accepts everything, which is the silent
# failure it was written for.
#
# AND THE ABSENCE IN PROBE 1 IS ASSERTED AGAINST A RUN THAT HAPPENED.
# `check-list-length.sh` went green on its first real run over a module that
# never parsed: "no diagnostic appeared" is free the moment the run dies
# earlier. The exit code is captured beside the output, and the BROKEN control
# below is nothing-compiles precisely so that this cannot regress.
#
# PROBE 3 IS THE CONTROL SPELLING. `{ Kind: … }` shipped with F3 and must go on
# meaning what it meant. If probes 2 and 3 ever disagree, the two spellings have
# diverged and that is the defect this feature exists not to introduce.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

PRELUDE='module Wire
record Method { Channel: int }
record Header { Channel: int }
type Frame = Method | Header
'

# ---------------------------------------------------------------------------
# judge — the whole of the gate's opinion, in one place.
#
# Reads P1.out/P1.rc … P4.out from a directory and prints one line per
# violation. A function over a directory so that --self-test drives THIS code
# path rather than a copy of it.
# ---------------------------------------------------------------------------
judge() {
  local dir="$1"
  local p1 rc1 p2 p3 p4
  p1="$(cat "$dir/P1.out")"
  rc1="$(cat "$dir/P1.rc")"
  p2="$(cat "$dir/P2.out")"
  p3="$(cat "$dir/P3.out")"
  p4="$(cat "$dir/P4.out")"

  # PROBE 1 — A COVERING PAIR IN THE NEW SPELLING COMPILES CLEAN.
  #
  #   Which(Method m) -> :method
  #   Which(Header h) -> :header
  #
  # Two members, two clauses, nothing left over. This is the probe a
  # fires-on-everything gate fails, and the probe that catches the type prefix
  # subtracting too little.
  if [ "$rc1" != "0" ]; then
    echo "probe 1: a covering type-prefixed program did not compile (exit $rc1)."
    echo "         an absent diagnostic proves nothing if the run failed. it said:"
    sed 's/^/           /' <<<"${p1:-(nothing)}"
  elif [ -n "$p1" ]; then
    echo "probe 1: a covering type-prefixed program compiled, and it complained:"
    sed 's/^/           /' <<<"$p1"
  fi

  # PROBE 2 — THE SILENT DIRECTION. A partial cover must be REFUSED, and the
  # residual must name the member left out.
  #
  #   Which(Method m) -> :method        // and no Header clause
  #
  # Accepting this is the ticket 54 failure: proved exhaustive, crashes on a
  # Header. Asserting the residual NAMES `Wire.Header` rather than merely that
  # something was refused is what stops a compiler that rejects the program for
  # an unrelated reason from passing.
  if grep -q 'syntax error\|illegal characters' <<<"$p2"; then
    echo "probe 2: did not compile, so nothing was measured. it said:"
    sed 's/^/           /' <<<"$p2"
  elif ! grep -q "Wire.Header" <<<"$p2"; then
    echo "probe 2: a partial cover was accepted, or was refused without naming the"
    echo "         member left out. the type prefix is subtracting more than the"
    echo "         Kind spelling does, and a Header reaches no clause. it said:"
    sed 's/^/           /' <<<"${p2:-(nothing)}"
  fi

  # PROBE 3 — THE CONTROL SPELLING, UNCHANGED.
  #
  #   Which({ Kind: :'Wire.Method' }) -> :method
  #
  # Same partial cover written the way F3 shipped. It must be refused with the
  # same residual. If this and probe 2 ever disagree, the two spellings mean
  # different things and the feature has introduced the divergence it exists to
  # avoid.
  if ! grep -q "Wire.Header" <<<"$p3"; then
    echo "probe 3: the Kind spelling stopped refusing a partial cover. this is a"
    echo "         regression in surface that shipped with F3, not in F22. it said:"
    sed 's/^/           /' <<<"${p3:-(nothing)}"
  fi

  # PROBE 4 — A TYPE PREFIX THAT NAMES NOTHING.
  #
  #   Which(Nope { Channel: 1 }) -> :no
  #
  # The one genuinely new error class the feature adds. It must name the type
  # that could not be found, per ticket 23.
  #
  # THE SYNTAX-ERROR GUARD IS NOT DECORATION HERE, AND IT WAS ADDED AFTER THIS
  # PROBE PASSED ON A COMPILER THAT HAD NONE OF THIS FEATURE. Before the grammar
  # existed, `Which(Nope { Channel: 1 })` produced `syntax error before: 'Nope'`
  # — which contains the string `Nope` and satisfied a bare name match. The probe
  # was green while measuring nothing, which is the shape it exists to catch in
  # the compiler.
  if grep -q 'syntax error\|illegal characters' <<<"$p4"; then
    echo "probe 4: did not compile, so nothing was measured. a syntax error that"
    echo "         happens to contain the type name is not a refusal of it. it said:"
    sed 's/^/           /' <<<"$p4"
  elif ! grep -q 'Nope' <<<"$p4"; then
    echo "probe 4: an undeclared type in a pattern was accepted, or was refused"
    echo "         without naming it. it said:"
    sed 's/^/           /' <<<"${p4:-(nothing)}"
  fi
}

# ---------------------------------------------------------------------------
# --self-test
#
# FOUR STUBS, FAILING ON DIFFERENT PROBES. A gate is believed only if it catches
# each one AND lets each one's other probes through — a check that fired on
# everything would catch all four and be worthless, which is `check-shell.sh`'s
# lesson from ticket 15.
#
#   SILENT    the partial cover is accepted and nothing is said. This is the
#             over-subtraction bug itself, and the reason the feature exists.
#             Fails probe 2 ONLY; passes 1, 3 and 4.
#
#   CRYWOLF   every probe reports, the correct program included. The
#             over-informed stub: it says all the right words, so a gate
#             matching only on words calls it a pass. Caught by probe 1 alone,
#             which is why probe 1 is not optional.
#
#   BROKEN    nothing compiles. The vacuity control: probe 1 must fire on the
#             exit code even though its output is empty, and probe 2 must fire
#             on "did not compile" rather than being satisfied by silence.
#
#   GOOD      the decided behaviour. Must pass all four.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  fail=0
  residual="in.bs:5: error: Which is not exhaustive
  no clause matches:
    Which({ Kind: :'Wire.Header' }) -> ..."

  expect() {
    local name="$1" dir="$2" want="$3" got
    got="$(judge "$dir" | grep -c "^probe" || true)"
    if [ "$want" = "$got" ]; then
      printf '  %-10s %s: %s probe(s) fired, as expected\n' "ok" "$name" "$got"
    else
      printf '  %-10s %s: expected %s probe(s) to fire, %s did\n' "FAIL" "$name" "$want" "$got"
      judge "$dir" | sed 's/^/             /'
      fail=1
    fi
  }

  # --- SILENT: accepts the partial cover, says nothing ---------------------
  mkdir -p "$CTL/silent"
  : > "$CTL/silent/P1.out"; echo 0 > "$CTL/silent/P1.rc"
  : > "$CTL/silent/P2.out"
  printf '%s\n' "$residual" > "$CTL/silent/P3.out"
  echo "in.bs:6: error: unknown type Nope" > "$CTL/silent/P4.out"
  expect "SILENT" "$CTL/silent" 1

  # --- CRYWOLF: reports on everything, correct program included ------------
  mkdir -p "$CTL/crywolf"
  echo "in.bs:5: error: Which is not exhaustive" > "$CTL/crywolf/P1.out"
  echo 0 > "$CTL/crywolf/P1.rc"
  printf '%s\n' "$residual" > "$CTL/crywolf/P2.out"
  printf '%s\n' "$residual" > "$CTL/crywolf/P3.out"
  echo "in.bs:6: error: unknown type Nope" > "$CTL/crywolf/P4.out"
  expect "CRYWOLF" "$CTL/crywolf" 1

  # --- BROKEN: nothing compiles -------------------------------------------
  mkdir -p "$CTL/broken"
  : > "$CTL/broken/P1.out"; echo 1 > "$CTL/broken/P1.rc"
  echo "in.bs:6: error: syntax error before: 'Method'" > "$CTL/broken/P2.out"
  echo "in.bs:6: error: syntax error before: 'Method'" > "$CTL/broken/P3.out"
  echo "in.bs:6: error: syntax error before: 'Method'" > "$CTL/broken/P4.out"
  expect "BROKEN" "$CTL/broken" 4

  # --- GOOD: the decided behaviour ----------------------------------------
  mkdir -p "$CTL/good"
  : > "$CTL/good/P1.out"; echo 0 > "$CTL/good/P1.rc"
  printf '%s\n' "$residual" > "$CTL/good/P2.out"
  printf '%s\n' "$residual" > "$CTL/good/P3.out"
  echo "in.bs:6: error: unknown type Nope" > "$CTL/good/P4.out"
  expect "GOOD" "$CTL/good" 0

  echo
  if [ "$fail" = "0" ]; then
    echo "self-test: the gate fires on each defect and stays quiet on the good build"
    exit 0
  fi
  echo "self-test: FAILED"
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
if [ ! -x "$BSC" ]; then
  echo "the bsc escript is missing, so nothing can be measured."
  echo "This is a failure rather than a skip: run \`rebar3 escriptize\` first."
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Each probe is its own module directory: bsc resolves a module from the
# directory it sits in, so sharing one would make every probe the same program.
probe() {
  local name="$1" body="$2"
  mkdir -p "$WORK/$name/Wire"
  printf '%s%s' "$PRELUDE" "$body" > "$WORK/$name/Wire/in.bs"
  set +e
  "$BSC" "$WORK/$name/Wire/in.bs" > "$WORK/$name.out" 2>&1
  echo $? > "$WORK/$name.rc"
  set -e
}

probe P1 'public atom Which(Frame)
Which(Method m) -> :method
Which(Header h) -> :header
'

probe P2 'public atom Which(Frame)
Which(Method m) -> :method
'

probe P3 "public atom Which(Frame)
Which({ Kind: :'Wire.Method' }) -> :method
"

probe P4 'public atom Which(Frame)
Which(Nope { Channel: 1 }) -> :no
Which(Method m) -> :method
Which(Header h) -> :header
'

echo "a record pattern naming its type subtracts what the Kind spelling subtracts"
echo

violations="$(judge "$WORK")"
if [ -n "$violations" ]; then
  echo "$violations"
  exit 1
fi

echo "  ok         a covering type-prefixed pair compiles clean, and is seen to compile"
echo "  ok         a partial cover is refused, and the residual names the missing member"
echo "  ok         the Kind spelling refuses the same program with the same residual"
echo "  ok         an undeclared type in a pattern is refused by name"
echo
echo "the type prefix and the Kind spelling agree"
