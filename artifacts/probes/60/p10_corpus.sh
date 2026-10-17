#!/usr/bin/env bash
# Probe 10 - what each prototype costs the existing corpus: pre-existing .bs files using the word `internal`
# (P2 reserves it) and pre-existing modules with an `Internal` segment (P1 gives it meaning). Excludes this probe dir.
root=$(cd "$(dirname "$0")/../../.." && pwd)
files=$(find "$root" -name '*.bs' -not -path '*/artifacts/*' | wc -l)
echo ".bs files in repo outside artifacts/: $files"
echo "files containing word 'internal' (any case): $(grep -rliw internal --include=*.bs "$root" --exclude-dir=artifacts | wc -l)"
echo "module declarations with an 'Internal' segment: $(grep -rhE '^module .*\bInternal\b' --include=*.bs "$root" --exclude-dir=artifacts | wc -l)"
echo "files hand-listing keyword 'private' (proxy for editor sites a new keyword touches):"
grep -rlw private "$root/editor" --exclude-dir=node_modules 2>/dev/null | grep -v "parser.c\|node-types\|grammar.json" | sed "s#$root/##"
