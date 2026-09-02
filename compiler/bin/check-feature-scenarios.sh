#!/usr/bin/env bash
#
# check-feature-scenarios.sh — a scenario identifier cited by the code must be
# defined in the feature document it names.
#
# WHY THIS EXISTS (2026-09-02, ENG-276)
#
# The test suite navigates by scenario identifier. `corrected_signature_tests.erl`
# opens its sections with `%% F25.1 — the line exists, and it is a whole signature
# rather than a type.`, and twenty-three feature documents answer that citation
# with a matching section. The identifier is the join between a test and the
# prose explaining why the test is that shape.
#
# Three features had no such prose. Measured on `8924db7`, 220 distinct
# identifiers were cited from `compiler/{src,test,bin}` and 16 of them were
# defined nowhere:
#
#   F25.1 … F25.9   cited by `corrected_signature_tests.erl`
#   F26.1, F26.1b, F26.2   cited by `division_tests.erl`
#   F31.1 … F31.4   cited by `collapse_tests.erl`
#
# A clean-room reader following `F25.4 — a record in the RESIDUAL has no
# writable spelling` from the test to `F25-corrected-signature.md` found the
# file, found no such section, and had nothing to fall back on but the compiler
# source the handoff excludes. The citation looked like provenance and carried
# none.
#
# WHY A GATE AND NOT A ONE-TIME REPAIR. The identifiers were correct when the
# tests were written; the feature files were written in the same sessions and
# simply never grew the sections. Nothing connected the two halves, so nothing
# noticed. That is a document falsified at a distance, and — as
# `check-status-claims.sh` puts it — a check for it has to be at a distance too.
#
# WHAT IT CHECKS, AND WHAT IT DOES NOT
#
# Every `FNN.N` (optionally with a lettered sub-part, `F26.1b`) appearing in
# `compiler/src`, `compiler/test` or `compiler/bin` must appear in
# `compiler/features/FNN-*.md`. That is the whole rule.
#
# IT GATES ONE THING. ENG-276 repairs five other classes of stale provenance —
# unlinked ticket references, an implementation task recorded only in the index,
# drifted source-line references, and issue-state claims. NONE of those are
# checked here. The source-line class was fixed by removing it (F29 now cites
# functions, which do not drift), and the issue-state class belongs to ENG-291,
# whose scope is undecided. A reader must not take a green run here as evidence
# about any of them.
#
# It also does not check that the section SAYS anything useful. It checks the
# identifier is defined, not that the prose beneath it is true — no gate can do
# the second, and `check-status-claims.sh` holds the nearest end of it.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# ---------------------------------------------------------------------------
# The rule, as one function over two parameters, so --self-test drives THIS
# code path against fixtures rather than against a copy of its logic.
#
# `--features-dir` and the code roots are both arguments for that reason: the
# self-test hands it a built tree with a known answer.
#
# EXTRACTION. `git grep -E` has no `\b`, and neither does the POSIX ERE used
# here, so nothing relies on one. Identifiers are extracted with `grep -oE`
# and compared AS WHOLE STRINGS, which is what stops a one-digit sub-part from
# being satisfied by a file that defines only its two-digit extension, and what
# makes the lettered `F26.1b` a distinct identifier from `F26.1` rather than a
# prefix of it.
# ---------------------------------------------------------------------------
ID_RE='F[0-9]+\.[0-9]+[a-z]?'

judge() {
  local features="$1"; shift
  local id feat file candidate defined

  # Every identifier cited by the code, once each, read line by line so that
  # nothing depends on word splitting.
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    feat="${id%%.*}"                       # F26.1b -> F26

    # The feature document is found by glob rather than by `ls`, so a name with
    # a space in it could not change what is opened.
    file=""
    for candidate in "$features/$feat"-*.md; do
      [ -e "$candidate" ] || continue
      file="$candidate"
      break
    done
    if [ -z "$file" ]; then
      printf '%s: cited by the code, but there is no %s-*.md to define it\n' "$id" "$feat"
      continue
    fi

    # Whole-string membership (`-x`), never a substring test, and `-F` so a
    # dot in an identifier cannot act as a wildcard.
    defined="$(grep -oE "$ID_RE" "$file" 2>/dev/null | sort -u || true)"
    if ! printf '%s\n' "$defined" | grep -qxF -- "$id"; then
      printf '%s: cited by the code, not defined in %s\n' "$id" "${file#"$features"/}"
    fi
  done <<EOF
$(grep -rhoE "$ID_RE" "$@" 2>/dev/null | sort -u || true)
EOF
}

# ---------------------------------------------------------------------------
# --self-test — four defects and two correct forms.
#
# The green half is not optional: a check that fires on everything passes the
# red half and is worthless. `check-shell.sh` was written at a severity where
# the tree was already clean and could never have seen the class it existed for.
#
# The four defects are chosen for the clause each one reaches, not for how well
# each represents the feature:
#
#   undefined   the plain case — the thing actually found on the tree.
#   suffix      a lettered sub-part cited where only the unlettered identifier
#               is defined. A gate that strips the letter, or matches on a
#               prefix, reports green over a missing section. `F26.1b` is the
#               real one, and it is why the letter is part of the identifier.
#   substring   a two-digit sub-part cited where only its one-digit prefix is
#               defined. The same failure from the other side, and the reason
#               nothing here uses a bare `grep -q`.
#   index_only  the OVER-INFORMED stub: the identifier IS in `features/`, but
#               in `README.md` rather than in the feature file. A gate that
#               greps the directory instead of the named file sees it and goes
#               green, and the clean-room reader who opened the feature file
#               still finds nothing.
#
# And two greens, the second of which is the cry-wolf half:
#
#   defined     the correct form.
#   uncited     a feature file defining a section that no code cites. Defining
#               more than the tests reach is not a defect, and a gate that
#               refuses it would force the prose to shrink to the test suite.
#
# THE SYNTHETIC IDENTIFIERS ARE BUILT FROM `$P` AND NEVER WRITTEN OUT, HERE OR
# BELOW. This gate scans `compiler/bin`, and it is in `compiler/bin`, so a
# fixture identifier spelled literally anywhere in this file — prose included —
# is a citation of a feature that does not exist, and the gate reports it.
# It did, on the first run: the code was already built from `$P`, and four
# literals in this comment block were not. Fixed here rather than by excluding
# the file from the scan, because an exclusion is the blind spot that
# `check-gates-wired.sh` exists to refuse.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  fail=0
  P="F""99"

  build() {                      # build <case> <feature-file-body> <code-body>
    local c="$1"
    mkdir -p "$W/$c/features" "$W/$c/code"
    printf '%s\n' "$2" > "$W/$c/features/$P-a-fixture.md"
    printf '%s\n' "$3" > "$W/$c/code/t.erl"
  }

  build undefined   "# $P — a fixture"                      "%% $P.1 — cited here"
  build suffix      "# $P — a fixture"$'\n'"## $P.1 — one"   "%% $P.1b — cited here"
  build substring   "# $P — a fixture"$'\n'"## $P.1 — one"   "%% $P.10 — cited here"
  build defined     "# $P — a fixture"$'\n'"## $P.1 — one"   "%% $P.1 — cited here"
  build uncited     "# $P — a fixture"$'\n'"## $P.2 — two"   "%% no citation at all"

  # The over-informed stub needs the identifier present in the DIRECTORY but
  # absent from the FILE, so it is built by hand rather than through build().
  mkdir -p "$W/index_only/features" "$W/index_only/code"
  printf '# %s — a fixture\n' "$P"                > "$W/index_only/features/$P-a-fixture.md"
  printf '| %s.1 | done | the index knows |\n' "$P" > "$W/index_only/features/README.md"
  printf '%%%% %s.1 — cited here\n' "$P"          > "$W/index_only/code/t.erl"

  for bad in undefined suffix substring index_only; do
    if [ -z "$(judge "$W/$bad/features" "$W/$bad/code")" ]; then
      echo "  x SELF-TEST: '$bad' produced no complaint - the gate cannot see it"; fail=1
    else
      echo "  ok red on $bad"
    fi
  done
  for good in defined uncited; do
    if [ -n "$(judge "$W/$good/features" "$W/$good/code")" ]; then
      echo "  x SELF-TEST: the CORRECT form '$good' was rejected -"
      judge "$W/$good/features" "$W/$good/code"; fail=1
    else
      echo "  ok green on $good"
    fi
  done

  [ "$fail" -eq 0 ] || { echo "self-test FAILED"; exit 1; }
  echo "self-test passed: four defects seen, two correct forms accepted"
  exit 0
fi

out="$(judge "$ROOT/compiler/features" \
             "$ROOT/compiler/src" "$ROOT/compiler/test" "$ROOT/compiler/bin")"
if [ -n "$out" ]; then
  echo "$out"
  echo
  echo "A test cites a scenario identifier that its feature document never defines."
  echo "Add the section, or correct the citation to the identifier that exists."
  exit 1
fi

count="$(grep -rhoE "$ID_RE" \
         "$ROOT/compiler/src" "$ROOT/compiler/test" "$ROOT/compiler/bin" 2>/dev/null |
         sort -u | wc -l | tr -d ' ')"
echo "  ok         $count scenario identifiers cited by the code, every one defined in its feature document"
