#!/usr/bin/env bash
#
# A FIELD ASSIGNMENT IS CHECKED — AT CONSTRUCTION AND AT `with`, ON BOTH HALVES.
#
# Ticket 36. `Order{ Id = :oops }` and `o with { Total = :oops }` both compiled
# clean and reached a `.beam`: `Id: int` is a declared type and `:oops` is a
# synthesised one that does not meet it. The decision is that site 2 is not
# "construction" but FIELD ASSIGNMENT, of which the two are spellings — so both
# check, and no sixth site opens.
#
# MEASURING THE TICKET FOUND A THIRD DEFECT ITS OWN SCOPE FENCE FORBADE LOOKING
# FOR. It said *"this ticket is about the values, not the names — F5 enforces
# the names"*, and F5 enforces them at CONSTRUCTION only. `o with { Nope = 1 }`
# compiled, emitted Erlang's `:=`, and raised `{badkey,'Nope'}` at run time, so
# 26 §2's width-preservation was being delivered by the BEAM rather than by the
# compiler. That is why probe 3 exists and why it is the probe most likely to be
# skipped: a builder implementing from the ticket's stated delta writes probes 1
# and 2 and stops. The `VALUE-ONLY` control below is exactly that builder, and
# the gate is not believed unless it catches them.
#
# WHY A GATE AND NOT A `<!-- check: -->` BLOCK IN LANGUAGE.md. Probe 4 asserts
# that a CORRECT record program compiles clean, and a doc block cannot express
# the difference between "compiled clean" and "did not compile at all". This
# gate captures the exit code beside the output for exactly that reason — see
# the `BROKEN` control.
#
# THE ASSERTIONS ARE ON THE DIAGNOSTIC, NEVER ON THE EXIT CODE ALONE. Refusing
# the program is candidate zero; naming the field and handing back the residual
# is the decision, and it is what ticket 23 asks a diagnostic to do.
#
# PROBE 5 — THE SUBJECT (ENG-249, 2026-09-03). F21 checked the fields named in
# a `with` and never asked what was being updated: `n with { Total = 1 }` on an
# `int` compiled at exit 0, typed as `int`, and raised `{badmap, N}` when it
# ran. A probe written for ticket 48 found it — the survey had claimed `with`
# was already a map-update form, and the claim was true only because the
# subject was unchecked. The SUBJECT-BLIND control below is F21 exactly as it
# shipped on 2026-08-21, and this gate went green over it for thirteen days.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

# ---------------------------------------------------------------------------
# judge — the whole of the gate's opinion, in one place.
#
# Reads P1.out … P5.out and P4.rc from a directory and prints one line per
# violation. A function over a directory so --self-test drives THIS code path
# rather than a copy of it.
# ---------------------------------------------------------------------------
judge() {
  local dir="$1"
  local p1 p2 p3 p4 p5 rc4
  p1="$(cat "$dir/P1.out")"
  p2="$(cat "$dir/P2.out")"
  p3="$(cat "$dir/P3.out")"
  p4="$(cat "$dir/P4.out")"
  p5="$(cat "$dir/P5.out")"
  rc4="$(cat "$dir/P4.rc")"

  # PROBE 1 — construction, the value half.
  #
  #   Order Make(int n)
  #   Make(n) -> Order{ Id = :oops, Total = n }
  #
  # Two assertions, and the second is what separates this decision from merely
  # refusing: the diagnostic must name the FIELD and hand back the residual.
  # `Order{Id} \ Order` — the name residual 33 §3 measured and marked useless —
  # is a different query from `:oops \ int`, which is precise.
  if grep -q 'syntax error\|illegal characters' <<<"$p1"; then
    echo "probe 1: did not compile, so nothing was measured. it said:"
    sed 's/^/           /' <<<"$p1"
  elif ! grep -q 'assigns Id a value' <<<"$p1"; then
    echo "probe 1: Order{ Id = :oops } was accepted — a record built with a field"
    echo "         value its own declaration rejects. it said:"
    sed 's/^/           /' <<<"${p1:-(nothing)}"
  elif ! grep -qF ':oops' <<<"$p1"; then
    echo "probe 1: refused the construction but did not hand back the residual."
    echo "         the value that was not accepted is the thing to remove. it said:"
    sed 's/^/           /' <<<"$p1"
  fi

  # PROBE 2 — `with`, the value half. THE HALF THE TICKET THOUGHT WAS A SIXTH
  # SITE.
  #
  #   Order Bump(Order o)
  #   Bump(o) -> o with { Total = :oops }
  #
  # It is not a sixth site: `Total: int` is written in the record declaration,
  # and that is the same place that governs probe 1. 33 §2's closing sentence
  # names the four forms that declare nothing — `e_op`, `e_tuple`, `e_list`,
  # `e_block` — and `e_with` is not among them.
  if grep -q 'syntax error\|illegal characters' <<<"$p2"; then
    echo "probe 2: did not compile, so nothing was measured. it said:"
    sed 's/^/           /' <<<"$p2"
  elif ! grep -q 'assigns Total a value' <<<"$p2"; then
    echo 'probe 2: o with { Total = :oops } was accepted. `with` is width-preserving,'
    echo "         which is a fact about NAMES and licenses nothing about values."
    echo "         it said:"
    sed 's/^/           /' <<<"${p2:-(nothing)}"
  fi

  # PROBE 3 — `with`, the NAME half. The defect ticket 36 did not name.
  #
  #   Bump(o) -> o with { Nope = 1 }
  #
  # Before F21 this compiled and raised `{badkey,'Nope'}` at run time. Two
  # assertions: the name must be refused at compile time, and the prose must not
  # say "builds" — `with` updates a record, and reusing construction's headline
  # verb tells the author something false about the expression they wrote.
  if grep -q 'syntax error\|illegal characters' <<<"$p3"; then
    echo "probe 3: did not compile, so nothing was measured. it said:"
    sed 's/^/           /' <<<"$p3"
  elif ! grep -q 'not declared by Order' <<<"$p3"; then
    echo "probe 3: o with { Nope = 1 } was accepted at compile time. it raises"
    echo "         {badkey,'Nope'} at run time, so 26 §2 was being enforced by the"
    echo "         BEAM rather than by the compiler. it said:"
    sed 's/^/           /' <<<"${p3:-(nothing)}"
  elif grep -q 'builds an Order' <<<"$p3"; then
    echo "probe 3: refused the name, but called the expression a build. \`with\`"
    echo "         updates a record — nothing is missing here, a name was invented."
    sed 's/^/           /' <<<"$p3"
  fi

  # PROBE 4 — THE PROBE A FIRES-ON-EVERYTHING CHECK FAILS.
  #
  # A correct record program: every field assigned a value its declaration
  # accepts, at construction and at `with`, including one assigned from a call
  # and one from a local binding. It must compile CLEAN.
  #
  # AND THE ABSENCE IS ASSERTED AGAINST A RUN THAT HAPPENED. `check-list-length.sh`
  # went green on its first real run over a module that never parsed, because a
  # probe asserting that no diagnostic appears is satisfied for free the moment
  # the run dies earlier. The exit code is captured beside the output here so
  # that failure is not merely detectable but impossible: clean means rc 0 AND
  # nothing said.
  if [ "$rc4" != "0" ]; then
    echo "probe 4: a correct record program did not compile (exit $rc4). an absent"
    echo "         diagnostic proves nothing if the run failed. it said:"
    sed 's/^/           /' <<<"${p4:-(nothing)}"
  elif [ -n "$p4" ]; then
    echo "probe 4: a correct record program compiled, and the compiler complained:"
    sed 's/^/           /' <<<"$p4"
  fi

  # PROBE 5 — THE SUBJECT. ENG-249.
  #
  #   int Bump(int n)
  #   Bump(n) -> n with { Total = 1 }
  #
  # Probes 2 and 3 ask about the fields; this one asks what is being updated.
  # `with` is a record update, and an `int` carries no field to update — so the
  # refusal is site 3's relation (`subject \ { Total: term }` is non-empty)
  # spoken in `with`'s verb, and the residual handed back is the member that
  # lacks the field. Here that member is the whole subject.
  if grep -q 'syntax error\|illegal characters' <<<"$p5"; then
    echo "probe 5: did not compile, so nothing was measured. it said:"
    sed 's/^/           /' <<<"$p5"
  elif ! grep -q 'updates Total on a value that may not carry it' <<<"$p5"; then
    echo "probe 5: n with { Total = 1 } on an int was accepted. the subject of a"
    echo "         \`with\` is unchecked, so it types as whatever it was and raises"
    echo "         {badmap, N} at run time. it said:"
    sed 's/^/           /' <<<"${p5:-(nothing)}"
  elif ! grep -qw 'int' <<<"$p5"; then
    echo "probe 5: refused the update but did not hand back the residual. the"
    echo "         member that lacks the field is the thing to discriminate on."
    sed 's/^/           /' <<<"$p5"
  fi
}

# ---------------------------------------------------------------------------
# --self-test
#
# FOUR STUBS. The one that matters is VALUE-ONLY.
#
#   SILENT      nothing is reported. The compiler as ticket 36 found it. Fails
#               probes 1, 2 and 3; PASSES probe 4.
#
#   CRYWOLF     every probe reports, including the correct program. The
#               over-informed stub: it says all the right words, so a gate
#               matching only on the words would call it a pass. Caught by
#               probe 4 alone, which is why probe 4 is not optional.
#
#   VALUE-ONLY  the ticket's stated delta, implemented exactly: one containment
#               per field at `e_record` and at `e_with`, and nothing about
#               names. Passes probes 1, 2 and 4 and fails ONLY probe 3. This is
#               the build a careful reader of the ticket produces, and catching
#               it is the whole reason the gate has a third probe.
#
#   SUBJECT-BLIND  F21 exactly as it shipped (ENG-249): both halves checked at
#               both spellings, and the base of a `with` never asked what it
#               is. Passes probes 1–4 and fails ONLY probe 5. This is what the
#               tree looked like for thirteen days with this gate green.
#
#   GOOD        the decided behaviour. Must pass all five.
#
#   BROKEN      nothing compiles. Every probe must fire, probe 4 included.
#
# The stubs fail on DIFFERENT probes, and the gate is believed only if it
# catches each one AND lets each one's other probes through. A check that fired
# on everything would catch all five stubs and be worthless — `check-shell.sh`'s
# lesson from ticket 15, written at a severity where the tree was already clean.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  fail=0

  # --- SILENT ------------------------------------------------------------
  mkdir -p "$CTL/silent"
  : > "$CTL/silent/P1.out"
  : > "$CTL/silent/P2.out"
  : > "$CTL/silent/P3.out"
  : > "$CTL/silent/P4.out"
  : > "$CTL/silent/P5.out"
  echo 0 > "$CTL/silent/P4.rc"
  silent="$(judge "$CTL/silent" || true)"
  for n in 1 2 3 5; do
    grep -q "^probe $n:" <<<"$silent" || {
      echo "SELF-TEST FAILED: probe $n missed the silent stub — the compiler as ticket 36 found it"
      fail=1
    }
  done
  if grep -q '^probe 4:' <<<"$silent"; then
    echo "SELF-TEST FAILED: probe 4 fired on the silent stub, whose probe 4 is correct."
    echo "                  a probe that fires on everything proves nothing."
    fail=1
  fi

  # --- CRYWOLF -----------------------------------------------------------
  #
  # Says every right word, on every program, including the correct one. Only
  # probe 4 can see it — an over-informed stub is invisible to any probe that
  # asks whether a diagnostic APPEARED.
  mkdir -p "$CTL/crywolf"
  cat > "$CTL/crywolf/P1.out" <<'OUT'
P1/P1.bs:7: error: Make assigns Id a value Order does not accept
  not covered by the declared type of Id:
    :oops
OUT
  cat > "$CTL/crywolf/P2.out" <<'OUT'
P2/P2.bs:7: error: Bump assigns Total a value Order does not accept
  not covered by the declared type of Total:
    :oops
OUT
  cat > "$CTL/crywolf/P3.out" <<'OUT'
P3/P3.bs:7: error: Grow updates an Order with the wrong fields
  not declared by Order:
    Nope
OUT
  cat > "$CTL/crywolf/P4.out" <<'OUT'
P4/P4.bs:9: error: New assigns Id a value Order does not accept
  not covered by the declared type of Id:
    int
OUT
  cat > "$CTL/crywolf/P5.out" <<'OUT'
P5/P5.bs:5: error: Bump updates Total on a value that may not carry it
  this member has no Total:
    int
  `with` updates a record: give it one, or discriminate on the tag
  first, in a clause head.
OUT
  echo 1 > "$CTL/crywolf/P4.rc"
  crywolf="$(judge "$CTL/crywolf" || true)"
  grep -q '^probe 4:' <<<"$crywolf" || {
    echo "SELF-TEST FAILED: probe 4 missed the cry-wolf stub. a stub that says every"
    echo "                  right word passes every probe that asks whether a"
    echo "                  diagnostic appeared — probe 4 is the only one that can"
    echo "                  see it, and it did not."
    fail=1
  }
  for n in 1 2 3 5; do
    if grep -q "^probe $n:" <<<"$crywolf"; then
      echo "SELF-TEST FAILED: probe $n fired on the cry-wolf stub, whose probe $n is correct."
      fail=1
    fi
  done

  # --- VALUE-ONLY --------------------------------------------------------
  #
  # THE STUB THIS GATE IS REALLY FOR. The ticket's delta, built exactly as
  # written: values checked at both spellings, names untouched. It is a real
  # improvement and it leaves a runtime crash in the tree.
  mkdir -p "$CTL/valueonly"
  cat > "$CTL/valueonly/P1.out" <<'OUT'
P1/P1.bs:7: error: Make assigns Id a value Order does not accept
  not covered by the declared type of Id:
    :oops
OUT
  cat > "$CTL/valueonly/P2.out" <<'OUT'
P2/P2.bs:7: error: Bump assigns Total a value Order does not accept
  not covered by the declared type of Total:
    :oops
OUT
  : > "$CTL/valueonly/P3.out"          # `Nope` sails through, exactly as before
  : > "$CTL/valueonly/P4.out"
  : > "$CTL/valueonly/P5.out"          # ...and so does the int: it never looked
  echo 0 > "$CTL/valueonly/P4.rc"
  valueonly="$(judge "$CTL/valueonly" || true)"
  grep -q '^probe 3:' <<<"$valueonly" || {
    echo "SELF-TEST FAILED: probe 3 missed the value-only stub — the third defect,"
    echo "                  which the ticket's own scope fence forbade looking for."
    fail=1
  }
  grep -q '^probe 5:' <<<"$valueonly" || {
    echo "SELF-TEST FAILED: probe 5 missed the value-only stub, which never looked"
    echo "                  at the subject either."
    fail=1
  }
  for n in 1 2 4; do
    if grep -q "^probe $n:" <<<"$valueonly"; then
      echo "SELF-TEST FAILED: probe $n fired on the value-only stub, whose probe $n is correct."
      echo "                  a probe that fires on everything proves nothing."
      fail=1
    fi
  done

  # --- SUBJECT-BLIND -----------------------------------------------------
  #
  # F21 as it shipped. Probes 1–4 are the compiler's real answers on
  # 2026-08-21; probe 5 is what it said about `n with { Total = 1 }` on an
  # `int`, which is nothing. The stub the fifth probe exists for.
  mkdir -p "$CTL/subjectblind"
  cp "$CTL/crywolf/P1.out" "$CTL/subjectblind/P1.out"
  cp "$CTL/crywolf/P2.out" "$CTL/subjectblind/P2.out"
  cp "$CTL/crywolf/P3.out" "$CTL/subjectblind/P3.out"
  : > "$CTL/subjectblind/P4.out"
  : > "$CTL/subjectblind/P5.out"
  echo 0 > "$CTL/subjectblind/P4.rc"
  subjectblind="$(judge "$CTL/subjectblind" || true)"
  grep -q '^probe 5:' <<<"$subjectblind" || {
    echo "SELF-TEST FAILED: probe 5 missed the subject-blind stub — F21 as it shipped,"
    echo "                  which this gate passed for thirteen days."
    fail=1
  }
  for n in 1 2 3 4; do
    if grep -q "^probe $n:" <<<"$subjectblind"; then
      echo "SELF-TEST FAILED: probe $n fired on the subject-blind stub, whose probe $n is correct."
      echo "                  a probe that fires on everything proves nothing."
      fail=1
    fi
  done

  # --- GOOD --------------------------------------------------------------
  mkdir -p "$CTL/good"
  cp "$CTL/crywolf/P1.out" "$CTL/good/P1.out"
  cp "$CTL/crywolf/P2.out" "$CTL/good/P2.out"
  cp "$CTL/crywolf/P3.out" "$CTL/good/P3.out"
  : > "$CTL/good/P4.out"
  cp "$CTL/crywolf/P5.out" "$CTL/good/P5.out"
  echo 0 > "$CTL/good/P4.rc"
  good="$(judge "$CTL/good" || true)"
  if [ -n "$good" ]; then
    echo "SELF-TEST FAILED: the gate rejected the decided behaviour:"
    sed 's/^/                  /' <<<"$good"
    fail=1
  fi

  # --- BROKEN ------------------------------------------------------------
  mkdir -p "$CTL/broken"
  for f in P1 P2 P3 P4 P5; do
    printf '%s/%s.bs:7: error: syntax error before: %s\n' "$f" "$f" "']'" \
      > "$CTL/broken/$f.out"
  done
  echo 1 > "$CTL/broken/P4.rc"
  broken="$(judge "$CTL/broken" || true)"
  for n in 1 2 3 4 5; do
    grep -q "^probe $n:" <<<"$broken" || {
      echo "SELF-TEST FAILED: probe $n went green over a module that did not compile."
      echo "                  an absent diagnostic is not a passing measurement."
      fail=1
    }
  done

  if [ "$fail" -eq 0 ]; then
    echo "self-test: caught the silent, cry-wolf, value-only and subject-blind stubs"
    echo "           on different probes, passed each one's other probes, passed the"
    echo "           correct control, and refused a run that never compiled — the"
    echo "           gate discriminates and does not pass vacuously"
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

mkdir -p "$WORK/P1" "$WORK/P2" "$WORK/P3" "$WORK/P4" "$WORK/P5"

cat > "$WORK/P1/P1.bs" <<'BS'
module P1

record Order { Id: int, Total: int }

public Order Make(int n)

Make(n) -> Order{ Id = :oops, Total = n }
BS

cat > "$WORK/P2/P2.bs" <<'BS'
module P2

record Order { Id: int, Total: int }

public Order Bump(Order o)

Bump(o) -> o with { Total = :oops }
BS

cat > "$WORK/P3/P3.bs" <<'BS'
module P3

record Order { Id: int, Total: int }

public Order Grow(Order o)

Grow(o) -> o with { Nope = 1 }
BS

# The control. Every field assigned a value its declaration accepts — a literal,
# a parameter, a local binding, a projection and a call return — at construction
# and at `with`. If the check is too eager, this is where it shows.
cat > "$WORK/P4/P4.bs" <<'BS'
module P4

record Order { Id: int, Total: int }

public int Double(int n)

Double(n) -> n * 2

public Order New(int id)

New(id) -> Order{ Id = id, Total = 0 }

public Order Pay(Order o)

Pay(o) -> o with { Total = 500 }

public Order Twice(Order o)

Twice(o) ->
    var t = Double(o.Total)
    o with { Total = t }
BS

# The subject. No record is declared at all: the only thing `with` could be
# updating here is an int, and an int carries no field.
cat > "$WORK/P5/P5.bs" <<'BS'
module P5

public int Bump(int n)

Bump(n) -> n with { Total = 1 }
BS

for p in P1 P2 P3 P4 P5; do
  # Captured, not piped: a probe that reports a diagnostic exits non-zero, and
  # for P1..P3 that is the expected shape rather than a failure of the gate.
  # P4's code is kept, because for P4 it is the measurement.
  set +e
  ( cd "$WORK" && "$BSC" --src-root . "$p" ) > "$WORK/$p.out" 2>&1
  echo $? > "$WORK/$p.rc"
  set -e
done

violations="$(judge "$WORK" || true)"

if [ -n "$violations" ]; then
  echo "a field assignment is not checked"
  echo
  printf '%s\n' "$violations"
  echo
  echo "ticket 36 and compiler/features/F21-field-value-obligations.md carry the decision."
  exit 1
fi

echo "  ok         Order{ Id = :oops } names the field and hands back :oops"
echo "  ok         o with { Total = :oops } is checked too, and opens no sixth site"
echo "  ok         o with { Nope = 1 } is refused at compile time, not at run time"
echo "  ok         a correct record program compiles clean, and is seen to compile"
echo "  ok         n with { Total = 1 } on an int is refused, and int is handed back"
echo
echo "a field assignment is checked, at both spellings, on both halves, and on its subject"
