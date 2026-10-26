#!/usr/bin/env bash
# P2: which erlc stage first turns `-5`/`2+3`/`1 bsl 3` into a literal? Runs in a scratch dir.
set -u
here=$(cd "$(dirname "$0")" && pwd); w=$(mktemp -d); cp "$here/fold.erl" "$w/"; cd "$w"
for opt in +to_pp +dexp +dcore +to_core +to_kernel +dkern; do
  echo "=== erlc $opt  (guards of g/1, clause of p/1)"
  erlc $opt fold.erl >/dev/null 2>&1
  f=$(ls fold.* 2>/dev/null | grep -v '\.erl$' | head -1)
  [ -n "$f" ] && grep -n -E "when|-5|5\b|8\b|bsl|\+|- *5|\*" "$f" | head -14
  rm -f fold.core fold.P fold.E fold.expand fold.kernel fold.dkern fold.S fold.beam
done
echo "=== erlc -S (final asm; guard tests)"
erlc -S fold.erl; grep -n -E "is_ge|is_lt|\{integer,|ge,|bsl|gc_bif" fold.S | head -20
