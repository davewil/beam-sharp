#!/usr/bin/env bash
# Does blanket -compile(inline) generalise beyond Day01? Compile every example module's emitted
# .abstr with and without it: success, .beam size, compile time (5 compiles each, mean).
set -e
source "$(dirname "$0")/../common.sh"; cd "$(dirname "$0")"; HERE="$PWD"
rm -rf abstr; mkdir abstr
mkdir -p abstr; for d in "$REPO"/compiler/examples/*/; do n=$(basename $d); mkdir -p "$HERE/abstr/$n"
  ( cd "$REPO/compiler/examples" && $BSC -o "$HERE/abstr/$n" --src-root . "$n" >/dev/null 2>"$HERE/abstr/$n.err" ) || echo "skip $n (bsc refused: $(head -1 "$HERE/abstr/$n.err"))"
done
erlc corp.erl; erl -noshell -pa . -eval 'corp:main(["abstr"])'
