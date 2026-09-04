#!/usr/bin/env bash
#
# A DIRECTORY OF SHELL SCRIPTS OUTSIDE EVERY ENUMERATION.
#
# `check-shell.sh` says this about itself, in its own header:
#
#   "ENUMERATION ONLY REACHES THE DIRECTORIES NAMED HERE, which is the seam. The
#    audition's four scripts sat unlinted from the day they were written, because
#    they live in `handoff/` and nothing added it to this list. What that hid,
#    found the moment it was added 2026-08-20: a `# shellcheck disable=SC2046` in
#    `run.sh` written two lines above the line it meant to cover, annotating a
#    `date` call and suppressing nothing. A DIRECTORY MISSING FROM THIS LOOP DOES
#    NOT FAIL — it reports success over a smaller repo than you think it read."
#
# `check-gates-wired.sh` records the same shape one layer out: "`editor/bin/` held
# TWO gates the workflow had never mentioned — not excluded with a reason, simply
# never considered. They accumulated five shipped features' worth of grammar
# drift while every gate named in the workflow stayed green." And its verdict on
# why a human reviewer will not catch it: "An unmentioned check is not outside the
# rule; it is the rule's blind spot."
#
# Both gates now enumerate. NEITHER ASKS WHETHER ITS ENUMERATION IS COMPLETE,
# which is the one question that closes the seam, and it is the question here.
#
# ---------------------------------------------------------------------------
# DECLARED OR EXCLUDED, AND AN EXCLUSION CARRIES ITS REASON.
#
# This does not say every shell script must be linted. `5abb590` records a
# deliberate decision the other way — "wayfinder/ is outside check-links and
# check-shell, so both were run by hand on the new files" — and that is a fine
# answer. What is not fine is the third state the two incidents above were in:
# not enumerated, not excluded, simply never considered.
#
# So a directory holding executable shell must appear either in an enumeration or
# in `detectors/shell-dirs.exclusions`, with a reason on the same line. The
# exclusions file is the difference between a decision and an oversight, and it
# is the only artefact here a reader has to maintain.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXCLUSIONS="$ROOT/detectors/shell-dirs.exclusions"

# Every directory under BASE holding at least one executable *.sh, ignoring build
# output and vendored trees.
shell_dirs() {
  local base="$1"
  find "$base" \
       -path '*/_build' -prune -o \
       -path '*/node_modules' -prune -o \
       -path '*/.git' -prune -o \
       -name '*.sh' -perm -u+x -print 2>/dev/null |
    sed 's|/[^/]*$||' |
    sed "s|^$base/||; s|^$base\$|.|" |
    sort -u
}

# The directories the enumerating gates actually reach, read out of those gates
# rather than copied. A copy would drift from the thing it claims to describe,
# which is the failure one directory up.
enumerated_dirs() {
  local base="$1" f
  for f in "$base/bin/check-shell.sh" "$base/bin/check-gates-wired.sh" \
           "$base/bin/check-cwd-independence.sh" "$base/detectors/detect-unmanifested-tool.sh"; do
    [ -f "$f" ] || continue
    # `"$ROOT/bin"`, `"$ROOT/compiler/bin"`, `"$base"/editor/bin/*.sh`, and the
    # quoted list forms all reduce to the path between ROOT and the next quote.
    grep -oE '\$(ROOT|base|root)"?/[A-Za-z0-9_./-]+' "$f" |
      sed -E 's/^\$[A-Za-z_]+"?\///; s|/\*\.sh$||; s|/$||'
    grep -oE '"(bin|compiler/bin|editor/bin|handoff/[A-Za-z0-9_-]+|detectors)"' "$f" | tr -d '"'
  done | sed 's|/\*.*$||' | sort -u
}

# The declared exclusions, and only those carrying a reason.
excluded_dirs() {
  local f="$1"
  [ -f "$f" ] || return 0
  grep -vE '^[[:space:]]*(#|$)' "$f" |
    awk -F'#' 'NF > 1 && $2 ~ /[A-Za-z]/ { gsub(/[[:space:]]+$/, "", $1); print $1 }'
  return 0
}

# Parameters throughout, so --self-test drives this exact function.
unenumerated() {
  local base="$1" excl="$2" d
  local enum; enum=" $(enumerated_dirs "$base" | tr '\n' ' ') "
  local ex;   ex=" $(excluded_dirs "$excl" | tr '\n' ' ') "
  shell_dirs "$base" | while read -r d; do
    [ -z "$d" ] && continue
    case "$enum" in *" $d "*) continue ;; esac
    case "$ex"   in *" $d "*) continue ;; esac
    printf '%s: holds executable shell and is in no enumeration and no exclusion list\n' "$d"
  done
  return 0
}

# ---------------------------------------------------------------------------
# --self-test
#
# The third control is the one that earns the detector. An exclusion with NO
# REASON must still be reported: "not enumerated, not excluded, never considered"
# and "excluded because somebody pasted a path in" are the same state, and a list
# that accepts a bare path is a list that grows silently.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT
  mkdir -p "$CTL/bin" "$CTL/tools" "$CTL/legacy" "$CTL/orphan" "$CTL/detectors"
  for d in bin tools legacy orphan; do
    printf '#!/usr/bin/env bash\ntrue\n' > "$CTL/$d/x.sh"
    chmod +x "$CTL/$d/x.sh"
  done
  # An enumerating gate that reaches bin/ only.
  mkdir -p "$CTL/bin"
  printf '#!/usr/bin/env bash\nfor d in "$ROOT/bin"; do :; done\n' > "$CTL/bin/check-shell.sh"

  printf '# reasons required\ntools    # linted by their own harness, see tools/README\nlegacy\n' > "$CTL/excl"

  out="$(unenumerated "$CTL" "$CTL/excl")"
  fail=0
  printf '%s' "$out" | grep -q '^orphan:' || {
    echo "SELF-TEST FAILED: a directory in no enumeration and no exclusion was not reported."
    echo "                  That is handoff/audition-switch before 2026-08-20, which sat"
    echo "                  unlinted from the day it was written."
    fail=1
  }
  printf '%s' "$out" | grep -q '^tools:' && {
    echo "SELF-TEST FAILED: a directory excluded WITH A REASON was reported. 5abb590"
    echo "                  records exactly such a decision for wayfinder/, and a detector"
    echo "                  that cannot accept one leaves no way to say 'deliberately not'."
    fail=1
  }
  printf '%s' "$out" | grep -q '^legacy:' || {
    echo "SELF-TEST FAILED: a bare path in the exclusions file, with no reason, was"
    echo "                  accepted. 'Never considered' and 'somebody pasted a path' are"
    echo "                  the same state, and this list is the only thing that tells them"
    echo "                  apart."
    fail=1
  }
  printf '%s' "$out" | grep -q '^bin:' && {
    echo "SELF-TEST FAILED: an enumerated directory was reported"
    fail=1
  }

  if [ "$fail" -eq 0 ]; then
    echo "self-test: reported the unconsidered directory and the reasonless exclusion;"
    echo "           accepted the enumerated one and the excluded-with-a-reason one"
    exit 0
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
[ "${1:-}" = "" ] || { echo "usage: detect-unenumerated-shell-dir.sh [--self-test]"; exit 2; }

found="$(shell_dirs "$ROOT" | grep -c . || true)"
if [ "$found" -eq 0 ]; then
  echo "no directories of executable shell found — this detector is looking in the wrong place"
  exit 1
fi

findings="$(unenumerated "$ROOT" "$EXCLUSIONS")"
if [ -n "$findings" ]; then
  printf '%s\n' "$findings"
  echo
  echo "A directory missing from an enumeration does not fail — it reports success over"
  echo "a smaller repo than you think it read. Add it to check-shell.sh's scripts() and"
  echo "the other enumerations, or to detectors/shell-dirs.exclusions with the reason on"
  echo "the same line."
  exit 1
fi

echo "$found directories of executable shell, every one enumerated or excluded with a reason"
