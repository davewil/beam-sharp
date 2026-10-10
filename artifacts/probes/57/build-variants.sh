#!/usr/bin/env bash
# Builds six compilers from a clean `git archive HEAD` of the repo: 0 (baseline) and the prototypes
# A1 A2 B C C2 (patch-*.diff in this directory). Prints the built bsc paths. Usage: build-variants.sh OUTDIR
set -u
source /tmp/claude-0/env.sh
OUT=${1:?outdir}; HERE=$(cd "$(dirname "$0")" && pwd); REPO=$(git -C "$HERE" rev-parse --show-toplevel)
mkdir -p "$OUT"
for v in 0 A1 A2 B C C2; do
  d=$OUT/wp-$v; rm -rf "$d"; mkdir -p "$d"
  git -C "$REPO" archive HEAD compiler | tar -x -C "$d"
  if [ "$v" != 0 ]; then
    p=$(ls "$HERE"/patch-$v-*.diff); (cd "$d" && git apply --directory=. "$p") || { echo "patch $v failed"; exit 1; }
  fi
  # bs_parser.erl is generated and gitignored; the archive has none, but never trust an mtime.
  rm -f "$d/compiler/src/bs_parser.erl"
  (cd "$d/compiler" && rebar3 escriptize >/dev/null 2>&1) || { echo "build $v failed"; exit 1; }
  cp "$d/compiler/_build/default/bin/bsc" "$OUT/bsc-$v"
  printf 'bsc-%s: %s\n' "$v" "$OUT/bsc-$v"
done
