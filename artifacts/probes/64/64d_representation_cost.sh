#!/usr/bin/env bash
# PROBE 64d — heap words, serialized bytes, run time and BEAM asm: bare vs always-tagged option<int>.
# Control inside the probe: both shapes compute the same sum (the match is the only difference).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cp "$HERE/repr.erl" "$W/"
( cd "$W" && erlc +no_inline repr.erl && erl -noshell -s repr run -s init stop )
echo
echo "== BEAM asm for the two consumers (erlc -S): the first clause body that matches an element =="
( cd "$W" && erlc -S repr.erl && awk '/^{function, bare_sum, 2/,/^{function, tagged_sum, 1/' repr.S | sed -n 1,40p
  echo "-- tagged --"
  awk '/^{function, tagged_sum, 2/,/^{function, bare_mk, 1/' repr.S | sed -n 1,48p )
