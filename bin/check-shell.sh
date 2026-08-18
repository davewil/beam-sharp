#!/usr/bin/env bash
#
# THE GATES ARE SHELL, AND SHELL IS WHERE THIS REPO'S SELF-INFLICTED BUGS LIVE.
#
# Every gate in this suite is a shell script, so a quoting or precedence bug in
# one of them is not an ordinary bug: it is a bug in the thing that decides
# whether everything else is correct. The failures on record are all of that
# shape and all of them reported success while broken:
#
#   `check-links.sh`'s first draft excluded a preceding backtick and reported 6
#   dead paths where there were 20 — the quiet-gate failure it exists to prevent,
#   committed inside the gate itself.
#
#   Its second draft misreported its own line numbers: it numbered a
#   comment-stripped copy and then ran `grep -n` over a stream that was already
#   numbered.
#
#   A corpus-rewrite script shipped with two regex precedence bugs, and a `sed`
#   edit mangled a paragraph of prose it was only supposed to retarget.
#
# None of those are exotic. `shellcheck` finds this class by construction, and
# the repo had never run it.
#
# SEVERITY IS PINNED AT `info`, AND THE SELF-TEST IS WHY. The first draft of
# this gate used `warning`, on the reasoning that the tree was already clean
# there and a threshold should sit where the tree is. Its own --self-test then
# failed: SC2086, the unquoted-expansion check — the word-splitting bug this
# gate names in its first paragraph — is classified `info`, so at `warning` the
# gate could not catch the class it was written for. It would have passed
# forever and proved nothing.
#
# At `info` the existing scripts produced ten findings and two were real: an
# `A && B || C` chain in `check-map.sh` and another in `check-surface.sh`, where
# C runs if B fails. That is the same shape that silently swallowed a failure in
# the session this gate was written in.
#
# `style` remains out: it carries opinions about phrasing, and a gate that
# argues about taste gets switched off.
#
# TWO CHECKS ARE EXCLUDED, WITH THEIR REASON, per ci.yml's rule:
#
#   SC2016 — "expressions don't expand in single quotes". Every occurrence is a
#            literal `$` inside an embedded awk or grep program, which is this
#            repo's dominant idiom for reading its own documents.
#   SC1003 — "want to escape a single quote?". Both occurrences are in
#            `check-tokens.sh`, escaping quotes for a tree-sitter grammar.
#
# Neither can be fixed without making the embedded program wrong, so they are
# named here rather than annotated at thirty call sites.
#
# IF SHELLCHECK IS MISSING THIS FAILS. It does not skip. `check-corpus.sh` skips
# with exit 0 when the tree-sitter CLI is absent and the workflow installs the
# CLI on purpose to stop that being load-bearing; the reasoning in `ci.yml` is
# that "a gate that silently skips is worse than one that is honestly missing".
# This one is honestly missing.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEVERITY="info"
EXCLUDE="SC2016,SC1003"

# Every executable shell gate in the repo. Enumerated rather than listed, so a
# gate added tomorrow is linted tomorrow without anybody editing this file —
# the same reason `check-gates-wired.sh` enumerates instead of listing.
scripts() {
  local d
  for d in "$ROOT/bin" "$ROOT/compiler/bin" "$ROOT/editor/bin"; do
    [ -d "$d" ] || continue
    find "$d" -maxdepth 1 -name '*.sh' -perm -u+x -print
  done
}

# ---------------------------------------------------------------------------
# --self-test
#
# The positive control carries an unquoted expansion — SC2086, the word-split
# bug — which is the actual class, not a stand-in for it. The negative control
# is the same script with the quotes in place. If shellcheck flagged both, the
# gate would be noise; if it flagged neither, the gate would be decoration.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  command -v shellcheck >/dev/null 2>&1 || {
    echo "SELF-TEST CANNOT RUN: shellcheck is not installed"
    echo "  brew install shellcheck   (ubuntu-latest ships it preinstalled)"
    exit 1
  }

  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  # POSITIVE CONTROL — unquoted $f splits on whitespace and globs.
  cat > "$CTL/bad.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
f="a file.txt"
cat $f
SH

  # NEGATIVE CONTROL — identical but quoted.
  cat > "$CTL/good.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
f="a file.txt"
cat "$f"
SH

  fail=0
  if shellcheck --severity="$SEVERITY" --exclude="$EXCLUDE" "$CTL/bad.sh" >/dev/null 2>&1; then
    echo "SELF-TEST FAILED: the unquoted expansion passed — this gate cannot fire"
    fail=1
  fi
  if ! shellcheck --severity="$SEVERITY" --exclude="$EXCLUDE" "$CTL/good.sh" >/dev/null 2>&1; then
    echo "SELF-TEST FAILED: the correctly quoted script was rejected, so the gate"
    echo "                  would fail every clean script and be removed"
    fail=1
  fi

  if [ "$fail" -eq 0 ]; then
    echo "self-test: rejected the unquoted expansion, accepted the quoted one — the gate discriminates"
    exit 0
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck is not installed, so the shell gates are unchecked."
  echo "This is a failure rather than a skip, on the rule in ci.yml: a gate that"
  echo "silently skips is worse than one that is honestly missing."
  echo "  brew install shellcheck   (ubuntu-latest ships it preinstalled)"
  exit 1
fi

# NOT `mapfile`, WHICH IS BASH 4. macOS ships bash 3.2 as /bin/bash, so the
# first draft of this line ran green on ubuntu and died with `command not found`
# on the machine the gates are actually developed on — a gate that works only
# where nobody is watching it fail. `while read` is in every shell that matters.
files=()
while IFS= read -r s; do
  files+=("$s")
done < <(scripts)

if [ "${#files[@]}" -eq 0 ]; then
  echo "no shell gates found — this check is looking in the wrong place"
  exit 1
fi

if ! shellcheck --severity="$SEVERITY" --exclude="$EXCLUDE" --format=gcc "${files[@]}"; then
  echo
  echo "A quoting or precedence bug in a gate is a bug in the thing that decides"
  echo "whether everything else is correct. Fix it, or annotate the line with a"
  echo "\`# shellcheck disable=SCxxxx\` carrying its reason."
  exit 1
fi

echo "${#files[@]} shell gates are clean at severity=$SEVERITY (excluding $EXCLUDE)"
