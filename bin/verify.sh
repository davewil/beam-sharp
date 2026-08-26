#!/usr/bin/env bash
#
# ONE COMMAND. FROM A CLEAN CLONE, FROM ANY DIRECTORY.
#
#     ./bin/verify.sh
#
# WHY THIS EXISTS
# Until 2026-08-26 the most complete verification recipe in this repository was
# in `.claude/end-session.md` — an agent-specific overlay, written for a session
# rather than for a person, and twenty-odd separate commands with a `cd` folded
# into most of them. A recipient of the clean-room handoff had no entry point at
# all: no file said "run this", and the file that came closest was one a human
# was never meant to read.
#
# It is also the one place the repository's own rule can be honoured without
# being remembered. CLAUDE.md: "Nothing is done until the gates pass twice from
# a clean checkout. Twice, and clean both times — not two runs in the same tree.
# `spec-check.sh` caches a PLT under `$TMPDIR` and `fixture_root/0` seeds off the
# OS pid, so a second run in a warm tree is not an independent measurement of the
# first. Set `SPEC_CHECK_DIR` per run." That was a sentence a caller had to
# remember. It is now a property of this script: every invocation gets a fresh
# `SPEC_CHECK_DIR`, so two runs are two measurements whether or not anybody knew
# to arrange it.
#
# WHAT IT IS NOT
# It is not a second copy of `.github/workflows/ci.yml`. The workflow keeps its
# per-step granularity — and the long record of *why* each gate exists, which is
# the most valuable prose in this repository — and `check-gates-wired.sh` asks
# this file the same enumeration question it asks the workflow, so a gate added
# tomorrow is named here tomorrow or the build goes red.
#
# FAIL FAST, AND THE ORDER IS LOAD-BEARING.
# `escriptize` before `eunit`, because several tests drive `bsc` as a subprocess.
# The toolchain before anything compiles, because a version mismatch is a clear
# failure there and a baffling one afterwards. Everything after a failed stage is
# noise, so the first red stops the run and names itself.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------------------------------------------------------------------------
# The runner. Takes stages as label/command pairs so --self-test drives this
# exact function over fixtures rather than over a second copy of its logic.
# ---------------------------------------------------------------------------
run_stages() {
  local label cmd n=0
  while [ "$#" -gt 0 ]; do
    label="$1"; cmd="$2"; shift 2
    n=$((n + 1))
    printf '\n=== [%d] %s\n' "$n" "$label"
    if ! ( eval "$cmd" ); then
      printf '\nFAILED at stage %d: %s\n' "$n" "$label"
      printf 'Nothing after this ran. Fix that stage and run ./bin/verify.sh again.\n'
      return 1
    fi
  done
  printf '\nAll %d stages passed.\n' "$n"
  return 0
}

# ---------------------------------------------------------------------------
# --self-test
#
# THREE CLAIMS, AND THE THIRD IS THE ONE A PLAUSIBLE IMPLEMENTATION FAILS.
#
# A runner written as `for s in "${stages[@]}"; do $s || rc=1; done` exits
# non-zero on a failure and reports the label, so it satisfies the first two
# controls completely. It also runs every stage after the failure — which in
# this repository means running `eunit` after `escriptize` failed, and reading
# a wall of subprocess errors that are all one problem. The marker file is what
# separates the two designs: it must NOT exist.
#
# The fourth control is the discrimination half. A runner that reported failure
# unconditionally would pass the three above and be worthless.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  fail=0

  set +e
  out="$(run_stages \
      "a stage that passes"  "true" \
      "a stage that fails"   "false" \
      "a stage after it"     "touch '$CTL/ran-after'" 2>&1)"
  rc=$?
  set -e

  if [ "$rc" -eq 0 ]; then
    echo "SELF-TEST FAILED: a failing stage exited 0, so this entry point would report"
    echo "                  a green verification over a red gate"
    fail=1
  fi
  if ! printf '%s' "$out" | grep -q 'FAILED at stage 2: a stage that fails'; then
    echo "SELF-TEST FAILED: the failing stage was not named, so a red run says only"
    echo "                  that something somewhere went wrong"
    fail=1
  fi
  if [ -e "$CTL/ran-after" ]; then
    echo "SELF-TEST FAILED: a stage AFTER the failure ran. Everything downstream of a"
    echo "                  red gate reports the same problem again in a less useful"
    echo "                  form — the escript fails, and then thirty subprocess tests"
    echo "                  fail for the one reason already printed."
    fail=1
  fi

  set +e
  out_ok="$(run_stages "one" "true" "two" "true" 2>&1)"
  rc_ok=$?
  set -e

  if [ "$rc_ok" -ne 0 ]; then
    echo "SELF-TEST FAILED: every stage passed and the runner still reported failure,"
    echo "                  so it does not discriminate"
    echo "$out_ok"
    fail=1
  fi
  if ! printf '%s' "$out_ok" | grep -q 'All 2 stages passed'; then
    echo "SELF-TEST FAILED: a clean run did not report how many stages it ran, so it"
    echo "                  cannot be told from a run that enumerated nothing"
    fail=1
  fi

  if [ "$fail" -eq 0 ]; then
    echo "self-test: stopped at the failing stage, named it, ran nothing after it, and"
    echo "           left a run whose stages all pass alone"
    exit 0
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
[ "${1:-}" = "" ] || { echo "usage: verify.sh [--self-test]"; exit 2; }

cd "$ROOT"

# A FRESH PLT AND A FRESH FIXTURE ROOT PER INVOCATION, so that "it passed twice"
# is two measurements. See the header. `mktemp -d` rather than a fixed path
# under `$TMPDIR`, which is precisely the cache that makes the second run cheap
# and meaningless.
SPEC_CHECK_DIR="$(mktemp -d)"
export SPEC_CHECK_DIR
trap 'rm -rf "$SPEC_CHECK_DIR"' EXIT

echo "beam-sharp — full verification"
echo "  repository: $ROOT"
echo "  SPEC_CHECK_DIR: $SPEC_CHECK_DIR (fresh; a warm one is not an independent run)"

run_stages \
  "The toolchain installed here is the pinned one" \
    "./bin/check-toolchain.sh --env" \
\
  "Every gate proves it can fail" \
    "./bin/check-gates-wired.sh --self-test &&
     ./bin/check-cwd-independence.sh --self-test &&
     ./bin/check-shell.sh --self-test &&
     ./bin/check-map.sh --self-test &&
     ./bin/check-surface.sh --self-test &&
     ./bin/check-links.sh --self-test &&
     ./bin/check-toolchain.sh --self-test &&
     ./bin/verify.sh --self-test &&
     ./compiler/bin/check-no-silent-skip.sh --self-test &&
     ./compiler/bin/extract-exemplars.sh --self-test" \
\
  "The manifest and the workflow pin the same toolchain" \
    "./bin/check-toolchain.sh" \
\
  "Every gate on disk is wired into the workflow, this script and the session list" \
    "./bin/check-gates-wired.sh" \
\
  "Gates give the same verdict from any directory" \
    "./bin/check-cwd-independence.sh" \
\
  "The gates are shellcheck-clean" \
    "./bin/check-shell.sh" \
\
  "The map is an index" \
    "./bin/check-map.sh" \
\
  "Surface decisions are traceable from LANGUAGE.md" \
    "./bin/check-surface.sh" \
\
  "The package points only at things it ships" \
    "./bin/check-links.sh" \
\
  "Build the escript" \
    "cd compiler && rebar3 escriptize" \
\
  "The handoff package is assembled, self-contained and reproducible" \
    "./bin/build-handoff.sh --self-test &&
     ./bin/check-handoff-package.sh --self-test &&
     ./bin/check-handoff-package.sh" \
\
  "The audition can tell an implementation from a lookup table" \
    "./handoff/audition-switch/check.sh --self-test &&
     ./handoff/audition-switch/stage.sh --self-test" \
\
  "The tour gate proves it can fail, then replays what it pasted" \
    "./compiler/bin/check-tour.sh --self-test && ./compiler/bin/check-tour.sh" \
\
  "Tests" \
    "cd compiler && rebar3 eunit" \
\
  "No test passes without running" \
    "cd compiler && ./bin/check-no-silent-skip.sh" \
\
  "The check helper walks the compiler's path" \
    "cd compiler && ./bin/check-helper-agrees.sh --self-test && ./bin/check-helper-agrees.sh" \
\
  "LANGUAGE.md compiles" \
    "cd compiler && ./bin/check-language.sh --self-test && ./bin/check-language.sh" \
\
  "Examples compile and run" \
    "cd compiler &&
     find examples -path examples/exemplars -prune -o -name '*.bs' -print0 |
       while IFS= read -r -d '' f; do dirname \"\$f\"; done | sort -u |
       while IFS= read -r d; do
         echo \"  \$d\"
         ./_build/default/bin/bsc --src-root examples -o \"\$(mktemp -d)\" \"\$d\" || exit 1
       done" \
\
  "Shipping documents agree with the compiler about what is built" \
    "./bin/check-status-claims.sh --self-test && ./bin/check-status-claims.sh" \
\
  "Diagnostics are terms" \
    "cd compiler && ./bin/check-diagnostics.sh --self-test && ./bin/check-diagnostics.sh" \
\
  "The checker sees a list's length" \
    "cd compiler && ./bin/check-list-length.sh --self-test && ./bin/check-list-length.sh" \
\
  "\`/\` lowers to div, and only a provable zero is refused" \
    "cd compiler && ./bin/check-division.sh --self-test && ./bin/check-division.sh" \
\
  "No \`not\` and no \`!\`, both taught, and \`not\` is still a name" \
    "cd compiler && ./bin/check-negation.sh --self-test && ./bin/check-negation.sh" \
\
  "A field assignment is checked, at both spellings" \
    "cd compiler && ./bin/check-field-values.sh --self-test && ./bin/check-field-values.sh" \
\
  "A type prefix subtracts what the Kind spelling subtracts" \
    "cd compiler && ./bin/check-record-pattern.sh --self-test && ./bin/check-record-pattern.sh" \
\
  "An int parameter is an integer at the boundary" \
    "cd compiler && ./bin/check-boundary-kind.sh --self-test && ./bin/check-boundary-kind.sh" \
\
  "A return mismatch hands over the signature to paste" \
    "cd compiler && ./bin/check-corrected-signature.sh --self-test && ./bin/check-corrected-signature.sh" \
\
  "Emitted specs survive Dialyzer" \
    "cd compiler && ./bin/spec-check.sh" \
\
  "Exemplars are not stale" \
    "cd compiler && ./bin/extract-exemplars.sh --check" \
\
  "The exemplars stop where FRONTIER says they do" \
    "./compiler/bin/check-exemplar-frontier.sh --self-test &&
     ./compiler/bin/check-exemplar-frontier.sh" \
\
  "The editor grammars know every shipped keyword" \
    "./editor/bin/check-tokens.sh --self-test && ./editor/bin/check-tokens.sh" \
\
  "The editor grammar parses every example" \
    "./editor/bin/check-corpus.sh --self-test && ./editor/bin/check-corpus.sh"
