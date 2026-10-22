#!/usr/bin/env bash
# What an author sees when the DERIVED alias collides, under the scratch alias-patched compiler (probe 05's patch).
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib.sh"
ALIAS=$(BS_PATCH_ALIAS=1 build_bsc alias) || exit 1
PLAIN=$(build_bsc plain) || exit 1
mkdir -p "$SCRATCH/cwd"; cd "$SCRATCH/cwd"
SRC="$SCRATCH/src06"; rm -rf "$SRC"; cp -r "$HERE/src" "$SRC"   # bsc writes beside --src-root
for m in Clash Info Ok; do
  for v in plain alias; do B=$PLAIN; [ $v = alias ] && B=$ALIAS
    echo "=== module $m under the $v compiler"; rm -rf "$SCRATCH/o-$m-$v"; mkdir -p "$SCRATCH/o-$m-$v"
    "$B" --src-root "$SRC" -o "$SCRATCH/o-$m-$v" "$SRC/$m" 2>&1 | head -8; echo "exit=${PIPESTATUS[0]}"
    [ -f "$SCRATCH/o-$m-$v/$m.beam" ] && erl -noshell -pa "$SCRATCH/o-$m-$v" -eval "io:format(\"exports: ~p~n\",['$m':module_info(exports)]),halt()."
  done
done
