#!/usr/bin/env bash
#
# Every `.bs` file the compiler accepts must also parse with the Tree-sitter
# grammar, with no ERROR node.
#
# WHY THIS IS THE GATE THAT MATTERS
# `check-tokens.sh` catches a keyword nobody added to a grammar. It cannot catch
# a rule that is present and WRONG, and a Tree-sitter grammar is a whole second
# parser for the language -- so the only honest check is to run it over the same
# corpus the compiler runs over. `compiler/examples/` is the "must run" surface,
# so it is the right corpus: if bsc compiles it, this must parse it.
#
# NOT CHECKED HERE: `examples/exemplars/`. Those are the compiler's target, not
# its test suite, and they do not parse with `bsc` either -- they are written on
# the other side of two documented forks (the bare clause head, and
# `[module: GenServer]`). Holding this grammar to them would be holding it to a
# language the compiler does not implement.
#
# Usage:  editor/bin/check-corpus.sh

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
GRAMMAR="$HERE/tree-sitter-beam-sharp"

if ! command -v tree-sitter >/dev/null 2>&1; then
    echo "tree-sitter CLI not found -- skipping (install: npm i -g tree-sitter-cli)"
    exit 0
fi

cd "$GRAMMAR"

# Regenerate first, so a grammar.js edit that was never generated fails here
# rather than passing against a stale parser.c.
tree-sitter generate >/dev/null

fail=0
for f in "$REPO"/compiler/examples/*.bs; do
    if tree-sitter parse -q "$f" >/dev/null 2>&1; then
        printf '  %-8s %s\n' "ok" "${f#"$REPO"/}"
    else
        printf '  %-8s %s\n' "ERROR" "${f#"$REPO"/}"
        tree-sitter parse "$f" 2>&1 | grep -F ERROR | head -3 | sed 's/^/           /'
        fail=1
    fi
done

echo
if [ "$fail" -eq 0 ]; then
    echo "every example parses with no ERROR node"
else
    echo "the grammar rejects source the compiler accepts."
    exit 1
fi
