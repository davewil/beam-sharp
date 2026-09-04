#!/usr/bin/env bash
#
# A CONTROL WHOSE VERDICT CANNOT FAIL.
#
# Three separate incidents, all inside `--self-test` blocks, all of which left a
# control that reported success no matter what happened:
#
#   `be6307b`  "check-tour.sh's negative control went through a helper ending in
#              `|| true`, so 'the document as committed was accepted' could never
#              fail." It had been vacuous until 2026-09-02.
#   `d67ab38`  "The self-test captured judge's exit status and discarded it, so an
#              awk or find failure inside judge printed nothing, which is what
#              every green control looks like: the exact class the both-halves
#              rule exists for."
#   `a923fe6`  the fix, stated as a rule: "Nothing reads a launcher's `$?` — the
#              `|| true` helper that made the tour's negative control vacuous
#              until 2026-09-02 is gone. A control that never wrote a status is
#              red."
#
# `check-shell.sh` cannot see any of this. `|| true` is idiomatic and correct on
# a `grep` that is allowed to match nothing; what makes it a defect is WHAT it is
# attached to. So the rule is not "no `|| true`" — it is that the thing a control
# is judging must have a status somebody reads.
#
# TWO SHAPES, both mechanical:
#
#   the discarded status   `rc=$?` where `$rc` is never read again. That is
#                          d67ab38 exactly.
#   the neutralised subject  a call to a function DEFINED IN THIS SCRIPT, inside
#                          the self-test, terminated by `|| true`. A function the
#                          script defines is the thing under test; a `grep` or a
#                          `find` is not, and neither is a cleanup.
#
# Zero findings today — all three were fixed. This is a regression guard, and its
# `--self-test` is where the evidence lives.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/shell-code.sh
. "$ROOT/detectors/lib/shell-code.sh"

GATE_DIRS=("bin" "compiler/bin" "editor/bin" "handoff/audition-switch" "detectors")

swallowed_in() {
  local f="$1" code reads v uses n line ln fn funcs
  code="$(shell_code "$f")"
  # THE ASSIGNMENT IS LOCATED IN STRIPPED CODE AND THE READ IS COUNTED IN THE RAW
  # FILE, and the asymmetry is the whole correctness of this shape.
  #
  # An assignment must be found in stripped code, or every `rc=$?` inside a
  # heredoc fixture counts. But a variable is almost always READ inside double
  # quotes — `if [ "$from_root" -ne "$from_away" ]` — and `shell_code` blanks
  # quoted spans, so counting reads there says every variable in the tree is
  # unread. Measured: 28 findings, of which 0 were real, including four in
  # check-cwd-independence.sh whose values are compared two lines below.
  reads="$(grep -vE '^[[:space:]]*#' "$f")"

  # SHAPE 1 — a status captured and never read.
  printf '%s\n' "$code" | grep -nE '(^[[:space:]]*|[;&|(][[:space:]]*)[a-zA-Z_][a-zA-Z0-9_]*=\$\?([[:space:]]*$|[[:space:]]*[;&|])' |
  while IFS= read -r line; do
    ln="${line%%:*}"
    v="$(printf '%s' "$line" | grep -oE '[a-zA-Z_][a-zA-Z0-9_]*=\$\?' | head -1 | sed -E 's/=\$\?$//')"
    # An `if`, not `[ -z "$v" ] && continue`: as the last command of an `&&` list
    # inside a command substitution, that form returns 1 whenever $v IS set and
    # `set -e` then kills the function — reporting nothing, which is what a clean
    # tree looks like. Twice in this directory now.
    if [ -z "$v" ]; then
      continue
    fi
    # `grep -F` and not a `\b` pattern: this repository has already been caught
    # by `git grep -E` having no word boundary, where a zero-hit sweep read as a
    # clean tree.
    n="$(printf '%s\n' "$reads" | grep -cF -e "\$$v" -e "\${$v" || true)"
    uses="$(printf '%s\n' "$code" | grep -cE "(^|[[:space:];&|(])$v=\\\$\\?" || true)"
    if [ "$n" -eq 0 ] && [ "$uses" -ge 1 ]; then
      printf '%s:%s: `%s=$?` and $%s is never read — a judge that crashed and a judge that passed look the same\n' \
             "${f#"$ROOT"/}" "$ln" "$v" "$v"
    fi
  done

  # SHAPE 2 — the subject under test neutralised by `|| true`.
  funcs="$(grep -oE '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$f" | tr -d ' ()' | tr '\n' ' ')"
  [ -z "$funcs" ] && return 0
  printf '%s\n' "$code" | grep -nE '\|\|[[:space:]]*true[[:space:]]*($|[;&])' |
  while IFS= read -r line; do
    ln="${line%%:*}"
    for fn in $funcs; do
      case "$fn" in red|green|expect_red|expect_green|die|note) continue ;; esac
      if printf '%s' "$line" | grep -qE "(^|[[:space:];&|(=\"])$fn([[:space:]]|\"|\\\$|$)"; then
        printf '%s:%s: `%s ... || true` — the function under test cannot report failure here\n' \
               "${f#"$ROOT"/}" "$ln" "$fn"
        break
      fi
    done
  done
  return 0
}

# ---------------------------------------------------------------------------
# --self-test
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  cat > "$CTL/discarded.sh" <<'SH'
#!/usr/bin/env bash
judge() { awk '{print}' "$1"; }
run() {
  judge x
  rc=$?
  echo done
}
SH

  cat > "$CTL/read.sh" <<'SH'
#!/usr/bin/env bash
judge() { awk '{print}' "$1"; }
run() {
  judge x
  rc=$?
  if [ "$rc" -ne 0 ]; then echo "judge crashed"; fi
}
SH

  cat > "$CTL/neutralised.sh" <<'SH'
#!/usr/bin/env bash
gate() { grep -q x y; }
run() {
  gate || true
  echo "the document as committed was accepted"
}
SH

  cat > "$CTL/tolerant.sh" <<'SH'
#!/usr/bin/env bash
gate() { grep -q x y; }
run() {
  hits="$(grep -c x y || true)"
  gate
}
SH
  chmod +x "$CTL"/*.sh

  fail=0
  printf '%s' "$(swallowed_in "$CTL/discarded.sh")" | grep -q 'never read' || {
    echo "SELF-TEST FAILED: a status captured into a variable and never read was not"
    echo "                  reported. That is d67ab38: a crashed judge and a clean one"
    echo "                  produce identical output."
    fail=1; }
  out="$(swallowed_in "$CTL/read.sh")"
  [ -n "$out" ] && { echo "SELF-TEST FAILED: a status that IS read was reported"; printf '  %s\n' "$out"; fail=1; }

  printf '%s' "$(swallowed_in "$CTL/neutralised.sh")" | grep -q 'cannot report failure' || {
    echo "SELF-TEST FAILED: the function under test suffixed \`|| true\` was not reported."
    echo "                  That is be6307b: check-tour.sh's negative control could never"
    echo "                  fail, and nobody noticed for weeks."
    fail=1; }
  out="$(swallowed_in "$CTL/tolerant.sh")"
  [ -n "$out" ] && {
    echo "SELF-TEST FAILED: \`grep -c ... || true\` was reported. That is the idiom for a"
    echo "                  search allowed to match nothing, it is correct, and firing on"
    echo "                  it would make this detector red on every gate in the tree."
    printf '  %s\n' "$out"; fail=1; }

  if [ "$fail" -eq 0 ]; then
    echo "self-test: reported the discarded status and the neutralised subject; accepted a"
    echo "           status that is read and a tolerant grep — the detector discriminates"
    exit 0
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
[ "${1:-}" = "" ] || { echo "usage: detect-swallowed-status.sh [--self-test]"; exit 2; }

scanned=0
findings=""
for d in "${GATE_DIRS[@]}"; do
  [ -d "$ROOT/$d" ] || continue
  for s in "$ROOT/$d"/*.sh; do
    [ -x "$s" ] || continue
    scanned=$((scanned + 1))
    out="$(swallowed_in "$s")"
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
  echo "A control whose subject cannot report failure is indistinguishable from one"
  echo "that passed. Read the status, or call the thing under test directly."
  exit 1
fi

echo "$scanned gate scripts read the status of everything they judge"
