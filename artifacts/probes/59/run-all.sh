#!/usr/bin/env bash
# Runs every probe for ticket 59 and concatenates the evidence into output.txt.
# ~15 minutes (run-cost.sh dominates). source env.sh first.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
{
  for s in run-behaviour.sh run-union.sh run-corpus.sh run-loop.sh run-cost.sh neighbours/run-neighbours.sh; do
    echo "################ $s"; "$HERE/$s" 2>&1
  done
} | tee "$HERE/output.txt"
