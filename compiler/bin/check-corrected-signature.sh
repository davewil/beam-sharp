#!/usr/bin/env bash
#
# A RETURN-MISMATCH DIAGNOSTIC MUST HAND THE AGENT THE SIGNATURE TO PASTE.
#
# Ticket 23 §8: "when a clause returns outside its signature, the diagnostic
# carries the corrected signature to paste." §4's test for the contractual
# subset is §2's — does it hand the agent something to write? — and until F25
# `return_not_declared` printed the uncovered residual and stopped, which
# answers what is WRONG and not what to WRITE.
#
# THE PROBE THAT DECIDES WHETHER THE FIX IS RIGHT IS PROBE 3, NOT PROBE 1.
# Probe 1 is the happy path and every plausible implementation passes it. The
# two that a fix written to satisfy probe 1 gets wrong were both MEASURED before
# this gate was written:
#
#   Two offending clauses produce TWO diagnostics. A correction computed per
#   clause prints two contradictory pasteable lines — `int | :zero` on one and
#   `int | (:error, string)` on the other — and pasting either leaves the other
#   clause still wrong. The correction is a property of the FUNCTION.
#
#   `bs_types:to_string/1` renders a record as `{ Kind: :'M.Invoice', … }`.
#   Ticket 26 §1 mints that tag from the qualified module path, so a signature
#   carrying it hard-codes a mint instead of naming `Invoice`. It LOOKS
#   pasteable. A line that looks pasteable and is not is worse than no line,
#   because §2's whole argument is that the compiler hands over something usable.
#
# WHY PROBE 4 EXISTS. Probe 3 asserts an ABSENCE — no signature for a record
# residual — and an absence passes for free over a run that never compiled. So
# probe 4 requires a module that DOES compile to produce no diagnostic at all.
# The absence in probe 3 is protected by the presence in probe 4, structurally,
# and the BROKEN control below is what proves the pairing works rather than a
# comment claiming it does.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

HEADING='the signature its clauses justify:'

# ---------------------------------------------------------------------------
# judge — the whole of the gate's opinion, in one place.
#
# Reads P1.out … P4.out from a directory and prints one line per violation. A
# function over a directory so --self-test drives THIS code path with fixtures
# rather than a copy of it.
# ---------------------------------------------------------------------------
judge() {
  local dir="$1"
  local p1 p2 p3 p4

  p1="$(cat "$dir/P1.out")"
  p2="$(cat "$dir/P2.out")"
  p3="$(cat "$dir/P3.out")"
  p4="$(cat "$dir/P4.out")"

  # PROBE 1 — the line exists, and it is a whole signature.
  #
  #   public int Answer(int n)      with      Answer(n) -> :oops
  #
  # Asserted on the entire line rather than on the type fragment: a fix that
  # printed `int | :oops` alone would still leave the agent assembling a
  # signature, which is the work §2 says the compiler owns.
  if ! grep -qF "$HEADING" <<<"$p1"; then
    echo "probe 1: no corrected signature for a plain return mismatch."
    echo "         ticket 23 §8 is the whole of this gate: the diagnostic must"
    echo "         carry the line to paste, not only the residual."
  elif ! grep -qF 'public int | :oops Answer(int n)' <<<"$p1"; then
    echo "probe 1: the corrected signature is not the line to paste."
    echo "         expected: public int | :oops Answer(int n)"
    echo "         got:"
    sed 's/^/           /' <<<"$p1"
  fi

  # PROBE 2 — the residual survives beside it. Two different questions, and
  # ticket 04 made the first one the product surface, so the new line is an
  # addition rather than a replacement.
  if ! grep -qF 'not covered by the declared return type:' <<<"$p1"; then
    echo "probe 2: the uncovered residual was dropped."
    echo "         the new line answers what to WRITE; the residual answers what"
    echo "         is not COVERED. ticket 04 made the second one a product surface."
  fi

  # PROBE 3 — ONE correction for the function, and it names no mint tag.
  #
  # Two sub-conditions, both measured before this file existed. The count must
  # be two identical lines, not two different ones, and no rendering of a record
  # may reach a signature.
  local heads lines
  heads="$(grep -cF "$HEADING" <<<"$p2" || true)"
  lines="$(grep -cF 'public int | :zero | (:error, string) Go(int n)' <<<"$p2" || true)"
  if [ "$heads" != "2" ] || [ "$lines" != "2" ]; then
    echo "probe 3: two offending clauses did not get ONE function-wide signature."
    echo "         headings: $heads  matching lines: $lines  (both must be 2)"
    echo "         a per-clause correction prints two contradictory pasteable"
    echo "         lines and pasting either leaves the other clause wrong."
    sed 's/^/           /' <<<"$p2"
  fi
  if grep -qF "$HEADING" <<<"$p3"; then
    echo "probe 3: a signature was printed for a record residual."
    echo "         bs_types renders it as its MINT TAG, which ticket 26 §1 derives"
    echo "         from the qualified module path. pasting that hard-codes a mint"
    echo "         instead of naming the record. no line is the correct answer."
    sed 's/^/           /' <<<"$p3"
  fi
  # The mint-tag guard is SCOPED TO THE SYNTHESISED LINE and not to the output,
  # because the residual legitimately prints `Kind:` — ticket 04 made the
  # discriminator the missing case, and to_pattern renders it on purpose. What
  # must never carry a tag is the line offered for pasting, which is the line
  # after the heading. Checking the whole output instead would forbid the
  # correct behaviour, and the self-test's GOOD stub is what caught that.
  local minted
  minted="$(grep -A1 -F "$HEADING" <<<"$p1$p2$p3$p4" | grep -F 'Kind:' || true)"
  if [ -n "$minted" ]; then
    echo "probe 3: a mint tag reached a pasteable signature."
    sed 's/^/           /' <<<"$minted"
  fi
  # ... and the record case must still be reported at all. Without this the
  # probe above passes over a module that produced no output whatsoever.
  if ! grep -qF 'returns a value its signature does not declare' <<<"$p3"; then
    echo "probe 3: the record case reported no return mismatch at all."
    echo "         the refusal is meant to drop ONE line, not the diagnostic."
  fi

  # PROBE 4 — the clean control. A module that compiles must say nothing, which
  # is what makes probe 3's absences a measurement rather than a vacuum.
  if [ -n "$p4" ]; then
    echo "probe 4: a module that should compile produced output."
    echo "         probe 3 asserts absences and they are only meaningful while"
    echo "         this compile is clean."
    sed 's/^/           /' <<<"$p4"
  fi
}

# ---------------------------------------------------------------------------
# --self-test — build the defects this gate names and require a red on each.
#
# A gate that has never been seen to fail is not believed. Three stubs, each
# wrong in a different way, plus the decided behaviour and a run that never
# compiled. Every stub must also PASS the probes it does not break: a probe
# that fires on everything is worthless.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT
  fail=0

  good_p1="m.bs:3: error: Answer returns a value its signature does not declare
  not covered by the declared return type:
    :oops
  the signature its clauses justify:
    public int | :oops Answer(int n)"

  good_p2="m.bs:3: error: Go returns a value its signature does not declare
  not covered by the declared return type:
    :zero
  the signature its clauses justify:
    public int | :zero | (:error, string) Go(int n)
m.bs:4: error: Go returns a value its signature does not declare
  not covered by the declared return type:
    (:error, string)
  the signature its clauses justify:
    public int | :zero | (:error, string) Go(int n)"

  good_p3="m.bs:5: error: Make returns a value its signature does not declare
  not covered by the declared return type:
    { Kind: :'M4.Invoice' }"

  # --- SILENT ------------------------------------------------------------
  #
  # The defect F25 exists for: the residual is printed and nothing else. This
  # is the compiler as it stood at 0be76fb.
  mkdir -p "$CTL/silent"
  printf '%s\n' "m.bs:3: error: Answer returns a value its signature does not declare
  not covered by the declared return type:
    :oops" > "$CTL/silent/P1.out"
  printf '%s\n' "m.bs:3: error: Go returns a value its signature does not declare
  not covered by the declared return type:
    :zero
m.bs:4: error: Go returns a value its signature does not declare
  not covered by the declared return type:
    (:error, string)" > "$CTL/silent/P2.out"
  printf '%s\n' "$good_p3" > "$CTL/silent/P3.out"
  : > "$CTL/silent/P4.out"
  silent="$(judge "$CTL/silent" || true)"
  grep -q '^probe 1:' <<<"$silent" || { echo "SELF-TEST FAILED: probe 1 missed the silent stub — the reported defect"; fail=1; }
  grep -q '^probe 3:' <<<"$silent" || { echo "SELF-TEST FAILED: probe 3 missed the silent stub — no function-wide line either"; fail=1; }
  for n in 2 4; do
    if grep -q "^probe $n:" <<<"$silent"; then
      echo "SELF-TEST FAILED: probe $n fired on the silent stub, which it should pass."
      echo "                  a probe that fires on everything proves nothing."
      fail=1
    fi
  done

  # --- PER-CLAUSE --------------------------------------------------------
  #
  # THE STUB THAT MOTIVATES THIS FILE. Every line is present and well-formed,
  # and each clause was corrected on its own — so the compiler prints two
  # different signatures for one function and neither is sufficient. A gate
  # that only asked "is the heading there?" would go green over this.
  mkdir -p "$CTL/perclause"
  printf '%s\n' "$good_p1" > "$CTL/perclause/P1.out"
  printf '%s\n' "m.bs:3: error: Go returns a value its signature does not declare
  not covered by the declared return type:
    :zero
  the signature its clauses justify:
    public int | :zero Go(int n)
m.bs:4: error: Go returns a value its signature does not declare
  not covered by the declared return type:
    (:error, string)
  the signature its clauses justify:
    public int | (:error, string) Go(int n)" > "$CTL/perclause/P2.out"
  printf '%s\n' "$good_p3" > "$CTL/perclause/P3.out"
  : > "$CTL/perclause/P4.out"
  perclause="$(judge "$CTL/perclause" || true)"
  grep -q '^probe 3:' <<<"$perclause" || {
    echo "SELF-TEST FAILED: probe 3 accepted a per-clause correction. this is the"
    echo "                  defect the gate exists for: two contradictory pasteable"
    echo "                  lines for one function, neither of them sufficient."
    fail=1
  }
  for n in 1 2 4; do
    if grep -q "^probe $n:" <<<"$perclause"; then
      echo "SELF-TEST FAILED: probe $n fired on the per-clause stub, which it should pass."
      fail=1
    fi
  done

  # --- OVERREACH ---------------------------------------------------------
  #
  # The OVER-INFORMED stub: it prints a signature everywhere, including where
  # there is nothing writable to print. Its record line is structurally correct
  # and carries a mint tag, which is the plausible-but-wrong fix.
  mkdir -p "$CTL/overreach"
  printf '%s\n' "$good_p1" > "$CTL/overreach/P1.out"
  printf '%s\n' "$good_p2" > "$CTL/overreach/P2.out"
  printf '%s\n' "m.bs:5: error: Make returns a value its signature does not declare
  not covered by the declared return type:
    { Kind: :'M4.Invoice' }
  the signature its clauses justify:
    public { Kind: :'M4.Order', Id: int, Total: int } | { Kind: :'M4.Invoice', Id: int, Total: int } Make(int n)" > "$CTL/overreach/P3.out"
  : > "$CTL/overreach/P4.out"
  overreach="$(judge "$CTL/overreach" || true)"
  grep -q '^probe 3:' <<<"$overreach" || {
    echo "SELF-TEST FAILED: probe 3 accepted a mint tag in a pasteable signature."
    echo "                  that line looks usable and is not, which is the failure"
    echo "                  mode ticket 23 §2 exists to prevent."
    fail=1
  }
  for n in 1 2 4; do
    if grep -q "^probe $n:" <<<"$overreach"; then
      echo "SELF-TEST FAILED: probe $n fired on the overreach stub, which it should pass."
      fail=1
    fi
  done

  # --- GOOD --------------------------------------------------------------
  mkdir -p "$CTL/good"
  printf '%s\n' "$good_p1" > "$CTL/good/P1.out"
  printf '%s\n' "$good_p2" > "$CTL/good/P2.out"
  printf '%s\n' "$good_p3" > "$CTL/good/P3.out"
  : > "$CTL/good/P4.out"
  good="$(judge "$CTL/good" || true)"
  if [ -n "$good" ]; then
    echo "SELF-TEST FAILED: the gate rejected the decided behaviour:"
    sed 's/^/                  /' <<<"$good"
    fail=1
  fi

  # --- BROKEN ------------------------------------------------------------
  #
  # Nothing compiled. Probe 3's record half asserts an ABSENCE and goes green
  # for free here; its companion presence check and probe 4 are what catch it.
  mkdir -p "$CTL/broken"
  : > "$CTL/broken/P1.out"
  : > "$CTL/broken/P2.out"
  : > "$CTL/broken/P3.out"
  printf '%s\n' "m.bs:1: error: syntax error before: 'module'" > "$CTL/broken/P4.out"
  broken="$(judge "$CTL/broken" || true)"
  for n in 1 2 3 4; do
    grep -q "^probe $n:" <<<"$broken" || {
      echo "SELF-TEST FAILED: probe $n went green over a run that never compiled."
      echo "                  an absent diagnostic is not a passing measurement."
      fail=1
    }
  done

  if [ "$fail" -eq 0 ]; then
    echo "self-test: caught three defects on different probes — the silent case, the"
    echo "           per-clause correction that prints two contradictory lines, and"
    echo "           the mint tag in a pasteable signature — passed each stub's other"
    echo "           probes, passed the decided behaviour, and refused a run that"
    echo "           never compiled. the gate discriminates and does not pass vacuously"
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

mkdir -p "$WORK/src/P1" "$WORK/src/P2" "$WORK/src/P3" "$WORK/src/P4" "$WORK/out"

cat > "$WORK/src/P1/p1.bs" <<'BS'
module P1
public int Answer(int n)
Answer(n) -> :oops
BS

cat > "$WORK/src/P2/p2.bs" <<'BS'
module P2
public int Go(int n)
Go(0) -> :zero
Go(n) -> (:error, "bad")
BS

# A record in the RESIDUAL. `Invoice` and `Order` carry the same fields, so what
# separates them is the tag ticket 26 §1 mints — which is exactly the thing that
# must not reach a pasteable line.
cat > "$WORK/src/P3/p3.bs" <<'BS'
module P3
record Order   { Id: int, Total: int }
record Invoice { Id: int, Total: int }
public Order Make(int n)
Make(n) -> Invoice{ Id = n, Total = 0 }
BS

# The clean control. It must compile silently, and probe 3's absences mean
# nothing without it.
cat > "$WORK/src/P4/p4.bs" <<'BS'
module P4
public atom Answer(int n)
Answer(n) -> :ok
BS

for p in P1 P2 P3 P4; do
  "$BSC" --src-root "$WORK/src" -o "$WORK/out" "$WORK/src/$p" \
      > "$WORK/$p.out" 2>&1 || true
  # The gate reads the diagnostic text only; the path prefix varies per run.
  sed -i.bak "s#$WORK/src/$p/##g" "$WORK/$p.out" && rm -f "$WORK/$p.out.bak"
done

violations="$(judge "$WORK" || true)"

if [ -n "$violations" ]; then
  echo "the return-mismatch diagnostic does not hand over a signature to paste:"
  echo
  sed 's/^/  /' <<<"$violations"
  echo
  echo "ticket 23 §8, built as F25. run --self-test to see the gate fail on purpose."
  exit 1
fi

echo "corrected signature: 4 probes — the line is present and pasteable, the"
echo "                     residual survives beside it, two clauses share one"
echo "                     function-wide correction, no mint tag reaches a"
echo "                     signature, and a clean module stays silent"
