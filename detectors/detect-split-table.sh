#!/usr/bin/env bash
#
# A MARKDOWN TABLE CUT IN HALF BY A BLANK LINE.
#
# `910ed93` (2026-09-01): "The blank line at `README.md:112` sat between F20's
# row and F21's for eleven days" — thirteen, corrected in `6eee4e9`. "Markdown
# closes a table at a blank line, so the index rendered as TWO TABLES with the
# second one headerless — and `check-status-claims.sh` section B stayed green
# throughout, because it asks whether a row for each F-file EXISTS, and a row in
# the second table exists."
#
# That is the whole class in one sentence: the defect is invisible to every gate
# that reads rows, and visible to anybody who renders the page. The feature index
# is the first thing a reader opens.
#
# `910ed93` closed it for ONE file, inside `check-status-claims.sh` section B,
# and its own commit records why the obvious rule is not enough: "control 7 also
# gains a second mutation: a prose line before F5's row, because the rule is 'not
# a table line' and a check written as `prev == \"\"` passes the blank-line
# control and is blind to prose." Both shapes are here.
#
# WIDENED TO EVERY MARKDOWN FILE, because nothing about the hazard is specific to
# the feature index — `LANGUAGE.md`, `TOUR.md` and the handoff README are all
# tables a reader renders, and none of them is covered.
#
# THE FENCE IS THE FALSE-POSITIVE CONTROL. A `|` inside a fenced code block is
# not a table row; it is a pipe, an Erlang guard, or a B# union. Without that
# exclusion this fires on most of LANGUAGE.md.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# A table row that follows a line which is not part of a table. Reported at the
# row, which is where the reader will see the second table start.
split_tables_in() {
  local f="$1"
  # A ROW THAT FOLLOWS A NON-TABLE LINE IS ONLY A DEFECT IF IT IS NOT A NEW
  # TABLE, and telling those apart needs one line of look-ahead: a genuine second
  # table opens with a header row followed by a `|---|---|` separator. Without
  # that, every document that simply has two tables in it is reported, and this
  # tree has many.
  #
  # So a candidate is remembered and judged on the NEXT line. `two.md` in the
  # self-test is the control that forces it.
  awk '
    function flush() {
      if (pend) {
        printf "%s:%d: a table row follows a %s line - markdown closes the table there and renders the rest headerless\n", FILE, pend, pendkind
        pend = 0
      }
    }
    /^[[:space:]]*```/ { flush(); fence = !fence; intable = 0; prev = "fence"; next }
    fence { next }
    /^[[:space:]]*\|/ {
      if (pend) {
        # the line after a candidate: a separator makes it a new tables header
        if ($0 ~ /^[[:space:]]*\|[[:space:]:|-]+\|?[[:space:]]*$/) { pend = 0 } else { flush() }
      } else if (intable && (prev == "blank" || prev == "prose")) {
        pend = FNR; pendkind = prev
      }
      intable = 1; prev = "row"; next
    }
    # A prose line does NOT clear intable. The first draft cleared it, on the
    # reasoning that prose ends a table - which is true of rendering and wrong
    # for this check, because it is exactly the prose-between-two-rows case
    # 910ed93 warns about, and clearing made that control unreachable. The
    # look-ahead is what tells a new table from a split one now, so intable can
    # stay set and let the candidate be raised.
    { flush(); if ($0 ~ /^[[:space:]]*$/) { prev = "blank" } else { prev = "prose" } }
    END { flush() }
  ' FILE="${f#"$ROOT"/}" "$f"
  return 0
}

# ---------------------------------------------------------------------------
# --self-test
#
# THE PROSE CONTROL IS THE ONE THAT EARNS THIS. 910ed93 records that a check
# written as "the previous line was empty" passes the blank-line control and is
# blind to a prose line doing the same damage, so both are here — and a detector
# that caught only the first would look correct and miss half the class.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  printf '| F | S |\n|---|---|\n| F20 | ok |\n\n| F21 | ok |\n' > "$CTL/blank.md"
  printf '| F | S |\n|---|---|\n| F20 | ok |\nand then some prose\n| F21 | ok |\n' > "$CTL/prose.md"
  printf '| F | S |\n|---|---|\n| F20 | ok |\n| F21 | ok |\n' > "$CTL/whole.md"
  printf 'text\n\n| F | S |\n|---|---|\n| F20 | ok |\n\nmore text\n\n| G | S |\n|---|---|\n| G1 | ok |\n' > "$CTL/two.md"
  printf 'a union:\n\n```\ntype T = :a | :b\n\n| not a row |\n```\n' > "$CTL/fenced.md"

  fail=0
  red() { [ -z "$(split_tables_in "$CTL/$1")" ] && { echo "SELF-TEST FAILED: $1 — $2"; fail=1; }; return 0; }
  green() {
    local out; out="$(split_tables_in "$CTL/$1")"
    [ -n "$out" ] && { echo "SELF-TEST FAILED: $1 — $2"; printf '  reported: %s\n' "$out"; fail=1; }
    return 0
  }

  red blank.md "a blank line between two rows was not reported. That is README.md:112,
                  which rendered the feature index as two tables for thirteen days while
                  check-status-claims.sh stayed green"
  red prose.md "a PROSE line between two rows was not reported. 910ed93: a check written
                  as \`prev == \"\"\` passes the blank-line control and is blind to this one"
  green whole.md "an unbroken table was reported"
  green two.md   "two separate tables, each with its own header and prose between them,
                  were reported. That is ordinary markdown and most documents here do it"
  green fenced.md "a \`|\` inside a fenced block was read as a table row. Those are B#
                  unions and Erlang guards, and firing on them lights up LANGUAGE.md"

  if [ "$fail" -eq 0 ]; then
    echo "self-test: reported the blank-split and the prose-split table; accepted an"
    echo "           unbroken one, two properly separate ones and a fenced union"
    exit 0
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
[ "${1:-}" = "" ] || { echo "usage: detect-split-table.sh [--self-test]"; exit 2; }

cd "$ROOT"
scanned=0
findings=""
while IFS= read -r f; do
  case "$f" in _build/*|editor/node_modules/*) continue ;; esac
  scanned=$((scanned + 1))
  out="$(split_tables_in "$ROOT/$f")"
  [ -n "$out" ] && findings+="$out"$'\n'
done < <("${GIT:-git}" ls-files '*.md')

if [ "$scanned" -eq 0 ]; then
  echo "no markdown scanned — this detector is looking in the wrong place"
  exit 1
fi

if [ -n "$findings" ]; then
  printf '%s' "$findings"
  echo
  echo "Markdown closes a table at the first line that is not a table line. Everything"
  echo "after it renders as a second, headerless table — and every gate that reads rows"
  echo "still finds them, so nothing goes red. Remove the line, or give the second half"
  echo "its own header."
  exit 1
fi

echo "$scanned markdown documents have no table split by a blank or prose line"
