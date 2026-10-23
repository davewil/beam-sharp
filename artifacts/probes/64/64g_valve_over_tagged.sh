#!/usr/bin/env bash
# PROBE 64g — the valve (|?>) over bare option<int> versus an always-tagged one.
# A Bare64: stage declared over int (as LANGUAGE.md documents).  B Tagged64: stage must take (:some, int).
# Control TaggedNarrow: the documented stage shape against the tagged subject — must be REFUSED.
set -uo pipefail
: "${BSC:?source env.sh first}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/64g"
for m in Bare64 Tagged64 TaggedNarrow; do
  echo "== $m"
  for a in 4 0; do printf '  Load(%s) = ' $a; "$BSC" "$HERE/$m/$m.bs" Load $a 2>&1 | sed -n 1,3p | tr '\n' ' '; echo; done
done
