#!/usr/bin/env bash
# PROBE 60g — two corpus facts the brief cites, as commands rather than recollection.
#  (1) the cross-module `using` edges in compiler/examples (native form: `using Uident.Path`)
#  (2) whether any directory or file in the repo is named like `Internal` (the segment option A would reserve)
# Text-level only: the exemplars do not compile, so --api cannot be asked. No toolchain needed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; REPO="$(cd "$HERE/../../.." && pwd)"; EX="$REPO/compiler/examples"
echo "== (1) native 'using' edges, importer -> target (importer = the file's 'module' line, else its directory)"
edges=$(cd "$EX" && for f in $(find . -name '*.bs' | sort); do
  m=$(grep -m1 -E '^module ' "$f" | awk '{print $2}'); [ -z "$m" ] && m="(dir:$(dirname "$f"))"
  grep -E '^using [A-Z]' "$f" | awk -v m="$m" '{print m" -> "$2}'
done | sort -u)
echo "$edges" | sed 's/^/   /'
echo "   distinct edges: $(echo "$edges" | grep -c .)   over $(find "$EX" -name '*.bs' | wc -l) .bs files"
echo "== (2) paths named like Internal anywhere in the repo (case-insensitive, excluding .git, _build and this probe directory)"
hits=$(cd "$REPO" && find . -ipath '*internal*' -not -path './.git/*' -not -path './compiler/_build/*' -not -path './artifacts/*' | head)
if [ -z "$hits" ]; then echo "   none"; else echo "$hits" | sed 's/^/   /'; fi
echo "== (2b) the word as an identifier or segment inside .bs source (whole word, any case)"
grep -rniw 'internal' --include=*.bs "$REPO" | sed "s|^$REPO/|   |" | head -5
echo "   count: $(grep -rniw 'internal' --include=*.bs "$REPO" | wc -l)"
