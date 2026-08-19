#!/usr/bin/env bash
#
# Extract the beam-sharp source out of ticket 25's exemplar write-ups into
# compiled-shaped files under compiler/examples/exemplars/.
#
# WHY THIS IS A SCRIPT AND NOT A ONE-OFF COPY
# The prototypes are the canonical text (ticket 25 is a standing resource and
# the write-ups keep being amended). Hand-copying would fork them silently,
# which is the exact failure 25b already recorded once — its source and its
# lowering disagreed about the reserved opcodes and nobody noticed. Re-run this
# after any edit to a 25*-*.md and the files follow.
#
# WHAT IT TAKES
# Only blocks under a `## \`name.bs\`` heading, up to the next `## ` heading.
# Illustrative snippets inside friction lists are deliberately NOT extracted —
# they are arguments, not files.
#
# Usage:  compiler/bin/extract-exemplars.sh [--check]
#         --check  exits non-zero if the extracted files are stale

set -euo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# `EXTRACT_EXEMPLARS_ROOT` exists for the self-test below, which points the
# extractor at a copy of the prototypes and the extracted files with one side
# altered. Nothing else sets it.
REPO="${EXTRACT_EXEMPLARS_ROOT:-$(cd "$SELF/.." && pwd)}"
HERE="$REPO/compiler"
SRC="$REPO/wayfinder/prototypes"
DEST="$HERE/examples/exemplars"

# ---------------------------------------------------------------------------
# --self-test
#
# `--check` makes one claim — the committed exemplars are what the write-ups
# currently say — and it can go stale from EITHER SIDE. Both controls matter
# because the two are different accidents with the same symptom:
#
#   1. Somebody edits an extracted file directly. Every one of them opens with
#      "EXTRACTED — do not edit here", which is a sign, not a lock.
#   2. Somebody amends a `25*-*.md` write-up and does not re-run the extractor.
#      This is the likelier of the two, because the write-ups are a standing
#      resource that keeps being amended — the reason this is a script at all.
#
# The forked-source failure is not hypothetical: 25b's write-up and its lowering
# once disagreed about the reserved opcodes and nobody noticed.
#
# The controls copy the real prototypes and the real extracted tree. A fixture
# write-up would exercise none of the awk that finds a "## `name.bs`" heading,
# which is where this script does its work.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  # Captured, not piped: a control run is meant to exit 1 and `pipefail` would
  # hand that status back even when the marker was found.
  control() {
    EXTRACT_EXEMPLARS_ROOT="$1" "${BASH_SOURCE[0]}" --check 2>&1 || true
  }
  fresh() {
    rm -rf "$1"; mkdir -p "$1/wayfinder/prototypes" "$1/compiler/examples"
    cp "$SELF"/../wayfinder/prototypes/25[a-z]-*.md "$1/wayfinder/prototypes/"
    cp -R "$SELF/examples/exemplars" "$1/compiler/examples/"
  }

  st_fail=0
  first_bs() { find "$1/compiler/examples/exemplars" -name '*.bs' | sort | head -1; }

  # CONTROL 1 — an extracted file edited by hand.
  fresh "$CTL/edited"
  printf '\nHandEdited() -> :oops\n' >> "$(first_bs "$CTL/edited")"
  case "$(control "$CTL/edited")" in
    *STALE*) ;;
    *) echo "SELF-TEST FAILED: a hand-edited extracted file was not reported —"
       echo "                  --check cannot see the side it was written to protect"
       st_fail=1 ;;
  esac

  # CONTROL 2 — a write-up amended without re-running the extractor. The edit
  # goes INSIDE a fenced block, since that is the only text that is extracted;
  # changing the prose around it correctly changes nothing.
  fresh "$CTL/amended"
  awk '
    /^```csharp$/ { print; infence = 1; next }
    infence && !done { print "// amended by the self-test"; done = 1 }
    { print }
  ' "$(find "$CTL/amended/wayfinder/prototypes" -name '25a-*.md' | head -1)" \
    > "$CTL/amended/tmp.md"
  mv "$CTL/amended/tmp.md" \
     "$(find "$CTL/amended/wayfinder/prototypes" -name '25a-*.md' | head -1)"
  case "$(control "$CTL/amended")" in
    *STALE*) ;;
    *) echo "SELF-TEST FAILED: an amended write-up was not reported — the source"
       echo "                  and the extracted files can fork silently"
       st_fail=1 ;;
  esac

  # NEGATIVE CONTROL — both sides as committed.
  fresh "$CTL/clean"
  if EXTRACT_EXEMPLARS_ROOT="$CTL/clean" "${BASH_SOURCE[0]}" --check > /dev/null 2>&1
  then :; else
    echo "SELF-TEST FAILED: the committed exemplars were called stale, so this gate"
    echo "                  would fail every clean tree and be removed"
    st_fail=1
  fi

  if [ "$st_fail" -eq 0 ]; then
    echo "self-test: reported the hand-edited file and the amended write-up;"
    echo "           accepted the committed pair — the check discriminates"
    exit 0
  fi
  exit 1
fi

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1 && DEST="$(mktemp -d)/exemplars"

mkdir -p "$DEST"

extract_one() {
  local md="$1" slug="$2" outdir="$3"
  mkdir -p "$outdir"
  awk -v outdir="$outdir" -v slug="$slug" -v md="$(basename "$md")" '
    # A "## `name.bs`" heading opens a file; any other "## " closes it.
    /^## `[a-z_]+\.bs`/ {
      match($0, /`[a-z_]+\.bs`/)
      cur = substr($0, RSTART+1, RLENGTH-2)
      path = outdir "/" cur
      printf "" > path              # truncate on first sight
      printf "// EXTRACTED — do not edit here.\n" >> path
      printf "// Source: wayfinder/prototypes/%s, section `%s`\n", md, cur >> path
      printf "// Regenerate: compiler/bin/extract-exemplars.sh\n" >> path
      printf "//\n" >> path
      printf "// This file is OUT OF THE WALKING SKELETON SLICE and does not parse today.\n" >> path
      printf "// It is a target for the compiler, not a passing example. The write-up it\n" >> path
      printf "// came from carries the friction list explaining what is wrong with it and\n" >> path
      printf "// why that is the point.\n\n" >> path
      inblock = 0
      next
    }
    /^## / { cur = ""; inblock = 0; next }
    cur == "" { next }
    /^```csharp$/ { inblock = 1; next }
    /^```$/      { if (inblock) { print "" >> path; inblock = 0 } next }
    inblock      { print >> path }
  ' "$md"
}

shopt -s nullglob
found=0
for md in "$SRC"/25[a-z]-*.md; do
  slug="$(basename "$md" .md)"
  extract_one "$md" "$slug" "$DEST/$slug"
  n=$(find "$DEST/$slug" -name '*.bs' | wc -l | tr -d ' ')
  echo "  $slug -> $n files"
  found=$((found + n))
done

echo "extracted $found .bs files into $DEST"

if [ "$CHECK" = 1 ]; then
  # README.md is hand-written and lives only in the real directory.
  if diff -rq --exclude=README.md "$DEST" "$HERE/examples/exemplars" >/dev/null 2>&1; then
    echo "OK — extracted files are up to date"
  else
    echo "STALE — re-run compiler/bin/extract-exemplars.sh" >&2
    diff -rq --exclude=README.md "$DEST" "$HERE/examples/exemplars" >&2 || true
    exit 1
  fi
fi
