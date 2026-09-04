#!/usr/bin/env bash
#
# check-decisions-derived.sh — decisions.md is assembled from the tickets, and
# this is what stops it being edited anywhere else.
#
# WHY THIS EXISTS (2026-09-04, ENG-310 stage 2)
#
# ENG-310's chosen shape is derive-after-backfill. Stage 1 (`38acb27`) gave
# every resolved ticket a `## Answer` in one spelling. Stage 2 makes
# decisions.md GENERATED, because a hand-kept second copy of the tickets is a
# second source of truth and it had already drifted in every way a second
# source of truth drifts:
#
#   * six resolved tickets had no entry at all, in a file whose own header
#     promises one per closed ticket (fixed in stage 1);
#   * ticket 44's decision sat inside ticket 63's bullet for weeks, which is
#     why 63's was the longest entry in the file (fixed in stage 1);
#   * ticket 40's preserved fog body opened with a column-0 bullet, so every
#     parser read it as a second ticket-40 entry (fixed in `ea5d453`);
#   * map.md's decisions index — the file that is supposed to BE the index of
#     decisions.md — is missing eleven of the sixty-one entries and orders
#     several differently. That one is NOT fixed here; see ENG-257.
#
# Every one of those is a copy disagreeing with its original. Generation is the
# only fix that cannot recur, because after it there is no second copy to
# disagree.
#
# WHAT IT CHECKS — one thing. Re-assemble decisions.md from the tickets and the
# order manifest, and require the result to be the committed bytes. `--write`
# on bin/gen-decisions.py is the fix for every way this goes red.
#
# WHY THAT IS NOT THE SAME CHECK AS check-decisions.sh. That gate asks whether
# the ANSWER exists and is the ticket's own. This one asks whether decisions.md
# still equals its inputs. A ticket can own a perfectly good answer while
# somebody hand-edits its entry in decisions.md, and stage 1's gate would stay
# green through it — that hand-edit is exactly how the four defects above got
# in.
#
# Usage:  bin/check-decisions-derived.sh [--self-test]

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEN="$ROOT/bin/gen-decisions.py"

# ---------------------------------------------------------------------------
# --self-test
#
# FIVE POSITIVE CONTROLS, EACH CARRYING ITS OWN MARKER. A gate that assembles
# anything at all exits non-zero on all five, so "did it fail" proves nothing;
# each control demands the specific string only its own defect can produce.
#
# The fixture is the REAL tickets, decisions.md and manifest copied to a
# temporary tree with one defect introduced. A control built out of two toy
# tickets would pass against a generator that cannot handle ticket 16's three
# entries or the one entry that belongs to no ticket at all, which are the two
# shapes most likely to be got wrong.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  fixture="$(mktemp -d "${TMPDIR:-/tmp}/check-decisions-derived.XXXXXX")"
  trap 'rm -rf "$fixture"' EXIT

  mkdir -p "$fixture/wayfinder" "$fixture/compiler"
  cp "$ROOT/wayfinder/decisions.md" "$fixture/wayfinder/"
  cp "$ROOT/wayfinder/decisions.order" "$fixture/wayfinder/"
  cp -R "$ROOT/wayfinder/issues" "$fixture/wayfinder/issues"
  cp "$ROOT/compiler/README.md" "$fixture/compiler/README.md"

  pristine="$fixture/pristine"
  cp -R "$fixture/wayfinder" "$pristine"

  restore() {
    rm -rf "$fixture/wayfinder"
    cp -R "$pristine" "$fixture/wayfinder"
  }

  # Run the generator over the fixture, capturing both streams and the status.
  run_fixture() {
    set +e
    python3 "$GEN" --check --wayfinder "$fixture/wayfinder" >"$fixture/out" 2>&1
    fixture_status=$?
    set -e
  }

  fails=0
  control() {
    local name="$1" want_marker="$2"
    run_fixture
    if [ "$fixture_status" -eq 0 ]; then
      echo "  SELFTEST   $name: the gate passed over a defect it must refuse"
      fails=1
    elif ! grep -qF -e "$want_marker" "$fixture/out"; then
      echo "  SELFTEST   $name: refused, but not for its own reason"
      echo "             expected to see: $want_marker"
      sed 's/^/             /' "$fixture/out" | head -8
      fails=1
    else
      echo "  ok         $name refused, naming its own defect"
    fi
    restore
  }

  # 1. HANDEDIT — decisions.md edited directly, which is the habit this gate
  #    replaces. The generated region must lose to the tickets.
  python3 - "$fixture/wayfinder/decisions.md" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.index('\n- ')
open(p, 'w').write(s[:i] + '\n- ZZ-HANDEDIT-ZZ a bullet nobody generated\n' + s[i + 1:])
PY
  control HANDEDIT ZZ-HANDEDIT-ZZ

  # 2. TICKETEDIT — a ticket's entry block edited and decisions.md not
  #    regenerated. The committed file must lose to the ticket.
  python3 - "$fixture/wayfinder/issues" <<'PY'
import os, sys
d = sys.argv[1]
for fn in sorted(os.listdir(d)):
    p = os.path.join(d, fn)
    s = open(p).read()
    if '```decisions-entry\n' in s:
        s = s.replace('```decisions-entry\n', '```decisions-entry\n- ZZ-TICKETEDIT-ZZ\n', 1)
        open(p, 'w').write(s)
        break
else:
    sys.exit('no ticket carries a decisions-entry block — fixture is wrong')
PY
  control TICKETEDIT ZZ-TICKETEDIT-ZZ

  # 3. LOSTBLOCK — a ticket's entry block deleted. The manifest still asks for
  #    it, so the generator must name the file rather than emit a short file.
  #    This is the control that would catch "an absent block silently vanishes".
  lost="$(python3 - "$fixture/wayfinder/issues" <<'PY'
import os, sys
d = sys.argv[1]
for fn in sorted(os.listdir(d)):
    p = os.path.join(d, fn)
    s = open(p).read()
    if '```decisions-entry\n' in s:
        head, rest = s.split('```decisions-entry\n', 1)
        _, tail = rest.split('\n```', 1)
        open(p, 'w').write(head + tail.lstrip('\n'))
        print(fn)
        break
else:
    sys.exit('fixture is wrong')
PY
)"
  control LOSTBLOCK "$lost"

  # 4. MANIFESTDROP — an entry removed from decisions.order. Its text is still
  #    in its ticket, so nothing else notices; the assembled file is simply
  #    missing an entry, which is the failure mode that lost six of them.
  dropped="$(python3 - "$fixture/wayfinder/decisions.order" <<'PY'
import sys
p = sys.argv[1]
lines = open(p).read().split('\n')
for i, l in enumerate(lines):
    if l.strip() and not l.lstrip().startswith('#'):
        print('issues/%s-' % l.strip().split(':')[0])
        del lines[i]
        break
open(p, 'w').write('\n'.join(lines))
PY
)"
  control MANIFESTDROP "$dropped"

  # 5. NOMARKERS — the generated region's markers removed, which is how a
  #    hand-editor would most plausibly disable this gate. Guessing where the
  #    region starts is the one thing the generator must refuse to do.
  python3 - "$fixture/wayfinder/decisions.md" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
open(p, 'w').write(s.replace('<!-- BEGIN GENERATED', '<!-- once generated', 1))
PY
  control NOMARKERS 'no BEGIN/END GENERATED markers'

  # NEGATIVE CONTROL. Called directly, so the exit status examined is the
  # gate's own — routed through the helper above it would be the helper's.
  set +e
  python3 "$GEN" --check --wayfinder "$fixture/wayfinder" >"$fixture/out" 2>&1
  clean_status=$?
  set -e
  if [ "$clean_status" -ne 0 ]; then
    echo "  SELFTEST   the unmodified tree does not assemble to itself:"
    sed 's/^/             /' "$fixture/out" | head -20
    fails=1
  else
    echo "  ok         the unmodified tree assembles to exactly itself"
  fi

  if [ "$fails" -ne 0 ]; then
    echo
    echo "  self-test FAILED"
    exit 1
  fi
  echo "  self-test passed: 5 controls refused for their own reasons, 1 clean tree accepted"
  exit 0
fi

exec python3 "$GEN" --check
