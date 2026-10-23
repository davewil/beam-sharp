#!/usr/bin/env bash
# PROBE 60g — corpus facts the brief cites, as commands rather than recollection.
#  (1) the cross-module `using` edges in compiler/examples (native form: `using Uident.Path`)
#  (2) whether any path or .bs source in the repo contains `Internal` (the segment option A would reserve)
#  (3) how many keyword rules the lexer has today (ticket 22 counted sixteen on 2026-08-23)
# CONTROLS (a count that cannot change proves nothing): (1) is re-run on a temp copy of the examples with one
# extra `using` line added and must report exactly one more edge; (2) is re-run after creating a path named
# Internal in a temp tree and must find it; (3) is re-run on a temp lexer copy with one extra keyword rule.
# Text-level only: the exemplars do not compile, so --api cannot be asked. No toolchain needed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; REPO="$(cd "$HERE/../../.." && pwd)"; EX="$REPO/compiler/examples"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; rc=0
edges() { ( cd "$1" && for f in $(find . -name '*.bs' | sort); do
  m=$(grep -m1 -E '^module ' "$f" | awk '{print $2}'); [ -z "$m" ] && m="(dir:$(dirname "$f"))"
  grep -E '^using [A-Z]' "$f" | awk -v m="$m" '{print m" -> "$2}'
done | sort -u ); }
echo "== (1) native 'using' edges, importer -> target (importer = the file's 'module' line, else its directory)"
e=$(edges "$EX"); echo "$e" | sed 's/^/   /'; n=$(echo "$e" | grep -c .)
echo "   distinct edges: $n   over $(find "$EX" -name '*.bs' | wc -l) .bs files"
cp -r "$EX" "$W/ex"; mkdir -p "$W/ex/Zed"; printf 'module Zed\nusing Zed.Added\n' > "$W/ex/Zed/zed.bs"
n2=$(edges "$W/ex" | grep -c .)
if [ "$n2" = $((n+1)) ]; then echo "   control: one added 'using' line -> $n2 edges (+1)  PASS"; else echo "   control FAILED: $n -> $n2"; rc=1; fi
echo "== (2) paths named like Internal anywhere in the repo (case-insensitive; excluding .git, _build, artifacts/)"
find_internal() { ( cd "$1" && find . -ipath '*internal*' -not -path './.git/*' -not -path './compiler/_build/*' -not -path './artifacts/*' | head ); }
hits=$(find_internal "$REPO"); if [ -z "$hits" ]; then echo "   none"; else echo "$hits" | sed 's/^/   /'; fi
mkdir -p "$W/t/A/Internal"; c=$(find_internal "$W/t" | grep -c .)
[ "$c" = 1 ] && echo "   control: a temp tree with A/Internal -> found $c  PASS" || { echo "   control FAILED: found $c"; rc=1; }
echo "== (2b) the word inside .bs source (whole word, any case)"
echo "   count: $(grep -rniw 'internal' --include=*.bs "$REPO" | wc -l)"
echo "== (3) lexer keyword rules (lines 'word : {token, {'word', ...' in bs_lexer.xrl)"
kw() { grep -E "^([a-z_]+)[[:space:]]+: \{token, \{'\1'" "$1" | awk '{print $1}'; }
k=$(kw "$REPO/compiler/src/bs_lexer.xrl"); echo "   $(echo "$k" | grep -c .) rules: $(echo $k)"
echo "   of which \`_\` is the wildcard, not a word: $(echo "$k" | grep -vx '_' | grep -c .) keywords; plus alias \`behavior\` -> behaviour"
cp "$REPO/compiler/src/bs_lexer.xrl" "$W/l.xrl"; printf "zorp  : {token, {'zorp', TokenLoc}}.\n" >> "$W/l.xrl"
k2=$(kw "$W/l.xrl" | grep -c .)
[ "$k2" = $(echo "$k" | grep -c .) ] && { echo "   control FAILED: an added rule was not counted"; rc=1; } || echo "   control: one added rule -> $k2 rules  PASS"
exit $rc
