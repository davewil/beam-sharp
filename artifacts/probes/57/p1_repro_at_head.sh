#!/usr/bin/env bash
# Ticket 57: reproduce the claim at HEAD, and test the ticket's "table" plus forms the ticket did not list.
# Usage: BSC=/path/to/bsc bash p1_repro_at_head.sh   (default: the repo's built escript)
set -u; here=$(cd "$(dirname "$0")" && pwd); BSC=${BSC:-$here/../../../compiler/_build/default/bin/bsc}; . "$here/lib.sh"
echo "== refinements (the ticket's table)"
try R1 'type T = int where value >= -5'
try R2 'type T = int where value >= -5 and value <= 5'
try R3 'type T = int where value >= 1 or value <= -1'
try R4 'type T = int where value <= 3 or value >= 10'
try R5 'type T = int where value != 0'
echo "== forms the ticket did not list"
try R6 'type T = int where value >= 2 + 3'
try R7 'type T = int where value >= -(5)'
try R8 'type T = int where value != -1'
try R9 'type T = int where value == -1'
try R10 'type T = int where -5 <= value'
echo "== the same literals as PATTERNS"
try P1 'public atom Sign(int n)
Sign(<= -1) -> :neg
Sign(0) -> :zero
Sign(>= 1) -> :pos'
