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

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
SRC="$REPO/wayfinder/prototypes"
DEST="$HERE/examples/exemplars"

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
