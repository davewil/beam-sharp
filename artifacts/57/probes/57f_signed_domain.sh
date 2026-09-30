#!/usr/bin/env bash
# 57f: the motivating program. A bounded signed quantity, its exhaustive dispatch, the residual after
# deleting a clause, and the boundary guard (ticket 46) over a negative lower bound.
. "$(dirname "$0")/common.sh"
src='type Delta = int where value >= -100 and value <= 100
type Step = :down | :none | :up

public Step Direction(Delta d)

Direction(<= -1) -> :down
Direction(0)     -> :none
Direction(>= 1)  -> :up'
mkdir -p "$work/D"; printf 'module D\n%s\n' "$src" > "$work/D/a.bs"
echo "--- exhaustive version"; "$BSC" "$work/D/a.bs" 2>&1 | sed 's/^/  | /'; echo "  rc=${PIPESTATUS[0]}"
for arg in -100 -1 0 100 101 -101; do printf '  Direction(%s) => ' "$arg"; "$BSC" "$work/D/a.bs" Direction "$arg" 2>&1 | tail -1; done
mkdir -p "$work/E"; printf 'module E\n%s\n' "$(printf '%s\n' "$src" | grep -v '^Direction(<= -1)')" > "$work/E/a.bs"
echo "--- first clause deleted: is the residual a writable, pasteable thing?"; "$BSC" "$work/E/a.bs" 2>&1 | sed 's/^/  | /'
mkdir -p "$work/F"; cat > "$work/F/a.bs" <<'BS'
module F
type Delta = int where value >= -100 and value <= 100
public Delta Clamp(int n)
Clamp(n) when n > 100 -> 100
Clamp(n) when n < -100 -> -100
Clamp(n) -> n
BS
echo "--- Clamp into Delta (guards mention -100; refinement mentions -100)"; "$BSC" "$work/F/a.bs" 2>&1 | sed 's/^/  | /'; echo "  rc=${PIPESTATUS[0]}"
