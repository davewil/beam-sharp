#!/usr/bin/env bash
# Probe 59-H: which eunit tests pin the behaviour? Runs `rebar3 eunit` in a scratch copy
# of the repo's compiler/ for head / narrow / widen (3 in parallel, ~6-8 min).
# The copies sit beside a symlink to the repo's aoc/ (some tests read ../aoc) and each has its
# escript built first (some tests drive _build/default/bin/bsc).
# NOT RUN HERE: the check-*.sh gates and bin/verify.sh. They were not run under either patch.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
"$HERE/build-compilers.sh" "$W/c" >/dev/null
for v in head narrow widen; do
  mkdir -p "$W/t/$v"; ln -s "$REPO/aoc" "$W/t/$v/aoc"
  cp -r "$W/c/$v-src" "$W/t/$v/compiler"
  (cd "$W/t/$v/compiler" && rebar3 escriptize >/dev/null 2>&1 && rebar3 eunit > "$W/eunit-$v.txt" 2>&1) &
done
wait
for v in head narrow widen; do
  echo "== eunit, build: $v"
  grep -E '^  Failed:|\*failed\*|All [0-9]+ tests passed|^  [0-9]+ tests' "$W/eunit-$v.txt" | cut -c1-170
done
