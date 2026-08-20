#!/usr/bin/env bash
#
# THE AUDITION'S CHECK: does the worker's `switchcheck` say what the compiler says?
#
# Usage:  ./check.sh <dir-containing-switchcheck>
#         ./check.sh --self-test
#
# It compares TAG SETS per case against `expected/`, which `oracle.sh` recorded
# by running the reference compiler. The worker never sees `expected/`.
#
# WHY TAGS AND NOT PASS/FAIL. A checker that printed `switch_inexhaustive` for
# every input would agree with the compiler on the rejecting cases and be
# worthless. Comparing the SET means a missing diagnostic and an invented one
# both fail, and a clean program that draws any output fails too. This is the
# same shape as `compiler/bin/check-helper-agrees.sh`, for the same reason: a
# harness that can only say "no" cannot tell knowing from guessing.
#
# WHAT A FAILURE MEANS IS DELIBERATELY AMBIGUOUS, AND THAT IS THE POINT. One
# worker missing a clause is a weak worker; SEVERAL workers missing the SAME
# clause is a hole in the specification. The audition is run across models on
# the identical packet so the two can be told apart — which makes this as much a
# test of the handoff document as of the model.
#
# THE SCORE THAT COUNTS IS THE HELD-OUT ONE.
#
# This check invokes the worker with the case's own path — `cases/c03-inexhaustive/
# Missing/in.bs`. The case's IDENTITY is in argv[1], and the worker's sandbox
# contains those directory names. Measured 2026-08-20: a stub that parses nothing
# and merely switches on that name scored 8/8 on the visible set, matching a real
# submission exactly. The visible cases cannot tell an implementation from a
# lookup table, because the worker is told the answers' index.
#
# So `heldout/` is marked too and never staged. A worker sees `cases/`; it is
# scored on both. The two numbers mean different things and are printed
# separately: the visible score says the worker fitted the examples, the held-out
# score says it implemented the specification. Reporting one total would blur
# exactly the distinction this file exists to draw.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run one implementation over one set of cases; print one line per disagreement.
compare() {
  local impl="$1"
  local set_dir="${2:-$HERE/cases}"
  local dir name want got bs
  for dir in "$set_dir"/*/; do
    [ -d "$dir" ] || continue
    name="$(basename "$dir")"
    bs="$(find "$dir" -name '*.bs' | head -1)"
    want="$(tr '\n' ' ' < "$HERE/expected/$name.tags" 2>/dev/null | sed 's/ *$//')"
    got="$("$impl" "$bs" 2>/dev/null | tr '[:upper:]' '[:lower:]' | grep -oE '[a-z_]+' | sort -u | tr '\n' ' ' | sed 's/ *$//')"
    if [ "$want" != "$got" ]; then
      printf '%-28s compiler says [%s] — this says [%s]\n' \
             "$name" "${want:-clean}" "${got:-clean}"
    fi
  done
}

# Both sets at once. The self-test's question is only "is this stub rejected
# ANYWHERE?", so it must look everywhere the real run looks — a control that
# was checked against the visible set alone is how this hole got in.
compare_all() {
  compare "$1" "$HERE/cases"
  compare "$1" "$HERE/heldout"
}

# ---------------------------------------------------------------------------
# --self-test: the check must reject a lazy implementation and accept a correct
# one. Only the pair is evidence — a check that failed everything would satisfy
# the first half and pass nothing ever again.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  # POSITIVE CONTROL — says nothing, ever. Passes the three clean cases by
  # accident, which is exactly the accident this check must not reward.
  printf '#!/usr/bin/env bash\nexit 0\n' > "$CTL/silent"

  # POSITIVE CONTROL — cries wolf on everything. The mirror-image failure.
  printf '#!/usr/bin/env bash\necho switch_inexhaustive\n' > "$CTL/paranoid"

  # POSITIVE CONTROL — the overfit. It never opens the file: it switches on the
  # case directory name, which this check puts in argv[1] and which is visible
  # inside every worker's sandbox.
  #
  # The other two stubs are UNDER-informed — they say too little or too much
  # without looking. This one is OVER-informed, and it is the failure that
  # actually threatens the audition, because its output is indistinguishable
  # from a correct implementation's on every case it was shown. Only a case it
  # was NOT shown can separate them, which is what `heldout/` is for.
  #
  # Hardcoded to the visible names on purpose. If someone deletes `heldout/`,
  # this stub starts passing and the self-test goes red — the fence cannot be
  # removed quietly.
  cat > "$CTL/lookup" <<'SH'
#!/usr/bin/env bash
case "$1" in
  *c01-*|*c02-*|*c05-*) ;;
  *c03-*|*c06-*) echo switch_inexhaustive ;;
  *c04-*)        echo unreachable_arm ;;
  *c07-*)        echo rebinding ;;
  *c08-*)        echo return_not_declared ;;
esac
SH

  # NEGATIVE CONTROL — delegates to the reference compiler, so it is correct by
  # construction. If the check cannot pass THIS, it cannot be passed at all.
  REPO="$(cd "$HERE/../.." && pwd)"
  BSC="$REPO/compiler/_build/default/bin/bsc"
  [ -x "$BSC" ] || BSC="$REPO/compiler/_build/test/bin/bsc"
  cat > "$CTL/oracle-impl" <<SH
#!/usr/bin/env bash
f="\$1"
mod_dir="\$(dirname "\$f")"
root="\$(dirname "\$mod_dir")"
{ "$BSC" --diagnostics term --src-root "\$root" -o "\$(mktemp -d)" "\$mod_dir" 2>/dev/null || true; } \\
  | sed -n 's/.*tag => \\([a-z_][a-z_0-9]*\\).*/\\1/p' | sort -u
SH
  chmod +x "$CTL/silent" "$CTL/paranoid" "$CTL/lookup" "$CTL/oracle-impl"

  fail=0
  [ -n "$(compare_all "$CTL/silent")"   ] || { echo "SELF-TEST FAILED: the silent stub was accepted"; fail=1; }
  [ -n "$(compare_all "$CTL/paranoid")" ] || { echo "SELF-TEST FAILED: the cry-wolf stub was accepted"; fail=1; }

  # The overfit stub must be caught, and it must be caught BY THE HELD-OUT SET.
  # Checking only that it fails somewhere would pass even if a visible case
  # happened to catch it, which would leave the real hole open.
  if [ -z "$(compare "$CTL/lookup" "$HERE/heldout")" ]; then
    echo "SELF-TEST FAILED: a stub that parses nothing — switching only on the case"
    echo "                  directory name — was accepted by the held-out set."
    echo "                  The audition cannot tell an implementation from a lookup"
    echo "                  table; add held-out cases until it can."
    fail=1
  fi

  correct="$(compare_all "$CTL/oracle-impl")"
  if [ -n "$correct" ]; then
    echo "SELF-TEST FAILED: a correct implementation was rejected —"
    printf '  %s\n' "$correct"
    echo "  the check is unpassable, which is worse than no check"
    fail=1
  fi

  if [ "$fail" -eq 0 ]; then
    echo "self-test: rejected the silent stub, the cry-wolf stub and the lookup-table"
    echo "           stub — the last on a case it had never seen — and accepted the"
    echo "           compiler-backed one. The check discriminates."
    exit 0
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
WORKDIR="${1:-.}"
IMPL="$WORKDIR/switchcheck"

[ -x "$IMPL" ] || { echo "no executable ./switchcheck in $WORKDIR — the packet asks for one"; exit 1; }
ls "$HERE"/expected/*.tags >/dev/null 2>&1 || { echo "no expectations — run ./oracle.sh first"; exit 1; }

count_in() { find "$1" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' '; }

# `wc -l` on an empty string still counts one line, so the empty case is
# separate — otherwise a worker with no failures scores one short of perfect.
count_lines() {
  if [ -z "$1" ]; then
    echo 0
  else
    printf '%s\n' "$1" | wc -l | tr -d ' '
  fi
}

seen_total=$(count_in "$HERE/cases")
held_total=$(count_in "$HERE/heldout")

seen_bad="$(compare "$IMPL" "$HERE/cases")"
held_bad="$(compare "$IMPL" "$HERE/heldout")"

seen_wrong=$(count_lines "$seen_bad")
held_wrong=$(count_lines "$held_bad")

[ -n "$seen_bad" ] && { echo "-- cases the worker was given --"; printf '%s\n' "$seen_bad"; echo; }
[ -n "$held_bad" ] && { echo "-- held-out cases the worker never saw --"; printf '%s\n' "$held_bad"; echo; }

printf 'visible  %s/%s\n'  "$((seen_total - seen_wrong))" "$seen_total"
printf 'held-out %s/%s\n'  "$((held_total - held_wrong))" "$held_total"

# THE TWO SCORES ARE READ TOGETHER, AND THE GAP IS THE INTERESTING NUMBER.
# High visible with low held-out is the signature of fitting the examples rather
# than implementing the specification — the failure the visible set alone cannot
# see. It is called out here so a reader does not have to notice it unaided.
if [ "$held_total" -gt 0 ] && [ "$seen_wrong" -eq 0 ] && [ "$held_wrong" -gt 0 ]; then
  echo
  echo "every visible case passed and $held_wrong held-out case(s) failed — this fitted the"
  echo "examples rather than the specification, and the visible set could not have shown it."
fi

[ -n "$seen_bad$held_bad" ] && exit 1
echo
echo "all $((seen_total + held_total)) cases agree with the reference compiler"
