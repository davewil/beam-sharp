#!/usr/bin/env bash
# build.sh -- build bsc four ways from the repo's compiler/ source into $W59_WORK.
#   base : the repo as it stands (tag test everywhere, int/float/range exported-only)
#   a    : option a, tag test exported-only too
#   b    : option b, int/float/range guards on every function too
#   c    : option b + a prototype pass that drops a private function's tag test where every
#          caller has already tested it (patches/option_c.patch)
# The repo's compiler/ is only read. Run from anywhere.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "${W59_ENV:-/tmp/claude-0/-home-user-beam-sharp/c0642514-f9d1-5f22-91e2-015f96c1f119/scratchpad/env.sh}"
REPO=$(cd "$HERE/../../.." && pwd)
W=${W59_WORK:-/tmp/claude-0/-home-user-beam-sharp/c0642514-f9d1-5f22-91e2-015f96c1f119/scratchpad/w59/work}
mkdir -p "$W"
for v in base a b c; do
  rm -rf "$W/$v"; mkdir -p "$W/$v"
  mkdir -p "$W/$v/compiler"; cp -r "$REPO/compiler/." "$W/$v/compiler"
  rm -rf "$W/$v/compiler/_build"
  # a few eunit tests read repo siblings of compiler/ (aoc/): copy them so base is green and p11 compares like with like
  cp -r "$REPO/aoc" "$W/$v/aoc"
  if [ "$v" != base ]; then (cd "$W/$v" && patch -p1 < "$HERE/patches/option_$v.patch" >/dev/null); fi
  (cd "$W/$v/compiler" && rebar3 escriptize >"$W/$v/build.log" 2>&1) || { echo "BUILD FAILED $v"; tail -20 "$W/$v/build.log"; exit 1; }
  echo "built $v: $W/$v/compiler/_build/default/bin/bsc"
done
