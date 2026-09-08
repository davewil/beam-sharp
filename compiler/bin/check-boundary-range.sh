#!/usr/bin/env bash
#
# A REFINED `int` PARAMETER MUST BE INSIDE ITS REFINEMENT AT THE EXPORTED BOUNDARY.
#
# Ticket 46, resolved 2026-08-23 and never built. `examples/Wire` publishes
# `-spec 'Classify'(0..255)` and answered:
#
#     $ bsc --src-root examples examples/Wire Classify 300   ->  :reserved
#     $ bsc --src-root examples examples/Wire Band -5        ->  :low
#     $ bsc --src-root examples examples/Wire Sizing 300     ->  :high
#
# `300` and `-5` are integers, so F24's `is_integer/1` passes them; nothing then
# asked whether they were in the domain the `-spec` advertises. This gate is the
# other half of `check-boundary-kind.sh` and the two are deliberately separate:
# each one's stub set is the other's blind spot.
#
# THE RULE IS SUBTRACTION, NOT A FLAG (46 §2). Only the part of the refinement a
# clause has not already proved is emitted. `Classify(>= 9)` carries `=< 255`;
# `Classify(1)` and `Classify(>= 4 and <= 7)` carry nothing.
#
# WHY THIS GATE COUNTS AND DOES NOT ONLY PROBE. A naive two-comparisons-on-every-
# clause emission crashes on exactly the same inputs as the decided one, so no
# behavioural probe can tell them apart. What separates them is what the compiler
# WROTE — and the emitted form is the compiler's own published output, the same
# boundary the `-spec` and `--api` are read at, so counting it is a boundary
# assertion and not an implementation one. Probe 5 is that count.
#
# WHY PROBE 4 EXISTS, WHICH IS THE ONE WORTH READING TWICE. An emitter that
# subtracts the declared type from an UNINHABITED answer finds nothing to
# subtract and emits nothing, so a clause the checker could not read loses its
# guard entirely. `Foo(n, m) when n > m` is such a clause
# (`bs_check:comparison/1` reads a variable against an integer LITERAL, and two
# variables fall through to `unknown`).
#
# THE COMPILER DOES NOT HAVE THAT EMITTER, AND THIS COMMENT USED TO CLAIM IT
# WOULD IF `bs_check:clause_accepts/2` read `Certain` instead of `Possible`.
# Measured 2026-09-08 by making the swap: every probe here stays green, because
# `Certain` is either `none` or identical to `Possible`, and `positions/2`
# answers `term` for an uninhabited type — the clause is over-guarded, not
# unguarded. What this probe defends is therefore `positions/2`'s fallback,
# which is one tidy-up away from being deleted as incidental, and not the
# choice of bound. The stub is kept for that reason and its name is left as
# CERTAIN because that is the reading it simulates.
#
# WHY THE ABSENCES ARE PAIRED WITH PRESENCES. Probes 1, 3, 4 and 6 assert that
# something is NOT there, and an absence goes green for free over a module that
# never compiled. Each is paired: probe 2 runs the same module as 1 and 3 and
# demands an answer, probe 5 demands the emitted form exists before reading its
# counts, and probe 6 demands `{function` before reading its absence. The BROKEN
# control below is what proves the pairing rather than a comment claiming it.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

# ---------------------------------------------------------------------------
# count_cmp — occurrences of a boundary comparison against a given integer in a
# FLATTENED abstract form (whitespace stripped, so the term printer's line
# breaks cannot hide a match).
#
# The right operand is pinned to the literal, which is what keeps F2's
# RELATIONAL PATTERNS out of the count: `Classify(>= 4 and <= 7)` lowers to a
# `=<` against 7, and no fixture below writes a clause that compares against a
# domain bound. Counting bare `'=<'` would count that lowering as a boundary
# guard and the gate would grade itself green on F2's work.
# ---------------------------------------------------------------------------
count_cmp() {
  local flat="$1" op="$2" n="$3"
  grep -o "'$op',{var,{[0-9,]*},'[^']*'},{integer,{[0-9,]*},$n}" "$flat" 2>/dev/null | wc -l | tr -d ' '
}

# ---------------------------------------------------------------------------
# judge — the whole of the gate's opinion, in one place.
#
# A function over a directory, so --self-test drives THIS code path with
# fixtures rather than a copy of it.
# ---------------------------------------------------------------------------
judge() {
  local dir="$1"
  local p1 p2 p3 p4 p5 p6 hi lo

  p1="$(cat "$dir/P1.out")"
  p2="$(cat "$dir/P2.out")"
  p3="$(cat "$dir/P3.out")"
  p4="$(cat "$dir/P4.out")"
  p5="$dir/P5.flat"
  p6="$dir/P6.flat"

  # PROBE 1 — the reported escape, ABOVE the domain.
  #
  #   Classify(>= 9) -> :reserved      called with 300
  #
  # `300 >= 9` is true, so the value walked into a clause whose parameter is
  # declared `0..255` and an answer came back. Ticket 18's outcome 3.
  if [ -z "$p1" ]; then
    echo "probe 1: nothing at all was reported for Classify(300) — neither a value"
    echo "         nor a failure. the probe did not run, so nothing was measured."
  elif grep -q 'reserved' <<<"$p1"; then
    echo "probe 1: Classify(300) returned a value, and the parameter is declared"
    echo "         0..255. this is ticket 18's outcome 3 — the type system is a lie."
    sed 's/^/           /' <<<"$p1"
  fi

  # PROBE 2 — the domain still answers, and the probe that keeps 1 and 3 honest.
  #
  # THE INCLUSIVE EDGE, 255, and not a comfortable interior value: an off-by-one
  # at the bound is the failure this shape invites, and `100` would not see it.
  # It also runs the SAME module as probes 1 and 3, so a module that never built
  # cannot pass those by silence without failing this one by silence.
  if ! grep -q 'reserved' <<<"$p2"; then
    echo "probe 2: Classify(255) is the inclusive upper edge of Octet and did not"
    echo "         answer :reserved. either the guard is off by one and has closed"
    echo "         the door on the domain it defends, or the module never compiled"
    echo "         — in which case probes 1 and 3 measured nothing."
    sed 's/^/           /' <<<"$p2"
  fi

  # PROBE 3 — the escape BELOW the domain, which ticket 46's own framing missed.
  #
  #   Band(n) when n <= 64 -> :low     called with -5
  #
  # 46 §2: "half the escapes are below it". This clause proves the UPPER half of
  # `Octet` and owes the lower, so it is the mirror of probe 1 and fails
  # separately — a fix that emits only upper bounds passes 1 and dies here.
  if [ -z "$p3" ]; then
    echo "probe 3: nothing at all was reported for Band(-5). the probe did not run."
  elif grep -q 'low' <<<"$p3"; then
    echo "probe 3: Band(-5) returned a value, and the parameter is declared 0..255."
    echo "         the clause proves the upper bound and owes the lower one; only"
    echo "         upper bounds are being emitted."
    sed 's/^/           /' <<<"$p3"
  fi

  # PROBE 4 — the unreadable guard, and the reason this gate is not just probes
  # 1 and 3.
  #
  #   Foo(n, m) when n > m -> 1        called with (300, 1)
  #
  # The guard is unreadable to the checker, so what the clause is CREDITED with
  # is uninhabited. An emitter that subtracts the declared type from that finds
  # nothing to subtract, emits NOTHING, and `300` walks in and answers `1`. The
  # compiler answers `term` at such a position instead, so the clause carries
  # both bounds and refuses it. See the header for what was measured here.
  if [ -z "$p4" ]; then
    echo "probe 4: nothing at all was reported for Foo(300, 1). the probe did not run."
  elif grep -qx '1' <<<"$p4"; then
    echo "probe 4: Foo(300, 1) answered from a clause whose guard the checker cannot"
    echo "         read, at a parameter declared 0..255. the credited type for such"
    echo "         a clause is uninhabited, and subtracting the declared type from"
    echo "         it leaves nothing to emit — so the clause carries no guard at"
    echo "         all. bs_check:positions/2 must answer term at that position."
    sed 's/^/           /' <<<"$p4"
  fi

  # PROBE 5 — subtraction, as a count. THE ASSERTION BEHAVIOUR CANNOT MAKE.
  #
  # The fixture is `wire.bs`'s Classify and Band, ten clauses between them.
  # 46 §2's table says which of them owe what:
  #
  #   Classify(0,1,2,3,8)        nothing   a literal proves itself in 0..255
  #   Classify(>= 4 and <= 7)    nothing   a two-sided span proves itself
  #   Classify(>= 9)             =< 255    the lower half is proved
  #   Band(n) when n > 128       =< 255
  #   Band(n) when n > 64        =< 255
  #   Band(n) when n <= 64       >= 0      the UPPER half is proved
  #
  # Three upper bounds and one lower, over ten clauses. Naive two-per-clause
  # emission would write twenty.
  if ! grep -q '{function' "$p5" 2>/dev/null; then
    echo "probe 5: the fixture produced no emitted function, so the counts below"
    echo "         are not a measurement."
  else
    hi="$(count_cmp "$p5" '=<' 255)"
    lo="$(count_cmp "$p5" '>=' 0)"
    if [ "$hi" != 3 ]; then
      echo "probe 5: $hi comparisons against the upper bound 255, and 46 §2's table"
      echo "         says 3 — one on Classify(>= 9) and two on Band. more means the"
      echo "         emitter is not subtracting; fewer means a clause that owes the"
      echo "         bound is not carrying it."
    fi
    if [ "$lo" != 1 ]; then
      echo "probe 5: $lo comparisons against the lower bound 0, and 46 §2's table"
      echo "         says 1 — on Band(n) when n <= 64, the clause that proves the"
      echo "         upper half and owes the lower."
    fi
  fi

  # PROBE 6 — no dead weight, asserted against a compile that HAPPENED.
  #
  # Every clause of the Lits fixture is an integer literal inside its domain, so
  # every clause proves itself and nothing is owed. This is the probe a
  # fires-on-everything emitter fails, and `{function` is required first because
  # an absent comparison proves nothing over a run that died — the lesson
  # `check-list-length.sh` learned by going green over a module that never
  # parsed.
  if ! grep -q '{function' "$p6" 2>/dev/null; then
    echo "probe 6: the literal-clause module produced no emitted function, so the"
    echo "         absence of comparisons below it is not a measurement."
  elif [ "$(count_cmp "$p6" '=<' 1)" != 0 ] || [ "$(count_cmp "$p6" '>=' 0)" != 0 ]; then
    echo "probe 6: a comparison emitted on a clause whose pattern is an integer"
    echo "         literal inside its own domain. the literal proves itself — 46 §2"
    echo "         — and a bound beside it is dead weight on every call."
  fi
}

# ---------------------------------------------------------------------------
# --self-test
#
# FOUR STUBS AND TWO CONTROLS, FAILING ON DIFFERENT PROBES.
#
#   SILENT    the compiler as ticket 46 left it: no range guard anywhere. Fails
#             1, 3, 4 and 5 — and PASSES 2 and 6.
#
#   NAIVE     two comparisons on every clause. The over-correction, and the one
#             every behavioural probe accepts. Fails 5 and 6 — PASSES 1-4.
#
#   UPPERONLY only the upper bound, which is the shape ticket 46's own prose
#             suggests before §2 corrects it. Fails 3 and 5 — PASSES 1, 2, 4, 6.
#
#   CERTAIN   THE STUB THIS GATE EXISTS FOR. An emitter correct on every clause
#             whose guard the checker can read, and absent on the one it
#             cannot. Fails 4 ALONE — which is what makes probe 4 worth its
#             own fixture rather than folding into probes 1 and 3.
#
#   GOOD      the decided behaviour. Must pass all six.
#
#   BROKEN    nothing compiled. Every probe must fire, because four of them
#             assert absences and an absence goes green over a run that never
#             happened.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  fail=0

  # Flattened emitted forms, written the way the term printer writes them once
  # whitespace is stripped. `cmp` builds one comparison so the stubs differ in
  # their COUNTS rather than in hand-copied text.
  cmp_at() { printf "{op,{1,1},'%s',{var,{1,1},'Bs@r1'},{integer,{1,1},%s}}" "$1" "$2"; }

  head_flat='{function,0,'"'"'Classify'"'"',1,[{clause,{1,1},[{var,{1,1},'"'"'Bs@r1'"'"'}],[['

  #                     upper bounds        lower bounds
  # GOOD/CERTAIN:            3                   1
  # NAIVE:                  10                  10
  # UPPERONLY:               3                   0
  # SILENT:                  0                   0
  build_flat() {                       # build_flat <n_upper> <n_lower> <file>
    local up="$1" lo="$2" out="$3" i
    { printf '%s' "$head_flat"
      for ((i=0;i<up;i++)); do cmp_at '=<' 255; done
      for ((i=0;i<lo;i++)); do cmp_at '>=' 0;   done
      printf ']],[{atom,{1,1},reserved}]}]}.'
    } > "$out"
  }

  # The literal-clause module: emitted, and with or without dead weight.
  lits_clean="{function,0,'Only',1,[{clause,{1,1},[{integer,{1,1},0}],[],[{integer,{1,1},10}]}]}."
  lits_dead="$lits_clean$(cmp_at '=<' 1)"

  stub() {                             # stub <name> <p1> <p2> <p3> <p4> <up> <lo> <lits>
    local d="$CTL/$1"; mkdir -p "$d"
    printf '%s\n' "$2" > "$d/P1.out"
    printf '%s\n' "$3" > "$d/P2.out"
    printf '%s\n' "$4" > "$d/P3.out"
    printf '%s\n' "$5" > "$d/P4.out"
    build_flat "$6" "$7" "$d/P5.flat"
    printf '%s\n' "$8" > "$d/P6.flat"
  }

  # Fires <name> <result> <must-fire probes…> — every other probe must be silent.
  #
  # Every branch is an `if`, and the function ends in an explicit `return 0`.
  # Under `set -e` a trailing `[ … ] && x=y` or `grep -q … && { … }` makes the
  # function exit non-zero when the test simply did not match, and the script
  # dies silently with no output at all — which is exactly what a self-test
  # must not do.
  expect() {
    local name="$1" out="$2"; shift 2
    local n w want fired
    for n in 1 2 3 4 5 6; do
      want=no
      for w in "$@"; do
        if [ "$w" = "$n" ]; then want=yes; fi
      done
      fired=no
      if grep -q "^probe $n:" <<<"$out"; then fired=yes; fi
      if [ "$want" = yes ] && [ "$fired" = no ]; then
        echo "SELF-TEST FAILED: probe $n missed the $name stub."
        fail=1
      fi
      if [ "$want" = no ] && [ "$fired" = yes ]; then
        echo "SELF-TEST FAILED: probe $n fired on the $name stub, which it should"
        echo "                  pass. a probe that fires on everything proves nothing."
        fail=1
      fi
    done
    return 0
  }

  # --- SILENT ------------------------------------------------------------
  stub silent ':reserved' ':reserved' ':low' '1' 0 0 "$lits_clean"
  expect silent "$(judge "$CTL/silent" || true)" 1 3 4 5

  # --- NAIVE -------------------------------------------------------------
  # Ten clauses × two bounds. Refuses everything probes 1-4 ask about, and puts
  # a comparison on every literal.
  stub naive 'crashed' ':reserved' 'crashed' 'crashed' 10 10 "$lits_dead"
  expect naive "$(judge "$CTL/naive" || true)" 5 6

  # --- UPPERONLY ---------------------------------------------------------
  # `Band(-5)` still answers, and the lower-bound count is zero.
  stub upperonly 'crashed' ':reserved' ':low' 'crashed' 3 0 "$lits_clean"
  expect upperonly "$(judge "$CTL/upperonly" || true)" 3 5

  # --- CERTAIN -----------------------------------------------------------
  # THE POINT OF THIS FILE. Every readable clause is guarded exactly right, so
  # the counts are correct and probes 1, 2, 3, 5 and 6 all pass. Only the clause
  # with the unreadable guard is undefended, and only probe 4 sees it.
  stub certain 'crashed' ':reserved' 'crashed' '1' 3 1 "$lits_clean"
  expect certain "$(judge "$CTL/certain" || true)" 4

  # --- GOOD --------------------------------------------------------------
  stub good 'crashed' ':reserved' 'crashed' 'crashed' 3 1 "$lits_clean"
  good="$(judge "$CTL/good" || true)"
  if [ -n "$good" ]; then
    echo "SELF-TEST FAILED: the gate rejected the decided behaviour:"
    sed 's/^/                  /' <<<"$good"
    fail=1
  fi

  # --- BROKEN ------------------------------------------------------------
  mkdir -p "$CTL/broken"
  : > "$CTL/broken/P1.out"
  : > "$CTL/broken/P2.out"
  : > "$CTL/broken/P3.out"
  : > "$CTL/broken/P4.out"
  echo 'syntax error before: 255' > "$CTL/broken/P5.flat"
  echo 'syntax error before: 255' > "$CTL/broken/P6.flat"
  expect broken "$(judge "$CTL/broken" || true)" 1 2 3 4 5 6

  if [ "$fail" -eq 0 ]; then
    echo "self-test: caught four defects on different probes — a silent emitter, the"
    echo "           naive two-per-clause form no behavioural probe can see, an"
    echo "           upper-bounds-only fix, and an emitter that credits an unreadable"
    echo "           clause with nothing — passed each stub's other probes, passed the decided"
    echo "           behaviour, and refused a run that never compiled."
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

mkdir -p "$WORK/src/Gate" "$WORK/src/Unread" "$WORK/src/Lits" "$WORK/out"

# `Octet` is a CLOSED domain, so ticket 12 §2 forbids a catch-all over it and
# every one of these clauses is load-bearing for the fixture to compile at all.
# `Classify` and `Band` together are 46 §2's measured table.
cat > "$WORK/src/Gate/gate.bs" <<'BS'
module Gate

type Octet = int where value >= 0 and value <= 255
type FrameType = :method | :header | :body | :heartbeat | :reserved
type Size = :low | :mid | :high

public FrameType Classify(Octet)

Classify(1)             -> :method
Classify(2)             -> :header
Classify(3)             -> :body
Classify(8)             -> :heartbeat
Classify(0)             -> :reserved
Classify(>= 4 and <= 7) -> :reserved
Classify(>= 9)          -> :reserved

public Size Band(Octet n)

Band(n) when n > 128 -> :high
Band(n) when n > 64  -> :mid
Band(n) when n <= 64 -> :low
BS

# The guard `n > m` compares two VARIABLES, which `bs_check:comparison/1` does
# not translate — it reads a variable against an integer literal and nothing
# else. So the clause credits `Certain = none` and is the fixture probe 4 needs.
cat > "$WORK/src/Unread/unread.bs" <<'BS'
module Unread

type Octet = int where value >= 0 and value <= 255

public int Foo(Octet n, Octet m)

Foo(n, m) when n > m -> 1
Foo(n, m)            -> 0
BS

# Two literals over a two-value domain: closed, exhaustive, and every head
# already proves itself inside `Bit`.
cat > "$WORK/src/Lits/lits.bs" <<'BS'
module Lits

type Bit = int where value >= 0 and value <= 1

public int Only(Bit)

Only(0) -> 10
Only(1) -> 11
BS

# Probes 1-3 run the SAME module with different arguments, which is what makes
# the absences safe. Captured rather than piped: a refused call exits non-zero
# and that is the expected shape, not a gate failure.
( cd "$WORK/src" && "$BSC" --src-root . Gate Classify 300 ) > "$WORK/P1.out" 2>&1 || true
( cd "$WORK/src" && "$BSC" --src-root . Gate Classify 255 ) > "$WORK/P2.out" 2>&1 || true
( cd "$WORK/src" && "$BSC" --src-root . Gate Band "-5"    ) > "$WORK/P3.out" 2>&1 || true
( cd "$WORK/src" && "$BSC" --src-root . Unread Foo 300 1  ) > "$WORK/P4.out" 2>&1 || true

# Probes 5 and 6 read the emitted abstract form, which `bsc` writes beside the
# beam as `.abstr`. Flattened first: the term printer breaks a comparison across
# lines, and a pattern that cannot match across a line break silently counts nothing.
( cd "$WORK/src" && "$BSC" --src-root . -o "$WORK/out" Gate ) > "$WORK/gate.log" 2>&1 || true
( cd "$WORK/src" && "$BSC" --src-root . -o "$WORK/out" Lits ) > "$WORK/lits.log" 2>&1 || true
flatten() { tr -d ' \n' < "$1" > "$2"; }
if [ -f "$WORK/out/Gate.abstr" ]; then flatten "$WORK/out/Gate.abstr" "$WORK/P5.flat"; else flatten "$WORK/gate.log" "$WORK/P5.flat"; fi
if [ -f "$WORK/out/Lits.abstr" ]; then flatten "$WORK/out/Lits.abstr" "$WORK/P6.flat"; else flatten "$WORK/lits.log" "$WORK/P6.flat"; fi

violations="$(judge "$WORK" || true)"

if [ -n "$violations" ]; then
  echo "a refined int parameter is not inside its refinement at the boundary"
  echo
  printf '%s\n' "$violations"
  echo
  echo "ticket 46 and compiler/features/F37-boundary-range.md carry the decision;"
  echo "46 §2 is the subtraction rule and its measured table."
  exit 1
fi

echo "  ok         Classify(300) returns no value, at the >= 9 clause"
echo "  ok         Classify(255) still answers at the inclusive edge"
echo "  ok         Band(-5) returns no value, at the clause that owes the lower bound"
echo "  ok         Foo(300, 1) is refused though its guard is unreadable"
echo "  ok         ten clauses carry four comparisons, not twenty"
echo "  ok         a literal clause carries none"
echo
echo "a refined int parameter is inside its refinement at the boundary"
