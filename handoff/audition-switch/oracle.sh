#!/usr/bin/env bash
#
# THE EXPECTED VERDICTS ARE RECORDED FROM THE COMPILER, NEVER TYPED BY HAND.
#
# This regenerates `expected/<case>.tags` by running the real `bsc` over every
# case and keeping the diagnostic tags it publishes on `--diagnostics term`.
#
# Hand-written expectations are how an audition ends up measuring the author's
# beliefs about the language instead of the language. If a case's behaviour ever
# changes, this file is re-run and the change shows up as a diff in the
# expectations — visible, reviewable, and attributable to the compiler rather
# than to whoever last edited a fixture.
#
# The worker being auditioned NEVER SEES `expected/`. It receives the packet and
# the cases; the tags stay on this side of the fence.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
BSC="$REPO/compiler/_build/default/bin/bsc"
[ -x "$BSC" ] || BSC="$REPO/compiler/_build/test/bin/bsc"
[ -x "$BSC" ] || { echo "no escript — run \`rebar3 escriptize\` in compiler/ first"; exit 1; }

mkdir -p "$HERE/expected"

for dir in "$HERE"/cases/*/; do
  name="$(basename "$dir")"
  mod_dir="$(find "$dir" -mindepth 1 -maxdepth 1 -type d | head -1)"
  out="$(mktemp -d)"
  # stdout carries the descriptors (F16); prose goes to stderr and is not used.
  #
  # `|| true` because A REJECTED PROGRAM IS THE NORMAL CASE HERE — most of these
  # cases exist to be refused, so bsc exits non-zero and under `pipefail` that
  # would abort the loop at the first interesting case. Without this the oracle
  # silently records only the programs that compile, which is the half that
  # teaches least.
  { "$BSC" --diagnostics term --src-root "$dir" -o "$out" "$mod_dir" 2>/dev/null || true; } \
    | sed -n 's/.*tag => \([a-z_][a-z_0-9]*\).*/\1/p' | sort -u > "$HERE/expected/$name.tags"
  printf '%-28s %s\n' "$name" "$(tr '\n' ' ' < "$HERE/expected/$name.tags" | sed 's/ *$//' || true)"
done
