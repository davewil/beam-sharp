#!/usr/bin/env bash
# Ticket 57. Patch A changes the AST of every `-<int>` literal. The AoC programs are the corpus that would show a regression.
# Compile every directory under aoc/ that holds a .bs file with the given build; print rc per directory and a digest of the emitted forms.
. "$(dirname "$0")/../env.sh"; ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
for d in $(find "$ROOT/aoc" -name '*.bs' -printf '%h\n' | sort -u); do
  o=$(mktemp -d); bsc -o $o $d >/dev/null 2>&1; rc=$?
  echo "$(echo ${d#$ROOT/}) rc=$rc $(cat $o/*.abstr 2>/dev/null | sed 's/^%%.*//' | md5sum | cut -c1-8)"
done
