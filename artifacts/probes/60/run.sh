#!/usr/bin/env bash
# Ticket 60: who may name a module? Usage: BSC=<bsc> FX=<fixture root> run.sh
# Compiles each importer against the fixture tree and prints the first diagnostic line, or OK.
set -u
BSC=${BSC:?}; FX=${FX:?}
for m in Shop/Billing Other Other2 Other3; do
  out=$(cd "$FX" && "$BSC" --src-root "$FX" "$m" 2>&1 | head -2 | tr '\n' ' ')
  printf '%-14s %s\n' "$m" "${out:-OK}"
done
