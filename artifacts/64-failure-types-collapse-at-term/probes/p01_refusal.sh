#!/usr/bin/env bash
# P01: reproduce the refusal at the declaration for the four shapes in ticket 64 (+ controls)
. "$(dirname "$0")/lib.sh"
for spec in "option<term>" "result<term, atom>" "result<int, term>" "option<atom>" "option<int>" "result<int, atom>" "option<(:ok, term) >"; do
  n=$(echo "$spec" | tr -c 'A-Za-z0-9\n' '_' | sed 's/_*$//; s/__*/_/g'); n="T_$n"
  mk "$n" <<SRC
module $n

public $spec Find(int k)
Find(k) -> :nothing
SRC
  echo "=== $spec ==="
  $BSC "$W/$n" --api 2>&1 | head -12
  $BSC "$W/$n" 2>&1 | head -12
done
