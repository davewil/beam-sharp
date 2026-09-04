#!/usr/bin/env bash
#
# TWO RUNS SHARING ONE SCRATCH PATH.
#
# `15ab27e` (2026-08-26): "check 6 compiled all sixteen example modules into ONE
# `-o` directory, where `ci.yml` gives each module a fresh `mktemp -d`. A second
# module emitting a beam under a first module's name would overwrite it with both
# compilations exiting 0, AND THE COUNT WOULD STILL READ SIXTEEN with one
# module's output never having existed."
#
# `a923fe6` (2026-09-03) is the same hazard one layer down, and it is the reason
# `ENG-318` exists: "`bsc` with no `-o` names its scratch from
# `erlang:unique_integer`, which repeats across VMs — 12 distinct values from 30
# fresh VMs, measured today — so two concurrent tour replays would share one
# `Fib.beam`." The gate now gives each run a private TMPDIR.
#
# It is not hypothetical for this project's own workflow either. The bar is "the
# gates pass twice from a clean checkout", the two runs are sequential, and a
# fixed scratch path means run 2 can be reading run 1's output — or a dead VM's
# leftovers, which is exactly how a sequential pair goes red for a reason that
# has nothing to do with the tree.
#
# THE RULE: a scratch path is created, not named. `mktemp -d` and `mktemp` give a
# fresh one per invocation; a literal under `/tmp` or `$TMPDIR` is shared by
# every run on the machine, including the other half of a clean pair and any
# parallel agent.
#
# WHAT IT FINDS TODAY: `handoff/audition-switch/run.sh` defaults its workdir to
# `/tmp/bsharp-audition` and `check.sh` documents that path, so two audition runs
# on one machine — or a re-run after a killed one — share a directory.
#
# READ FROM THE RAW SOURCE, NOT FROM STRIPPED CODE, and that is deliberate. The
# path is almost always inside a quoted default (`"${1:-/tmp/bsharp-audition}"`),
# so the sibling detectors' `shell_code` helper — which blanks quoted prose — is
# the wrong instrument here. A literal path in a string IS the code.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GATE_DIRS=("bin" "compiler/bin" "editor/bin" "handoff/audition-switch" "detectors")

# A literal scratch path: `/tmp/<name>` or `$TMPDIR/<name>`, in code rather than
# in a comment. `mktemp` templates are the correct form and are exempt by shape:
# they carry an `XXXX` run.
# A DETECTOR'S OWN FIXTURES ARE DEFECTIVE ON PURPOSE, so the --self-test region
# is not part of the tree being judged. Every control in this directory writes
# the defect it names into a scratch script; reading those back would make each
# detector report itself, which is noise dressed as a finding.
selftest_start() {
  grep -nE '^if \[ "\$\{1:-\}" = "--self-test" \]' "$1" | head -1 | sed -E 's/:.*//'
}

fixed_scratch_in() {
  local f="$1" start body
  start="$(selftest_start "$f")"
  if [ -n "$start" ]; then
    body="$(sed -n "1,$(( start - 1 ))p" "$f")"
  else
    body="$(cat "$f")"
  fi
  printf '%s\n' "$body" |
    grep -n '' |
    grep -vE '^[0-9]+:[[:space:]]*#' |
    grep -E '(/tmp/[A-Za-z0-9_.-]+|\$\{?TMPDIR\}?/[A-Za-z0-9_.-]+)' |
    grep -vE 'XXXX' |
    grep -vE 'scratch-path: exempt' |
    # A path inside a message or a documented command is prose about a path, not
    # a path this script uses. `check-handoff-package.sh` prints an example
    # `bsc ... -o /tmp/out` invocation for the shipped README, and `check.sh`
    # prints a usage line; neither creates anything.
    grep -vE '^[0-9]+:[[:space:]]*(printf|echo|cat)[[:space:]]' |
  while IFS= read -r line; do
    printf '%s: %s\n' "${f#"$ROOT"/}" "$(printf '%s' "$line" | sed -E 's/^[0-9]+:[[:space:]]*//' | cut -c1-100)"
  done
  return 0
}

# ---------------------------------------------------------------------------
# --self-test
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  printf '#!/usr/bin/env bash\nWORKDIR="${1:-/tmp/bsharp-audition}"\nmkdir -p "$WORKDIR"\n' > "$CTL/fixed.sh"
  printf '#!/usr/bin/env bash\nWORKDIR="$TMPDIR/bsc-run"\nmkdir -p "$WORKDIR"\n'            > "$CTL/tmpdir.sh"
  printf '#!/usr/bin/env bash\nWORKDIR="$(mktemp -d)"\ntrap "rm -rf $WORKDIR" EXIT\n'       > "$CTL/fresh.sh"
  printf '#!/usr/bin/env bash\nT="$(mktemp -d /tmp/bsc.XXXXXX)"\necho "$T"\n'               > "$CTL/template.sh"
  printf '#!/usr/bin/env bash\n# the old build wrote to /tmp/out and clobbered itself\ntrue\n' > "$CTL/comment.sh"

  fail=0
  red() { [ -z "$(fixed_scratch_in "$CTL/$1")" ] && { echo "SELF-TEST FAILED: $1 — $2"; fail=1; }; return 0; }
  green() {
    local out; out="$(fixed_scratch_in "$CTL/$1")"
    [ -n "$out" ] && { echo "SELF-TEST FAILED: $1 — $2"; printf '  reported: %s\n' "$out"; fail=1; }
    return 0
  }

  red fixed.sh  "a literal /tmp path was not reported — that is run.sh's workdir, shared by
                  every audition run on the machine"
  red tmpdir.sh "a literal name under \$TMPDIR was not reported. macOS mktemp ignores
                  TMPDIR while GNU honours it, so this is shared on one platform and not
                  the other, which is worse than shared on both"
  green fresh.sh    "\`mktemp -d\` was reported; creating a path per invocation is the fix"
  green template.sh "an XXXX template was reported; that is mktemp being told where to put
                  a FRESH directory, not a fixed one"
  green comment.sh  "a path named in a comment was reported; prose is not a scratch path"

  if [ "$fail" -eq 0 ]; then
    echo "self-test: reported the fixed /tmp path and the fixed \$TMPDIR name; accepted"
    echo "           mktemp, an XXXX template and a comment — the detector discriminates"
    exit 0
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
[ "${1:-}" = "" ] || { echo "usage: detect-shared-scratch.sh [--self-test]"; exit 2; }

scanned=0
findings=""
for d in "${GATE_DIRS[@]}"; do
  [ -d "$ROOT/$d" ] || continue
  for s in "$ROOT/$d"/*.sh; do
    [ -x "$s" ] || continue
    scanned=$((scanned + 1))
    out="$(fixed_scratch_in "$s")"
    [ -n "$out" ] && findings+="$out"$'\n'
  done
done

if [ "$scanned" -eq 0 ]; then
  echo "no gate scripts found — this detector is looking in the wrong place"
  exit 1
fi

if [ -n "$findings" ]; then
  printf '%s' "$findings"
  echo
  echo "A named scratch path is shared by every run on the machine: the other half of"
  echo "a clean pair, a parallel agent, and whatever a killed run left behind. Create"
  echo "one with \`mktemp -d\` instead, or mark the line \`scratch-path: exempt\` with the"
  echo "reason it must be fixed."
  exit 1
fi

echo "$scanned gate scripts create their scratch directories rather than naming them"
