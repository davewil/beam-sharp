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

# The same directory, spelled physically — every symlink resolved. Both spellings
# are needed and neither is redundant.
#
# `pwd` above is LOGICAL: it keeps whatever symlinks the caller walked through,
# which is what the human-facing messages should echo back. But
# `build-run-manifest.py` calls `.resolve()` on HARNESS, so every path it writes
# is symlink-free. Comparing a manifest path against $HERE therefore compares two
# spellings of one directory and calls them different.
#
# Found 2026-08-27: on macOS `/var` is a symlink to `/private/var` and `mktemp -d`
# hands back the logical form, so `git clone` into a temp dir — the exact shape of
# "the gates pass twice from a clean checkout" — made the binding control below
# fail against a manifest the harness had just staged itself. It is stage 12 of
# 34 and verify.sh stops at the first failure, so twenty-two stages went unrun for
# a reason unrelated to any change. Green on Linux CI and in a checkout under
# /Volumes, which is why it went unseen.
#
# The repair belongs on this side. Dropping the `.resolve()` in the builder would
# also make the two agree, and would be wrong: the manifest names the file that
# scores the run, and a path a symlink can alias is not that guarantee.
HERE_P="$(cd "$HERE" && pwd -P)"

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

# Which check.sh does a run manifest bind to? Factored out for the same reason
# `leaks` is: --self-test must be able to point it at a manifest staged by a
# DIFFERENT copy of the harness and require a rejection. A control that
# re-spelled this grep would be testing its own copy of the rule, and would go on
# passing after the shipped one drifted.
bound_check() {
  grep -o '"check": "[^"]*check\.sh' "$1" | sed 's/.*: "//' | sort -u
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
  # BOTH CODES NAME THE SAME FINDING — "appears unreachable" — under two different
  # tool versions: 0.11 reports SC2329, older builds report SC2317. CI runs
  # ubuntu-latest's preinstalled build and this repo's authors run brew's, so a
  # directive naming only one code passes locally and reddens master. It did, on
  # 2026-08-22. The tool is not version-pinned anywhere, which is the real gap.
  # shellcheck disable=SC2329,SC2317  # invoked from the EXIT trap below, which shellcheck cannot follow
  restore_run_manifest() {
    # Belt and braces: the older build reports the finding on the BODY line, not
    # on the definition, and whether a directive above the definition reaches
    # inside it is version-dependent. This one sits where the finding fired.
    # shellcheck disable=SC2317
    if [ -n "$SAVED" ]; then cp "$SAVED" "$HERE/manifest.run.json"; else rm -f "$HERE/manifest.run.json"; fi
  }
  trap 'restore_run_manifest; rm -rf "$CTL"' EXIT

  STAGED="$CTL/staged"
  if "${BASH_SOURCE[0]}" "$STAGED" >/dev/null 2>&1 && [ -f "$HERE/manifest.run.json" ]; then
    bound="$(bound_check "$HERE/manifest.run.json")"
    if [ "$bound" != "$HERE_P/check.sh" ]; then
      echo "SELF-TEST FAILED: the generated run manifest does not bind to this harness."
      echo "                  expected every check to invoke:"
      echo "                    $HERE_P/check.sh"
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

  # CONTROL — THE BINDING COMPARISON MUST SURVIVE A SYMLINKED PATH AND MUST STILL
  # REJECT A FOREIGN HARNESS. BOTH HALVES, OR NEITHER IS EVIDENCE.
  #
  # The control above compares a manifest path against this directory, and that
  # comparison was wrong from the day it was written without any control seeing
  # it — because the two spellings only diverge when the harness is reached
  # THROUGH A SYMLINK. That never happens in the main checkout or on Linux CI,
  # and it happens every single time under macOS's `mktemp -d`. So the first half
  # reaches the harness through a symlink on purpose, rather than waiting for a
  # platform to supply one and calling the result a surprise.
  #
  # The second half is the one that carries the weight. What is being repaired is
  # itself a self-test, so "goes green through a symlink" is satisfiable by
  # weakening the assertion until it asserts nothing — and this assertion is what
  # stops a foreign check.sh scoring the run, which on 2026-08-22 handed three
  # held-out answers to a worker. So a SECOND copy of the harness stages its own
  # manifest, and this directory's comparison must still call it foreign. A
  # control that only proved the green would pass while protecting nothing.
  #
  # The first half re-enters this --self-test, so both halves are skipped when
  # nested; without the guard the control recurses until the process table
  # objects.
  if [ "${AUDITION_SELFTEST_NESTED:-}" != "1" ]; then
    ln -s "$HERE_P" "$CTL/link"
    if ! AUDITION_SELFTEST_NESTED=1 "$CTL/link/stage.sh" --self-test >/dev/null 2>&1; then
      echo "SELF-TEST FAILED: the self-test does not pass when this same harness is"
      echo "                  reached through a symlink. The binding comparison is"
      echo "                  holding one spelling of this directory against another"
      echo "                  rather than comparing the directories. A clean clone"
      echo "                  under macOS's /var arrives by exactly this path, and"
      echo "                  loses every stage after this one."
      fail=1
    fi

    # Copied from the physical path so the copy is a genuine second directory
    # rather than another name for this one, and stripped of any manifest it
    # inherited so the one it is judged on is the one it just staged.
    cp -Rp "$HERE_P" "$CTL/foreign"
    rm -f "$CTL/foreign/manifest.run.json"
    if "$CTL/foreign/stage.sh" "$CTL/staged-foreign" >/dev/null 2>&1 \
         && [ -f "$CTL/foreign/manifest.run.json" ]; then
      if [ "$(bound_check "$CTL/foreign/manifest.run.json")" = "$HERE_P/check.sh" ]; then
        echo "SELF-TEST FAILED: a manifest staged by a DIFFERENT copy of the harness"
        echo "                  binds to THIS directory's check.sh. The comparison has"
        echo "                  stopped discriminating, so the 2026-08-22 leak — a run"
        echo "                  scored by a check.sh four commits behind the one that"
        echo "                  staged it — is open again."
        fail=1
      fi
    else
      echo "SELF-TEST FAILED: the second copy of the harness staged no manifest, so the"
      echo "                  half of this control that requires a REJECTION never ran."
      fail=1
    fi
  fi

  [ "$fail" -eq 0 ] && { echo "self-test: found the planted answers and the planted held-out set, cleared the clean tree, and bound the run manifest to this harness — through a symlinked path, and not to a second copy of it"; exit 0; }
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
