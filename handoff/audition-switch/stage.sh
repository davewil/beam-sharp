#!/usr/bin/env bash
#
# Stage one working directory per candidate model.
#
# Each worker gets PACKET.md and cases/ — and NOT expected/, and NOT heldout/.
# The boundary is enforced by what is on disk rather than by asking politely in
# the spec: a worker cannot read answers that were never copied into its
# sandbox. The spec still states the rule, because a worker that goes looking is
# itself a finding.
#
# THERE ARE TWO SECRETS NOW, NOT ONE. `expected/` holds the answers to the
# visible cases; `heldout/` holds cases the worker is scored on and never shown.
# A leak check written for one secret's name permits the other silently, so
# `leaks()` names both and the self-test plants both. Staging `heldout/` would
# not look like a leak — the worker would simply score well — which is precisely
# why it has to be caught on disk rather than noticed in a result.
#
#   ./stage.sh <workdir>
#
# Creates <workdir>/<model-key>/ for each key named below.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# NOT `for key in $KEYS` — this shell word-splits differently under zsh, where an
# unquoted parameter stays one word and the loop silently runs once on a
# nonsense name. An array is the portable spelling.
# `grok` joined on 2026-08-22, when the codex lane returned "You've hit your
# usage limit … try again at Aug 25th" on both attempts and never saw the
# packet. A lane that cannot bill is not a weak candidate — it is no
# measurement at all, and the audition's argument needs breadth: one worker
# missing a clause is a weak worker, several missing the SAME clause is a hole
# in the specification. Grok bills to a different plan, so it restores the
# fourth seat without waiting three days.
KEYS=(codex grok copilot-sonnet5 copilot-haiku45 free-deepseek)

# Are the answers reachable from anywhere under a staged tree? Factored out so
# --self-test can point it at a tree with a deliberate leak; testing it by
# planting a directory inside a real run does not work, because staging deletes
# and recreates each worker directory first — the plant was erased rather than
# detected, which told us nothing about the check.
leaks() {
  find "$1" -maxdepth 2 -type d \( -name 'expected' -o -name 'heldout' \) 2>/dev/null
}

if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT
  mkdir -p "$CTL/clean/worker/cases" "$CTL/leaky/worker/expected" "$CTL/held/worker/heldout"
  fail=0
  [ -z "$(leaks "$CTL/clean")" ] || { echo "SELF-TEST FAILED: a clean tree was reported as leaking"; fail=1; }
  [ -n "$(leaks "$CTL/leaky")" ] || { echo "SELF-TEST FAILED: a planted expected/ was NOT found"; fail=1; }
  # Planted separately from expected/, not alongside it: a check that only ever
  # sees the two together would pass while blind to heldout/ on its own.
  [ -n "$(leaks "$CTL/held")"  ] || { echo "SELF-TEST FAILED: a planted heldout/ was NOT found — the exam would be staged with the tutorial"; fail=1; }
  # CONTROL — THE RUN MANIFEST MUST BIND TO THE HARNESS THAT STAGED IT.
  #
  # The defect this replaces was a hand-written absolute path pointing at a
  # DIFFERENT copy of the repo. So the control stages into a scratch workdir and
  # asserts every emitted `check` names THIS directory's check.sh -- and, in the
  # other direction, that it names no other checkout. Asserting only "the path
  # is absolute" would have passed happily on the broken manifest.
  # THE SELF-TEST MUST NOT LEAVE A RUN MANIFEST POINTING AT ITS OWN SCRATCH DIR.
  # Staging writes `manifest.run.json`, and this control stages into $CTL, which
  # the EXIT trap deletes. Without save-and-restore the self-test would leave
  # behind a manifest whose workdir no longer exists — every sandbox empty, every
  # lane scored `no executable ./switchcheck`, and the cause three commands back.
  # Exactly the class this whole control was added to close, so it does not get
  # to arrive through the control itself.
  SAVED=""
  [ -f "$HERE/manifest.run.json" ] && { SAVED="$CTL/manifest.run.json.saved"; cp "$HERE/manifest.run.json" "$SAVED"; }
  # shellcheck disable=SC2329  # invoked from the EXIT trap below, which shellcheck cannot follow
  restore_run_manifest() {
    if [ -n "$SAVED" ]; then cp "$SAVED" "$HERE/manifest.run.json"; else rm -f "$HERE/manifest.run.json"; fi
  }
  trap 'restore_run_manifest; rm -rf "$CTL"' EXIT

  STAGED="$CTL/staged"
  if "${BASH_SOURCE[0]}" "$STAGED" >/dev/null 2>&1 && [ -f "$HERE/manifest.run.json" ]; then
    bound="$(grep -o '"check": "[^"]*check\.sh' "$HERE/manifest.run.json" | sed 's/.*: "//' | sort -u)"
    if [ "$bound" != "$HERE/check.sh" ]; then
      echo "SELF-TEST FAILED: the generated run manifest does not bind to this harness."
      echo "                  expected every check to invoke:"
      echo "                    $HERE/check.sh"
      echo "                  got:"
      printf '                    %s\n' "$bound"
      echo "                  A manifest that scores with a DIFFERENT copy of check.sh is"
      echo "                  how three held-out answers reached a worker on 2026-08-22."
      fail=1
    fi
    if ! grep -q "\"workdir\": \"$STAGED\"" "$HERE/manifest.run.json"; then
      echo "SELF-TEST FAILED: the run manifest's workdir is not the directory just staged,"
      echo "                  so it would score sandboxes nobody filled."
      fail=1
    fi
  else
    echo "SELF-TEST FAILED: staging produced no manifest.run.json — the check path is"
    echo "                  back to being whatever manifest.json happens to say."
    fail=1
  fi

  [ "$fail" -eq 0 ] && { echo "self-test: found the planted answers and the planted held-out set, cleared the clean tree, and bound the run manifest to this harness"; exit 0; }
  exit 1
fi

WORKDIR="${1:?usage: stage.sh <workdir> | stage.sh --self-test}"

mkdir -p "$WORKDIR"
for key in "${KEYS[@]}"; do
  d="$WORKDIR/$key"
  rm -rf "$d"
  mkdir -p "$d"
  cp "$HERE/PACKET.md" "$d/PACKET.md"
  cp -R "$HERE/cases" "$d/cases"
  printf '%s\n' "$key" > "$d/.model-key"
  echo "staged $d"
done

echo
found="$(leaks "$WORKDIR")"
if [ -n "$found" ]; then
  echo "LEAK — answers are reachable from a worker directory:"
  printf '  %s\n' "$found"
  exit 1
fi
echo "neither expected/ nor heldout/ is reachable from any worker directory"

# THE RUN MANIFEST IS GENERATED, FOR THE REASON `build-packet.py` GIVES.
#
# That script says the packet is built rather than maintained because "a
# hand-edited copy of the specification drifts from the specification". A
# hand-edited absolute path drifts from the harness by the identical mechanism,
# and on 2026-08-22 it did: `manifest.json`'s `check` pointed at the main
# checkout while the harness being developed was a worktree. The main checkout
# was four commits behind, so the run scored against a `check.sh` WITHOUT the
# held-out redaction, and `copilot-haiku45` was handed three held-out answers in
# its retry prompt. The fix was committed and correct; it simply was not where
# the run read from.
#
# So the path is no longer written by hand. Staging emits `manifest.run.json`
# with every `check` rewritten to THIS directory's `check.sh` — the copy you
# stage from is necessarily the copy that scores, and the two cannot diverge.
#
# It is written HERE, beside the harness, and NOT into the workdir or a sandbox.
# A pointer file next to the sandboxes would be readable (Seatbelt allows reads
# everywhere) and would name the directory holding `expected/` — downgrading
# "a worker that goes looking is itself a finding" to "read this line". The
# worker has no reason to be in the repo at all, so the repo is where it goes.
if [ -f "$HERE/manifest.json" ]; then
  RUN_MANIFEST="$HERE/manifest.run.json"
  if HARNESS="$HERE" WORKDIR="$WORKDIR" OUT="$RUN_MANIFEST" \
       python3 "$HERE/build-run-manifest.py" "$HERE/manifest.json"; then
    echo "run manifest: $RUN_MANIFEST — checks bound to $HERE"
    echo "  run ringer against THAT file, not manifest.json"
  else
    echo "could not generate $RUN_MANIFEST — refusing to leave a stale one behind"
    rm -f "$RUN_MANIFEST"
    exit 1
  fi
fi
