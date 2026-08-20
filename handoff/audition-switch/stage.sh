#!/usr/bin/env bash
#
# Stage one working directory per candidate model.
#
# Each worker gets PACKET.md and cases/ — and NOT expected/, and NOT heldout/.
# The boundary is enforced by what is on disk rather than by asking politely in
# the spec: a worker cannot read answers that were never copied into its
# sandbox. The spec still states the rule, because a worker that goes looking is
# itself a finding.
#
# THERE ARE TWO SECRETS NOW, NOT ONE. `expected/` holds the answers to the
# visible cases; `heldout/` holds cases the worker is scored on and never shown.
# A leak check written for one secret's name permits the other silently, so
# `leaks()` names both and the self-test plants both. Staging `heldout/` would
# not look like a leak — the worker would simply score well — which is precisely
# why it has to be caught on disk rather than noticed in a result.
#
#   ./stage.sh <workdir>
#
# Creates <workdir>/<model-key>/ for each key named below.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# NOT `for key in $KEYS` — this shell word-splits differently under zsh, where an
# unquoted parameter stays one word and the loop silently runs once on a
# nonsense name. An array is the portable spelling.
KEYS=(codex copilot-sonnet5 copilot-haiku45 free-deepseek)

# Are the answers reachable from anywhere under a staged tree? Factored out so
# --self-test can point it at a tree with a deliberate leak; testing it by
# planting a directory inside a real run does not work, because staging deletes
# and recreates each worker directory first — the plant was erased rather than
# detected, which told us nothing about the check.
leaks() {
  find "$1" -maxdepth 2 -type d \( -name 'expected' -o -name 'heldout' \) 2>/dev/null
}

if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT
  mkdir -p "$CTL/clean/worker/cases" "$CTL/leaky/worker/expected" "$CTL/held/worker/heldout"
  fail=0
  [ -z "$(leaks "$CTL/clean")" ] || { echo "SELF-TEST FAILED: a clean tree was reported as leaking"; fail=1; }
  [ -n "$(leaks "$CTL/leaky")" ] || { echo "SELF-TEST FAILED: a planted expected/ was NOT found"; fail=1; }
  # Planted separately from expected/, not alongside it: a check that only ever
  # sees the two together would pass while blind to heldout/ on its own.
  [ -n "$(leaks "$CTL/held")"  ] || { echo "SELF-TEST FAILED: a planted heldout/ was NOT found — the exam would be staged with the tutorial"; fail=1; }
  [ "$fail" -eq 0 ] && { echo "self-test: found the planted answers and the planted held-out set, cleared the clean tree"; exit 0; }
  exit 1
fi

WORKDIR="${1:?usage: stage.sh <workdir> | stage.sh --self-test}"

mkdir -p "$WORKDIR"
for key in "${KEYS[@]}"; do
  d="$WORKDIR/$key"
  rm -rf "$d"
  mkdir -p "$d"
  cp "$HERE/PACKET.md" "$d/PACKET.md"
  cp -R "$HERE/cases" "$d/cases"
  printf '%s\n' "$key" > "$d/.model-key"
  echo "staged $d"
done

echo
found="$(leaks "$WORKDIR")"
if [ -n "$found" ]; then
  echo "LEAK — answers are reachable from a worker directory:"
  printf '  %s\n' "$found"
  exit 1
fi
echo "neither expected/ nor heldout/ is reachable from any worker directory"
