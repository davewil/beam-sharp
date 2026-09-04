#!/usr/bin/env bash
#
# check-decisions-size.sh — decisions.md stays small enough to read.
#
# WHY THIS EXISTS (2026-09-05, ENG-310)
#
# ENG-310 was raised because the wayfinder corpus had outgrown reading, and it
# wrote its acceptance test down on the day it was filed: a reader who has
# never seen this project can answer "was X decided, and where" without loading
# more than a few hundred lines. It also said that test should be written
# first. Two stages of work then landed under the issue — a backfill gate and a
# generator — and neither wrote it. Measured after each:
#
#   decisions.md   1,778 lines at filing  →  1,886 after stage 1  →  1,910 after stage 2
#   issues/       20,247                  → 21,719               → 24,169
#
# David, 2026-09-05: "So this was in fact a massive fail of the goal." This gate
# is that acceptance test, written third instead of first. It was red at 1,910
# lines the moment it existed, which is the honest starting point.
#
# WHAT IT CHECKS — one number. decisions.md is at most BUDGET lines. That is
# the file a reader opens after map.md to learn what was decided, so it is the
# file whose length IS the read cost the issue names.
#
# WHY THIS BUDGET CANNOT BIND ON ABSENCE, which is the failure check-map.sh's
# budget has had twice. A line budget on a hand-kept file makes an author omit
# an entry rather than shorten one, because omitting is silent. decisions.md is
# generated: an entry cannot be omitted without check-decisions.sh's NOENTRY or
# check-decisions-derived.sh's DRIFT going red. So the only way to satisfy this
# gate is to make an entry SHORTER — edit its lead sentence in the ticket — and
# that is the pressure the issue wants. It is also why the budget is tight
# rather than generous: headroom here is not safety, it is the sprawl coming
# back one sentence at a time.
#
# Usage:  bin/check-decisions-size.sh [--self-test]

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# `CHECK_DECISIONS_SIZE_FILE` exists for --self-test, which points this gate
# at fixtures. Nothing else sets it.
FILE="${CHECK_DECISIONS_SIZE_FILE:-$ROOT/wayfinder/decisions.md}"

# One line per entry plus the preamble. At 61 entries the generated file is
# ~190 lines; 300 leaves room for roughly fifty more tickets before an author
# has to shorten anything, and no room at all for entries to grow back into
# paragraphs.
BUDGET=300

[ -f "$FILE" ] || { echo "no decisions.md at $FILE" >&2; exit 2; }

# ---------------------------------------------------------------------------
# --self-test
#
# ONE CHECK, ONE POSITIVE CONTROL, ONE NEGATIVE. The control is a file one line
# over the budget, not a thousand over, because a gate that only fires on the
# absurd case has not been shown to fire on the boundary. The negative control
# is a file exactly AT the budget, for the same reason.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  fixture="$(mktemp -d "${TMPDIR:-/tmp}/check-decisions-size.XXXXXX")"
  trap 'rm -rf "$fixture"' EXIT
  fails=0

  seq 1 "$((BUDGET + 1))" | sed 's/^/- entry /' > "$fixture/over.md"
  set +e
  CHECK_DECISIONS_SIZE_FILE="$fixture/over.md" "${BASH_SOURCE[0]}" > "$fixture/out" 2>&1
  st=$?
  set -e
  if [ "$st" -eq 0 ]; then
    echo "  SELFTEST   a file one line over the budget was accepted"
    fails=1
  elif ! grep -q 'OVER' "$fixture/out"; then
    echo "  SELFTEST   refused, but without the OVER marker"
    fails=1
  else
    echo "  ok         OVER fires on a file one line past the budget"
  fi

  seq 1 "$BUDGET" | sed 's/^/- entry /' > "$fixture/at.md"
  set +e
  CHECK_DECISIONS_SIZE_FILE="$fixture/at.md" "${BASH_SOURCE[0]}" > "$fixture/out" 2>&1
  st=$?
  set -e
  if [ "$st" -ne 0 ]; then
    echo "  SELFTEST   a file exactly at the budget was refused:"
    sed 's/^/             /' "$fixture/out"
    fails=1
  else
    echo "  ok         a file exactly at the budget is accepted"
  fi

  if [ "$fails" -ne 0 ]; then
    echo "  self-test FAILED"
    exit 1
  fi
  echo "  self-test passed: refuses one over, accepts exactly at — it discriminates"
  exit 0
fi

lines=$(wc -l < "$FILE" | tr -d ' ')
if [ "$lines" -le "$BUDGET" ]; then
  printf '  %-10s decisions.md is %s lines (budget %s)\n' "ok" "$lines" "$BUDGET"
  exit 0
fi

printf '  %-10s decisions.md is %s lines, over the %s budget\n' "OVER" "$lines" "$BUDGET"
echo
echo "  This is ENG-310's acceptance test: what was decided, readable in a few"
echo "  hundred lines. decisions.md is generated, so the fix is never to drop an"
echo "  entry — shorten its lead sentence in the ticket's ## Decisions entry block"
echo "  and run bin/gen-decisions.py --write."
exit 1
